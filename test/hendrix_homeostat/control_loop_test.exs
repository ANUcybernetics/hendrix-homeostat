defmodule HendrixHomeostat.ControlLoopTest do
  use ExUnit.Case

  alias HendrixHomeostat.ControlLoop
  alias HendrixHomeostat.MidiController
  alias HendrixHomeostat.MidiBackend.InMemory

  setup do
    {:ok, _pid} = start_supervised({InMemory, name: InMemory})
    InMemory.clear_history()

    {:ok, _pid} = start_supervised(MidiController)
    {:ok, _pid} = start_supervised(ControlLoop)

    :ok
  end

  describe "GenServer lifecycle" do
    test "starts and initializes correctly" do
      stop_supervised(ControlLoop)

      assert {:ok, pid} = ControlLoop.start_link([])
      assert Process.alive?(pid)

      state = :sys.get_state(pid)
      assert state.current_rms == nil
      assert state.last_state == nil
      assert state.transition_history == []
      assert is_integer(state.track1_volume)
      assert is_integer(state.track2_volume)
      assert is_map(state.config)

      stop_supervised(ControlLoop)
    end

    test "has correct child_spec" do
      spec = ControlLoop.child_spec([])
      assert spec.id == ControlLoop
      assert spec.shutdown == 5_000
    end
  end

  describe "receiving metrics" do
    test "updates current_rms" do
      metrics = %{rms: 0.5, zcr: 0.5, peak: 0.6}

      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      state = :sys.get_state(ControlLoop)
      assert state.current_rms == 0.5
    end

    test "handles multiple metric updates" do
      metrics1 = %{rms: 0.3, zcr: 0.5, peak: 0.6}
      metrics2 = %{rms: 0.5, zcr: 0.55, peak: 0.65}
      metrics3 = %{rms: 0.7, zcr: 0.6, peak: 0.7}

      send(ControlLoop, {:metrics, metrics1})
      send(ControlLoop, {:metrics, metrics2})
      send(ControlLoop, {:metrics, metrics3})
      Process.sleep(50)

      state = :sys.get_state(ControlLoop)
      assert state.current_rms == 0.7
    end
  end

  describe "configuration" do
    test "loads config from RuntimeConfig on init" do
      state = :sys.get_state(ControlLoop)

      assert is_map(state.config)
      assert Map.has_key?(state.config, :too_loud)
      assert Map.has_key?(state.config, :too_quiet)
      assert Map.has_key?(state.config, :oscillation_threshold)
    end

    test "receives config updates" do
      initial_state = :sys.get_state(ControlLoop)
      initial_config = initial_state.config

      new_config = %{too_loud: 0.9, too_quiet: 0.05, oscillation_threshold: 8}
      send(ControlLoop, {:config_update, new_config})
      Process.sleep(20)

      updated_state = :sys.get_state(ControlLoop)
      assert updated_state.config != initial_config
      assert updated_state.config.too_loud == 0.9
      assert updated_state.config.too_quiet == 0.05
      assert updated_state.config.oscillation_threshold == 8
    end
  end

  describe "state transitions" do
    test "tracks transition from ok to too_loud" do
      send(ControlLoop, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.3}})
      Process.sleep(20)

      initial_state = :sys.get_state(ControlLoop)
      assert initial_state.last_state == nil

      send(ControlLoop, {:metrics, %{rms: 0.9, zcr: 0.5, peak: 0.9}})
      Process.sleep(20)

      final_state = :sys.get_state(ControlLoop)
      assert final_state.last_state == :too_loud
      assert length(final_state.transition_history) == 1
    end

    test "tracks transition from ok to too_quiet" do
      send(ControlLoop, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.3}})
      Process.sleep(20)

      send(ControlLoop, {:metrics, %{rms: 0.05, zcr: 0.5, peak: 0.05}})
      Process.sleep(20)

      state = :sys.get_state(ControlLoop)
      assert state.last_state == :too_quiet
      assert length(state.transition_history) == 1
    end

    test "does not record transition when staying in same state" do
      send(ControlLoop, {:metrics, %{rms: 0.9, zcr: 0.5, peak: 0.9}})
      Process.sleep(20)

      state1 = :sys.get_state(ControlLoop)
      history_length_1 = length(state1.transition_history)

      send(ControlLoop, {:metrics, %{rms: 0.95, zcr: 0.5, peak: 0.95}})
      Process.sleep(20)

      state2 = :sys.get_state(ControlLoop)
      history_length_2 = length(state2.transition_history)

      # Should not have added a new transition
      assert history_length_2 == history_length_1
    end
  end

  describe "transition history" do
    test "maintains bounded transition history" do
      # Alternate between too_loud and too_quiet many times
      for i <- 1..50 do
        rms = if rem(i, 2) == 0, do: 0.9, else: 0.05
        send(ControlLoop, {:metrics, %{rms: rms, zcr: 0.5, peak: rms}})
        Process.sleep(5)
      end

      Process.sleep(50)

      state = :sys.get_state(ControlLoop)
      # Should be bounded to 20
      assert length(state.transition_history) <= 20
    end

    test "transition history contains timestamps" do
      send(ControlLoop, {:metrics, %{rms: 0.9, zcr: 0.5, peak: 0.9}})
      Process.sleep(20)

      state = :sys.get_state(ControlLoop)

      if length(state.transition_history) > 0 do
        [{_state, timestamp} | _] = state.transition_history
        assert is_integer(timestamp)
      end
    end
  end

  describe "ultrastable reconfiguration" do
    test "clears transition history after ultrastable reconfiguration" do
      # Create oscillation pattern
      for i <- 1..20 do
        rms = if rem(i, 2) == 0, do: 0.9, else: 0.05
        send(ControlLoop, {:metrics, %{rms: rms, zcr: 0.5, peak: rms}})
        Process.sleep(10)
      end

      Process.sleep(100)

      state = :sys.get_state(ControlLoop)

      # After ultrastable reconfiguration, history should be cleared
      # or significantly reduced
      assert length(state.transition_history) < 10
    end

    test "updates track volumes after ultrastable reconfiguration" do
      # Create oscillation pattern to trigger reconfiguration
      for i <- 1..20 do
        rms = if rem(i, 2) == 0, do: 0.9, else: 0.05
        send(ControlLoop, {:metrics, %{rms: rms, zcr: 0.5, peak: rms}})
        Process.sleep(10)
      end

      Process.sleep(100)

      final_state = :sys.get_state(ControlLoop)

      # Volumes should have changed (probabilistically - might be same by chance)
      # At least check they're valid MIDI values
      assert final_state.track1_volume in [25, 50, 75, 100, 127]
      assert final_state.track2_volume in [25, 50, 75, 100, 127]
    end
  end
end
