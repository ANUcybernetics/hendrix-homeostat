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
      assert state.current_metrics == nil
      assert state.metrics_history == []
      assert state.last_action_timestamp == nil

      stop_supervised(ControlLoop)
    end

    test "has correct child_spec" do
      spec = ControlLoop.child_spec([])
      assert spec.id == ControlLoop
      assert spec.shutdown == 5_000
    end
  end

  describe "receiving metrics" do
    test "updates current_metrics and history" do
      metrics1 = %{rms: 0.3, zcr: 0.5, peak: 0.6}
      metrics2 = %{rms: 0.35, zcr: 0.55, peak: 0.65}

      send(ControlLoop, {:metrics, metrics1})
      send(ControlLoop, {:metrics, metrics2})
      Process.sleep(20)

      state = :sys.get_state(ControlLoop)
      assert state.current_metrics == metrics2
      assert state.metrics_history == [0.35, 0.3]
    end

    test "maintains bounded history" do
      for i <- 1..50 do
        metrics = %{rms: i / 100, zcr: 0.5, peak: 0.6}
        send(ControlLoop, {:metrics, metrics})
      end

      Process.sleep(100)

      state = :sys.get_state(ControlLoop)
      assert length(state.metrics_history) <= 30
    end
  end

  describe "configuration" do
    test "loads config from application environment" do
      control_config = Application.fetch_env!(:hendrix_homeostat, :control)
      state = :sys.get_state(ControlLoop)

      assert state.config.critical_high == Keyword.fetch!(control_config, :critical_high)
      assert state.config.comfort_zone_min == Keyword.fetch!(control_config, :comfort_zone_min)
      assert state.config.comfort_zone_max == Keyword.fetch!(control_config, :comfort_zone_max)
      assert state.config.critical_low == Keyword.fetch!(control_config, :critical_low)
    end
  end
end
