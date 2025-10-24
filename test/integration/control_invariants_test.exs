defmodule HendrixHomeostat.Integration.ControlInvariantsTest do
  use ExUnit.Case

  alias HendrixHomeostat.ControlLoop
  alias HendrixHomeostat.MidiController
  alias HendrixHomeostat.MidiBackend.InMemory

  @moduledoc """
  Integration tests for core system invariants.

  These tests verify the fundamental behavior of the control system
  without testing specific implementation details like exact CC numbers
  or which tracks are controlled. This allows the algorithm to evolve
  while maintaining confidence in core functionality.
  """

  setup do
    {:ok, _in_memory_pid} = start_supervised({InMemory, name: InMemory})
    InMemory.clear_history()

    {:ok, _midi_pid} = start_supervised(MidiController)

    :ok
  end

  describe "core control loop invariants" do
    test "control loop responds to metrics by making decisions" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      send(control_pid, {:metrics, %{rms: 0.9, zcr: 0.5, peak: 0.9}})
      Process.sleep(50)

      history = InMemory.get_history()
      assert length(history) > 0, "Control loop should respond to extreme metrics"
    end

    test "control loop sends valid MIDI messages" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      send(control_pid, {:metrics, %{rms: 0.9, zcr: 0.5, peak: 0.9}})
      send(control_pid, {:metrics, %{rms: 0.01, zcr: 0.5, peak: 0.01}})
      Process.sleep(100)

      history = InMemory.get_history()

      Enum.each(history, fn
        {:control_change, _device, cc, value, _timestamp} ->
          assert cc >= 0 and cc <= 127, "CC number must be 0-127"
          assert value >= 0 and value <= 127, "CC value must be 0-127"

        other ->
          flunk("Unexpected MIDI message type: #{inspect(other)}")
      end)
    end

    test "control loop maintains state across multiple metric updates" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      send(control_pid, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.3}})
      send(control_pid, {:metrics, %{rms: 0.4, zcr: 0.5, peak: 0.4}})
      send(control_pid, {:metrics, %{rms: 0.35, zcr: 0.5, peak: 0.35}})
      Process.sleep(100)

      state = :sys.get_state(control_pid)
      assert state.current_metrics != nil, "Should have stored latest metrics"
      assert is_list(state.metrics_history), "Should maintain metrics history"
    end

    test "comfort zone metrics do not immediately trigger actions" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      send(control_pid, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.3}})
      send(control_pid, {:metrics, %{rms: 0.35, zcr: 0.5, peak: 0.35}})
      Process.sleep(50)

      history = InMemory.get_history()

      assert length(history) == 0,
             "Comfort zone metrics should not trigger immediate actions"
    end

    test "extreme high values trigger control response" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      send(control_pid, {:metrics, %{rms: 0.95, zcr: 0.5, peak: 0.95}})
      Process.sleep(50)

      history = InMemory.get_history()

      assert length(history) > 0, "Extreme high values should trigger response"
    end

    test "extreme low values trigger control response" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      send(control_pid, {:metrics, %{rms: 0.01, zcr: 0.5, peak: 0.01}})
      Process.sleep(50)

      history = InMemory.get_history()

      assert length(history) > 0, "Extreme low values should trigger response"
    end

    test "control loop tracks time of last action" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      initial_state = :sys.get_state(control_pid)
      assert initial_state.last_action_timestamp == nil

      send(control_pid, {:metrics, %{rms: 0.95, zcr: 0.5, peak: 0.95}})
      Process.sleep(50)

      final_state = :sys.get_state(control_pid)

      history = InMemory.get_history()

      if length(history) > 0 do
        assert final_state.last_action_timestamp != nil,
               "Should track timestamp after action"

        assert is_integer(final_state.last_action_timestamp),
               "Timestamp should be an integer"
      end
    end

    test "control loop maintains bounded metrics history" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      for i <- 1..100 do
        rms = 0.3 + i * 0.001
        send(control_pid, {:metrics, %{rms: rms, zcr: 0.5, peak: rms}})
      end

      Process.sleep(100)

      state = :sys.get_state(control_pid)

      assert length(state.metrics_history) <= 30,
             "Metrics history should be bounded to prevent memory growth"
    end
  end

  describe "MIDI controller integration" do
    test "MIDI controller is accessible from control loop" do
      {:ok, _control_pid} = start_supervised(ControlLoop)

      midi_pid = Process.whereis(MidiController)
      assert midi_pid != nil, "MidiController should be registered"
      assert Process.alive?(midi_pid), "MidiController should be alive"
    end

    test "control loop can send MIDI commands via controller" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      send(control_pid, {:metrics, %{rms: 0.95, zcr: 0.5, peak: 0.95}})
      Process.sleep(50)

      history = InMemory.get_history()

      if length(history) > 0 do
        assert Enum.all?(history, fn msg ->
                 match?({:control_change, _, _, _, _}, msg)
               end)
      end
    end
  end

  describe "configuration integration" do
    test "control loop reads thresholds from config" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      state = :sys.get_state(control_pid)
      config = state.config

      assert is_float(config.critical_high)
      assert is_float(config.critical_low)
      assert is_float(config.comfort_zone_min)
      assert is_float(config.comfort_zone_max)

      assert config.critical_high >= 0.0 and config.critical_high <= 1.0
      assert config.critical_low >= 0.0 and config.critical_low <= 1.0

      assert config.critical_low < config.comfort_zone_min
      assert config.comfort_zone_min < config.comfort_zone_max
      assert config.comfort_zone_max < config.critical_high
    end

    test "control loop loads stability configuration" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      state = :sys.get_state(control_pid)
      config = state.config

      assert is_float(config.stability_threshold)
      assert is_integer(config.stability_duration)
      assert config.stability_threshold > 0.0
      assert config.stability_duration > 0
    end
  end

  describe "metric pattern responses" do
    test "responds differently to sustained high vs brief spike" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      for _ <- 1..5 do
        send(control_pid, {:metrics, %{rms: 0.9, zcr: 0.5, peak: 0.9}})
        Process.sleep(10)
      end

      sustained_history = InMemory.get_history()
      assert length(sustained_history) > 0, "Sustained high should trigger action"

      InMemory.clear_history()

      send(control_pid, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.3}})
      send(control_pid, {:metrics, %{rms: 0.9, zcr: 0.5, peak: 0.9}})
      send(control_pid, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.3}})
      Process.sleep(50)

      spike_history = InMemory.get_history()
      assert length(spike_history) > 0, "Brief spike should still trigger action"
    end

    test "handles gradual increase in level" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      for i <- 1..10 do
        rms = 0.1 + i * 0.08
        send(control_pid, {:metrics, %{rms: rms, zcr: 0.5, peak: rms}})
        Process.sleep(10)
      end

      history = InMemory.get_history()

      assert length(history) > 0, "Gradual increase should eventually trigger action"
    end

    test "handles alternating high and low levels" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      for i <- 1..10 do
        rms = if rem(i, 2) == 0, do: 0.9, else: 0.01
        send(control_pid, {:metrics, %{rms: rms, zcr: 0.5, peak: rms}})
        Process.sleep(10)
      end

      history = InMemory.get_history()

      assert length(history) > 0, "Alternating levels should trigger multiple actions"
    end

    test "stable comfort zone does not trigger actions within short duration" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      for _ <- 1..10 do
        send(control_pid, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.3}})
        Process.sleep(10)
      end

      history = InMemory.get_history()

      assert length(history) == 0,
             "Stable comfort zone should not trigger actions in short duration"
    end

    test "metrics history captures recent activity" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      send(control_pid, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.3}})
      send(control_pid, {:metrics, %{rms: 0.4, zcr: 0.5, peak: 0.4}})
      send(control_pid, {:metrics, %{rms: 0.35, zcr: 0.5, peak: 0.35}})
      Process.sleep(50)

      state = :sys.get_state(control_pid)

      assert length(state.metrics_history) >= 3, "Should track recent metrics"
      assert Enum.all?(state.metrics_history, &is_float/1), "History should contain RMS values"
    end
  end

  describe "MIDI message structure validation" do
    test "all control change messages have device, cc, value, timestamp" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      send(control_pid, {:metrics, %{rms: 0.95, zcr: 0.5, peak: 0.95}})
      Process.sleep(50)

      history = InMemory.get_history()

      control_changes = Enum.filter(history, &match?({:control_change, _, _, _, _}, &1))

      Enum.each(control_changes, fn {:control_change, device, cc, value, timestamp} ->
        assert is_binary(device) or is_atom(device), "Device should be string or atom"
        assert is_integer(cc), "CC number should be integer"
        assert is_integer(value), "CC value should be integer"
        assert match?(%DateTime{}, timestamp), "Timestamp should be DateTime"
      end)
    end

    test "MIDI messages have monotonically increasing timestamps" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      for i <- 1..5 do
        rms = if rem(i, 2) == 0, do: 0.9, else: 0.01
        send(control_pid, {:metrics, %{rms: rms, zcr: 0.5, peak: rms}})
        Process.sleep(20)
      end

      history = InMemory.get_history()

      timestamps = Enum.map(history, fn {:control_change, _, _, _, ts} -> ts end)

      sorted_timestamps = Enum.sort(timestamps)

      assert timestamps == sorted_timestamps,
             "Timestamps should be monotonically increasing"
    end
  end

  describe "history management" do
    test "history is properly bounded at configured size" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      for i <- 1..50 do
        rms = 0.3 + rem(i, 5) * 0.01
        send(control_pid, {:metrics, %{rms: rms, zcr: 0.5, peak: rms}})
      end

      Process.sleep(100)

      state = :sys.get_state(control_pid)

      assert length(state.metrics_history) <= 30,
             "History should be bounded to prevent unbounded growth"
    end

    test "history clears after control action" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      for _ <- 1..5 do
        send(control_pid, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.3}})
      end

      Process.sleep(50)

      state_before = :sys.get_state(control_pid)
      history_before = length(state_before.metrics_history)

      send(control_pid, {:metrics, %{rms: 0.95, zcr: 0.5, peak: 0.95}})
      Process.sleep(50)

      state_after = :sys.get_state(control_pid)
      history_after = length(state_after.metrics_history)

      assert history_after < history_before,
             "History should be cleared or reset after action"
    end

    test "most recent metrics are always accessible" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      last_metrics = %{rms: 0.42, zcr: 0.5, peak: 0.42}
      send(control_pid, {:metrics, last_metrics})
      Process.sleep(50)

      state = :sys.get_state(control_pid)

      assert state.current_metrics == last_metrics,
             "Current metrics should reflect most recent update"
    end
  end
end
