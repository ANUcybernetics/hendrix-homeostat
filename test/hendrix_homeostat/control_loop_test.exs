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
    test "starts with start_link/1" do
      stop_supervised(ControlLoop)

      assert {:ok, pid} = ControlLoop.start_link([])
      assert Process.alive?(pid)

      stop_supervised(ControlLoop)
    end

    test "initializes with correct state from config" do
      state = :sys.get_state(ControlLoop)

      assert state.current_metrics == nil
      assert state.metrics_history == []
      assert state.last_action_timestamp == nil
      assert state.current_state == :comfortable

      assert state.config.critical_high == 0.8
      assert state.config.comfort_zone_min == 0.2
      assert state.config.comfort_zone_max == 0.5
      assert state.config.critical_low == 0.05
      assert state.config.stability_threshold == 0.02
      assert state.config.stability_duration == 30_000

      assert state.config.boost_bank == [1, 2, 3, 4, 5]
      assert state.config.dampen_bank == [10, 11, 12, 13, 14]
      assert state.config.random_bank == [20, 21, 22, 23, 24, 25, 26, 27, 28, 29]
    end

    test "has correct child_spec" do
      spec = ControlLoop.child_spec([])

      assert spec.id == ControlLoop
      assert spec.start == {ControlLoop, :start_link, [[]]}
      assert spec.shutdown == 5_000
    end
  end

  describe "receiving metrics" do
    test "updates current_metrics on receiving {:metrics, map}" do
      metrics = %{rms: 0.3, zcr: 0.5, peak: 0.6}
      send(ControlLoop, {:metrics, metrics})
      Process.sleep(10)

      state = :sys.get_state(ControlLoop)
      assert state.current_metrics == metrics
    end

    test "adds RMS to metrics_history" do
      metrics1 = %{rms: 0.3, zcr: 0.5, peak: 0.6}
      metrics2 = %{rms: 0.35, zcr: 0.55, peak: 0.65}

      send(ControlLoop, {:metrics, metrics1})
      send(ControlLoop, {:metrics, metrics2})
      Process.sleep(20)

      state = :sys.get_state(ControlLoop)
      assert state.metrics_history == [0.35, 0.3]
    end

    test "maintains history size limit of 30" do
      for i <- 1..50 do
        metrics = %{rms: i / 100, zcr: 0.5, peak: 0.6}
        send(ControlLoop, {:metrics, metrics})
      end

      Process.sleep(100)

      state = :sys.get_state(ControlLoop)
      assert length(state.metrics_history) == 30
    end
  end

  describe "critical high threshold (>= 0.8)" do
    test "sends dampen patch when RMS >= critical_high" do
      InMemory.clear_history()
      metrics = %{rms: 0.85, zcr: 0.5, peak: 0.9}

      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      history = InMemory.get_history()
      assert length(history) == 1

      [{:program_change, _device, patch, _timestamp}] = history
      assert patch in [10, 11, 12, 13, 14]
    end

    test "updates state to :loud on critical high" do
      metrics = %{rms: 0.9, zcr: 0.5, peak: 0.95}

      send(ControlLoop, {:metrics, metrics})
      Process.sleep(10)

      state = :sys.get_state(ControlLoop)
      assert state.current_state == :loud
    end

    test "sets last_action_timestamp on critical high" do
      metrics = %{rms: 0.85, zcr: 0.5, peak: 0.9}

      send(ControlLoop, {:metrics, metrics})
      Process.sleep(10)

      state = :sys.get_state(ControlLoop)
      assert is_integer(state.last_action_timestamp)
      assert state.last_action_timestamp > 0
    end

    test "exact threshold value 0.8 triggers critical high" do
      InMemory.clear_history()
      metrics = %{rms: 0.8, zcr: 0.5, peak: 0.8}

      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      history = InMemory.get_history()
      assert length(history) == 1
    end

    test "resets metrics history on critical high" do
      for _i <- 1..10 do
        metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
        send(ControlLoop, {:metrics, metrics})
      end

      Process.sleep(50)

      state_before = :sys.get_state(ControlLoop)
      assert length(state_before.metrics_history) == 10

      metrics = %{rms: 0.9, zcr: 0.5, peak: 0.95}
      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      state_after = :sys.get_state(ControlLoop)
      assert state_after.metrics_history == []
    end
  end

  describe "critical low threshold (<= 0.05)" do
    test "sends boost patch when RMS <= critical_low" do
      InMemory.clear_history()
      metrics = %{rms: 0.03, zcr: 0.5, peak: 0.1}

      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      history = InMemory.get_history()
      assert length(history) == 1

      [{:program_change, _device, patch, _timestamp}] = history
      assert patch in [1, 2, 3, 4, 5]
    end

    test "updates state to :quiet on critical low" do
      metrics = %{rms: 0.02, zcr: 0.5, peak: 0.05}

      send(ControlLoop, {:metrics, metrics})
      Process.sleep(10)

      state = :sys.get_state(ControlLoop)
      assert state.current_state == :quiet
    end

    test "sets last_action_timestamp on critical low" do
      metrics = %{rms: 0.01, zcr: 0.5, peak: 0.03}

      send(ControlLoop, {:metrics, metrics})
      Process.sleep(10)

      state = :sys.get_state(ControlLoop)
      assert is_integer(state.last_action_timestamp)
      assert state.last_action_timestamp > 0
    end

    test "exact threshold value 0.05 triggers critical low" do
      InMemory.clear_history()
      metrics = %{rms: 0.05, zcr: 0.5, peak: 0.1}

      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      history = InMemory.get_history()
      assert length(history) == 1
    end

    test "resets metrics history on critical low" do
      for _i <- 1..10 do
        metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
        send(ControlLoop, {:metrics, metrics})
      end

      Process.sleep(50)

      state_before = :sys.get_state(ControlLoop)
      assert length(state_before.metrics_history) == 10

      metrics = %{rms: 0.02, zcr: 0.5, peak: 0.05}
      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      state_after = :sys.get_state(ControlLoop)
      assert state_after.metrics_history == []
    end
  end

  describe "comfort zone (0.2-0.5)" do
    test "no action when RMS in comfort zone without stability" do
      InMemory.clear_history()
      metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}

      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      history = InMemory.get_history()
      assert history == []
    end

    test "updates state to :comfortable when in comfort zone" do
      metrics = %{rms: 0.35, zcr: 0.5, peak: 0.4}

      send(ControlLoop, {:metrics, metrics})
      Process.sleep(10)

      state = :sys.get_state(ControlLoop)
      assert state.current_state == :comfortable
    end

    test "lower boundary 0.2 is within comfort zone" do
      InMemory.clear_history()
      metrics = %{rms: 0.2, zcr: 0.5, peak: 0.3}

      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      state = :sys.get_state(ControlLoop)
      assert state.current_state == :comfortable

      history = InMemory.get_history()
      assert history == []
    end

    test "upper boundary 0.5 is within comfort zone" do
      InMemory.clear_history()
      metrics = %{rms: 0.5, zcr: 0.5, peak: 0.6}

      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      state = :sys.get_state(ControlLoop)
      assert state.current_state == :comfortable

      history = InMemory.get_history()
      assert history == []
    end
  end

  describe "between zones" do
    test "no action when RMS between comfort zone and critical thresholds" do
      InMemory.clear_history()

      metrics1 = %{rms: 0.19, zcr: 0.5, peak: 0.3}
      send(ControlLoop, {:metrics, metrics1})
      Process.sleep(10)

      metrics2 = %{rms: 0.6, zcr: 0.5, peak: 0.7}
      send(ControlLoop, {:metrics, metrics2})
      Process.sleep(10)

      history = InMemory.get_history()
      assert history == []
    end
  end

  describe "anti-stasis mechanism" do
    test "triggers random patch when stable for long enough with low variance" do
      InMemory.clear_history()

      for _i <- 1..30 do
        metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
        send(ControlLoop, {:metrics, metrics})
      end

      Process.sleep(100)

      state = :sys.get_state(ControlLoop)

      :sys.replace_state(ControlLoop, fn s ->
        %{s | last_action_timestamp: System.monotonic_time(:millisecond) - 31_000}
      end)

      metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      history = InMemory.get_history()
      assert length(history) == 1

      [{:program_change, _device, patch, _timestamp}] = history
      assert patch in [20, 21, 22, 23, 24, 25, 26, 27, 28, 29]
    end

    test "updates state to :stable when anti-stasis triggers" do
      for _i <- 1..30 do
        metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
        send(ControlLoop, {:metrics, metrics})
      end

      Process.sleep(100)

      :sys.replace_state(ControlLoop, fn s ->
        %{s | last_action_timestamp: System.monotonic_time(:millisecond) - 31_000}
      end)

      metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      state = :sys.get_state(ControlLoop)
      assert state.current_state == :stable
    end

    test "clears metrics history after anti-stasis trigger" do
      for _i <- 1..30 do
        metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
        send(ControlLoop, {:metrics, metrics})
      end

      Process.sleep(100)

      :sys.replace_state(ControlLoop, fn s ->
        %{s | last_action_timestamp: System.monotonic_time(:millisecond) - 31_000}
      end)

      metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      state = :sys.get_state(ControlLoop)
      assert state.metrics_history == []
    end

    test "does not trigger if variance is above threshold" do
      InMemory.clear_history()

      values =
        [0.2, 0.5, 0.2, 0.5, 0.2, 0.5, 0.2, 0.5, 0.2, 0.5] ++
          [0.2, 0.5, 0.2, 0.5, 0.2, 0.5, 0.2, 0.5, 0.2, 0.5] ++
          [0.2, 0.5, 0.2, 0.5, 0.2, 0.5, 0.2, 0.5, 0.2, 0.5]

      for rms <- values do
        metrics = %{rms: rms, zcr: 0.5, peak: 0.6}
        send(ControlLoop, {:metrics, metrics})
      end

      Process.sleep(100)

      :sys.replace_state(ControlLoop, fn s ->
        %{s | last_action_timestamp: System.monotonic_time(:millisecond) - 31_000}
      end)

      metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      history = InMemory.get_history()
      assert history == []
    end

    test "does not trigger if not enough history" do
      InMemory.clear_history()

      for _i <- 1..20 do
        metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
        send(ControlLoop, {:metrics, metrics})
      end

      Process.sleep(100)

      :sys.replace_state(ControlLoop, fn s ->
        %{s | last_action_timestamp: System.monotonic_time(:millisecond) - 31_000}
      end)

      metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      history = InMemory.get_history()
      assert history == []
    end

    test "does not trigger if not enough time has passed" do
      InMemory.clear_history()

      for _i <- 1..30 do
        metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
        send(ControlLoop, {:metrics, metrics})
      end

      Process.sleep(100)

      :sys.replace_state(ControlLoop, fn s ->
        %{s | last_action_timestamp: System.monotonic_time(:millisecond) - 1_000}
      end)

      metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      history = InMemory.get_history()
      assert history == []
    end

    test "triggers on first action if no previous action timestamp" do
      InMemory.clear_history()

      for _i <- 1..30 do
        metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
        send(ControlLoop, {:metrics, metrics})
      end

      Process.sleep(100)

      metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      history = InMemory.get_history()
      assert length(history) == 1
    end
  end

  describe "configuration" do
    test "reads control config from application config" do
      control_config = Application.fetch_env!(:hendrix_homeostat, :control)

      state = :sys.get_state(ControlLoop)

      assert state.config.critical_high == Keyword.fetch!(control_config, :critical_high)
      assert state.config.comfort_zone_min == Keyword.fetch!(control_config, :comfort_zone_min)
      assert state.config.comfort_zone_max == Keyword.fetch!(control_config, :comfort_zone_max)
      assert state.config.critical_low == Keyword.fetch!(control_config, :critical_low)

      assert state.config.stability_threshold ==
               Keyword.fetch!(control_config, :stability_threshold)

      assert state.config.stability_duration ==
               Keyword.fetch!(control_config, :stability_duration)
    end

    test "reads patch banks from application config" do
      patch_banks = Application.fetch_env!(:hendrix_homeostat, :patch_banks)

      state = :sys.get_state(ControlLoop)

      assert state.config.boost_bank == Keyword.fetch!(patch_banks, :boost_bank)
      assert state.config.dampen_bank == Keyword.fetch!(patch_banks, :dampen_bank)
      assert state.config.random_bank == Keyword.fetch!(patch_banks, :random_bank)
    end
  end

  describe "threshold priority" do
    test "critical high takes precedence over other conditions" do
      InMemory.clear_history()

      for _i <- 1..30 do
        metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
        send(ControlLoop, {:metrics, metrics})
      end

      Process.sleep(100)

      :sys.replace_state(ControlLoop, fn s ->
        %{s | last_action_timestamp: System.monotonic_time(:millisecond) - 31_000}
      end)

      metrics = %{rms: 0.9, zcr: 0.5, peak: 0.95}
      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      history = InMemory.get_history()
      [{:program_change, _device, patch, _timestamp}] = history
      assert patch in [10, 11, 12, 13, 14]
    end

    test "critical low takes precedence over stability check" do
      InMemory.clear_history()

      for _i <- 1..30 do
        metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
        send(ControlLoop, {:metrics, metrics})
      end

      Process.sleep(100)

      :sys.replace_state(ControlLoop, fn s ->
        %{s | last_action_timestamp: System.monotonic_time(:millisecond) - 31_000}
      end)

      metrics = %{rms: 0.02, zcr: 0.5, peak: 0.05}
      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      history = InMemory.get_history()
      [{:program_change, _device, patch, _timestamp}] = history
      assert patch in [1, 2, 3, 4, 5]
    end
  end

  describe "integration with MidiController" do
    test "uses MidiController.send_program_change for patch changes" do
      InMemory.clear_history()

      metrics = %{rms: 0.85, zcr: 0.5, peak: 0.9}
      send(ControlLoop, {:metrics, metrics})
      Process.sleep(20)

      history = InMemory.get_history()
      assert length(history) == 1
      assert match?([{:program_change, _, _, _}], history)
    end

    test "sends valid patch numbers from configured banks" do
      InMemory.clear_history()

      metrics_high = %{rms: 0.9, zcr: 0.5, peak: 0.95}
      metrics_low = %{rms: 0.01, zcr: 0.5, peak: 0.05}

      send(ControlLoop, {:metrics, metrics_high})
      send(ControlLoop, {:metrics, metrics_low})
      Process.sleep(20)

      history = InMemory.get_history()
      assert length(history) == 2

      for {_type, _device, patch, _timestamp} <- history do
        assert patch >= 0 and patch <= 98
      end
    end
  end
end
