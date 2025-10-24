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

      # Send metrics that should trigger some response
      send(control_pid, {:metrics, %{rms: 0.9, zcr: 0.5, peak: 0.9}})
      Process.sleep(50)

      # System should have sent SOME MIDI command
      history = InMemory.get_history()
      assert length(history) > 0, "Control loop should respond to extreme metrics"
    end

    test "control loop sends valid MIDI messages" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      # Trigger various states
      send(control_pid, {:metrics, %{rms: 0.9, zcr: 0.5, peak: 0.9}})
      send(control_pid, {:metrics, %{rms: 0.01, zcr: 0.5, peak: 0.01}})
      Process.sleep(100)

      history = InMemory.get_history()

      # All MIDI messages should be valid
      Enum.each(history, fn
        {:control_change, _device, cc, value, _timestamp} ->
          assert cc >= 0 and cc <= 127, "CC number must be 0-127"
          assert value >= 0 and value <= 127, "CC value must be 0-127"

        {:program_change, _device, pc, _timestamp} ->
          assert pc >= 0 and pc <= 127, "Program change must be 0-127"

        other ->
          flunk("Unexpected MIDI message type: #{inspect(other)}")
      end)
    end

    test "control loop maintains state across multiple metric updates" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      # Send several metrics
      send(control_pid, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.3}})
      send(control_pid, {:metrics, %{rms: 0.4, zcr: 0.5, peak: 0.4}})
      send(control_pid, {:metrics, %{rms: 0.35, zcr: 0.5, peak: 0.35}})
      Process.sleep(100)

      # Control loop should still be alive and responsive
      state = :sys.get_state(control_pid)
      assert state.current_metrics != nil, "Should have stored latest metrics"
      assert is_list(state.metrics_history), "Should maintain metrics history"
    end

    test "comfort zone metrics do not immediately trigger actions" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      # Send comfortable metrics
      send(control_pid, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.3}})
      send(control_pid, {:metrics, %{rms: 0.35, zcr: 0.5, peak: 0.35}})
      Process.sleep(50)

      history = InMemory.get_history()

      # Should not have sent commands for comfortable metrics
      assert length(history) == 0,
             "Comfort zone metrics should not trigger immediate actions"
    end

    test "extreme high values trigger control response" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      # Send very high metrics
      send(control_pid, {:metrics, %{rms: 0.95, zcr: 0.5, peak: 0.95}})
      Process.sleep(50)

      history = InMemory.get_history()

      assert length(history) > 0, "Extreme high values should trigger response"
    end

    test "extreme low values trigger control response" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      # Send very low metrics
      send(control_pid, {:metrics, %{rms: 0.01, zcr: 0.5, peak: 0.01}})
      Process.sleep(50)

      history = InMemory.get_history()

      assert length(history) > 0, "Extreme low values should trigger response"
    end

    test "control loop tracks time of last action" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      initial_state = :sys.get_state(control_pid)
      assert initial_state.last_action_timestamp == nil

      # Trigger an action
      send(control_pid, {:metrics, %{rms: 0.95, zcr: 0.5, peak: 0.95}})
      Process.sleep(50)

      final_state = :sys.get_state(control_pid)

      # If an action was taken, timestamp should be updated
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

      # Send many metrics
      for i <- 1..100 do
        rms = 0.3 + i * 0.001
        send(control_pid, {:metrics, %{rms: rms, zcr: 0.5, peak: rms}})
      end

      Process.sleep(100)

      state = :sys.get_state(control_pid)

      # History should be bounded (not grow infinitely)
      assert length(state.metrics_history) <= 30,
             "Metrics history should be bounded to prevent memory growth"
    end
  end

  describe "MIDI controller integration" do
    test "MIDI controller is accessible from control loop" do
      {:ok, _control_pid} = start_supervised(ControlLoop)

      # MidiController should be registered and alive
      midi_pid = Process.whereis(MidiController)
      assert midi_pid != nil, "MidiController should be registered"
      assert Process.alive?(midi_pid), "MidiController should be alive"
    end

    test "control loop can send MIDI commands via controller" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      # Trigger control loop to send MIDI
      send(control_pid, {:metrics, %{rms: 0.95, zcr: 0.5, peak: 0.95}})
      Process.sleep(50)

      history = InMemory.get_history()

      # Should have received MIDI commands through the backend
      if length(history) > 0 do
        assert Enum.all?(history, fn msg ->
                 match?({:control_change, _, _, _, _}, msg) or
                   match?({:program_change, _, _, _}, msg)
               end)
      end
    end
  end

  describe "configuration integration" do
    test "control loop reads thresholds from config" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      state = :sys.get_state(control_pid)
      config = state.config

      # Should have loaded threshold config
      assert is_float(config.critical_high)
      assert is_float(config.critical_low)
      assert is_float(config.comfort_zone_min)
      assert is_float(config.comfort_zone_max)

      # Thresholds should be in valid range
      assert config.critical_high >= 0.0 and config.critical_high <= 1.0
      assert config.critical_low >= 0.0 and config.critical_low <= 1.0

      # Thresholds should be logically ordered
      assert config.critical_low < config.comfort_zone_min
      assert config.comfort_zone_min < config.comfort_zone_max
      assert config.comfort_zone_max < config.critical_high
    end
  end
end
