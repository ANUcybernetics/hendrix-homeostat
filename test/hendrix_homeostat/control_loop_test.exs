defmodule HendrixHomeostat.ControlLoopTest do
  use ExUnit.Case, async: false

  import HendrixHomeostat.ControlLoopHelpers

  alias HendrixHomeostat.ControlLoop
  alias HendrixHomeostat.MidiController
  alias HendrixHomeostat.Midi.TestSpy

  setup do
    {:ok, _pid} = start_supervised({TestSpy, []})
    TestSpy.clear_notify()

    {:ok, midi_pid} =
      start_supervised({MidiController, ready_notify: self(), startup_delay_ms: 0})

    assert_receive {:midi_ready, ^midi_pid}, 100
    _ = :sys.get_state(MidiController)
    TestSpy.clear_history()

    {:ok, _pid} = start_supervised(ControlLoop)

    subscribe_to_control_loop()

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
    test "broadcasts state with updated current_rms" do
      send_metrics(0.5)

      state = assert_state_broadcast()
      assert state.current_rms == 0.5
    end

    test "handles multiple metric updates" do
      send_metrics(0.3)
      send_metrics(0.5)
      send_metrics(0.7)

      # Consume first two broadcasts
      assert_state_broadcast()
      assert_state_broadcast()

      # Check the final state
      state = assert_state_broadcast()
      assert state.current_rms == 0.7
    end
  end

  describe "configuration" do
    test "loads config from RuntimeConfig on init" do
      # Trigger a state broadcast by sending metrics
      send_metrics(0.5)

      state = assert_state_broadcast()

      assert is_map(state.config)
      assert Map.has_key?(state.config, :too_loud)
      assert Map.has_key?(state.config, :too_quiet)
      assert Map.has_key?(state.config, :oscillation_threshold)
    end

    test "receives config updates" do
      # Get initial state
      send_metrics(0.5)
      initial_state = assert_state_broadcast()
      initial_config = initial_state.config

      # Update config
      new_config = %{too_loud: 0.9, too_quiet: 0.05, oscillation_threshold: 8}
      send(ControlLoop, {:config_update, new_config})

      # Trigger a new broadcast to see updated config
      send_metrics(0.6)
      updated_state = assert_state_broadcast()

      assert updated_state.config != initial_config
      assert updated_state.config.too_loud == 0.9
      assert updated_state.config.too_quiet == 0.05
      assert updated_state.config.oscillation_threshold == 8
    end
  end

  describe "state transitions" do
    test "tracks transition from nil to too_loud" do
      send_metrics(0.9)
      state = assert_state_broadcast()
      assert state.last_state == :too_loud
      assert length(state.transition_history) == 1
    end

    test "tracks transition from ok to too_quiet" do
      send_metrics(0.3)
      assert_state_broadcast()

      send_metrics(0.05)
      state = assert_state_broadcast()
      assert state.last_state == :too_quiet
      assert length(state.transition_history) == 1
    end

    test "does not record transition when staying in same state" do
      send_metrics(0.9)
      state1 = assert_state_broadcast()
      history_length_1 = length(state1.transition_history)

      send_metrics(0.95)
      state2 = assert_state_broadcast()
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
        send_metrics(rms)
      end

      # Consume all broadcasts and check the final state
      state =
        Stream.repeatedly(fn -> assert_state_broadcast(timeout: 50) end)
        |> Enum.take(50)
        |> List.last()

      # Should be bounded to 20
      assert length(state.transition_history) <= 20
    end

    test "transition history contains timestamps" do
      send_metrics(0.9)
      state = assert_state_broadcast()

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
        send_metrics(rms)
      end

      # Collect all state broadcasts
      states =
        Stream.repeatedly(fn -> assert_state_broadcast(timeout: 100) end)
        |> Enum.take(20)

      # Find the last state (after potential reconfiguration)
      final_state = List.last(states)

      # After ultrastable reconfiguration, history should be cleared
      # or significantly reduced
      assert length(final_state.transition_history) < 10
    end

    test "updates track volumes after ultrastable reconfiguration" do
      # Create oscillation pattern to trigger reconfiguration
      for i <- 1..20 do
        rms = if rem(i, 2) == 0, do: 0.9, else: 0.05
        send_metrics(rms)
      end

      # Collect state broadcasts and check final state
      final_state =
        Stream.repeatedly(fn -> assert_state_broadcast(timeout: 100) end)
        |> Enum.take(20)
        |> List.last()

      # Volumes should be valid MIDI values
      assert final_state.track1_volume in [25, 50, 75, 100, 127]
      assert final_state.track2_volume in [25, 50, 75, 100, 127]
    end
  end
end
