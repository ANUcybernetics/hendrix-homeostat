defmodule HendrixHomeostat.Integration.ControlInvariantsTest do
  use ExUnit.Case

  alias HendrixHomeostat.ControlLoop
  alias HendrixHomeostat.MidiController
  alias HendrixHomeostat.MidiBackend.InMemory

  @moduledoc """
  Integration tests for core system invariants.

  These tests verify the fundamental behavior of the simplified control system
  without testing specific implementation details. The tests focus on:
  - System responds to extreme RMS values
  - Valid MIDI messages are sent
  - State is maintained correctly
  - Oscillation triggers parameter changes
  """

  setup do
    {:ok, _in_memory_pid} = start_supervised({InMemory, name: InMemory})
    InMemory.clear_history()

    {:ok, _midi_pid} = start_supervised(MidiController)

    :ok
  end

  describe "core control loop invariants" do
    test "control loop responds to extreme high metrics" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      send(control_pid, {:metrics, %{rms: 0.9, zcr: 0.5, peak: 0.9}})
      Process.sleep(50)

      history = InMemory.get_history()
      assert length(history) > 0, "Control loop should respond to extreme high metrics"
    end

    test "control loop responds to extreme low metrics" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      send(control_pid, {:metrics, %{rms: 0.05, zcr: 0.5, peak: 0.05}})
      Process.sleep(50)

      history = InMemory.get_history()
      assert length(history) > 0, "Control loop should respond to extreme low metrics"
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
      assert state.current_rms != nil, "Should have stored latest RMS"
      assert is_list(state.transition_history), "Should maintain transition history"
    end

    test "ok zone metrics do not trigger immediate actions" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      send(control_pid, {:metrics, %{rms: 0.2, zcr: 0.5, peak: 0.2}})
      send(control_pid, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.3}})
      send(control_pid, {:metrics, %{rms: 0.25, zcr: 0.5, peak: 0.25}})
      Process.sleep(50)

      history = InMemory.get_history()

      assert length(history) == 0,
             "Ok zone metrics should not trigger actions"
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
    test "control loop reads configuration from RuntimeConfig" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      state = :sys.get_state(control_pid)
      config = state.config

      assert is_float(config.too_loud)
      assert is_float(config.too_quiet)
      assert is_integer(config.oscillation_threshold)

      assert config.too_loud >= 0.0 and config.too_loud <= 1.0
      assert config.too_quiet >= 0.0 and config.too_quiet <= 1.0
      assert config.too_quiet < config.too_loud
    end
  end

  describe "oscillation response" do
    test "repeated oscillation triggers ultrastable reconfiguration" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      # Create sustained oscillation pattern
      for i <- 1..20 do
        rms = if rem(i, 2) == 0, do: 0.9, else: 0.05
        send(control_pid, {:metrics, %{rms: rms, zcr: 0.5, peak: rms}})
        Process.sleep(10)
      end

      Process.sleep(100)

      history = InMemory.get_history()

      # Should have sent volume change commands during ultrastable reconfiguration
      volume_changes =
        Enum.filter(history, fn
          {:control_change, _, cc, _, _} ->
            # Track volume CCs (7 and 8 based on rc600_cc_map)
            cc in [7, 8]

          _ ->
            false
        end)

      assert length(volume_changes) > 0,
             "Sustained oscillation should trigger volume parameter changes"
    end

    test "non-oscillating behavior does not trigger reconfiguration" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      # Send just a few extremes, not enough to be considered oscillating
      send(control_pid, {:metrics, %{rms: 0.9, zcr: 0.5, peak: 0.9}})
      Process.sleep(20)
      send(control_pid, {:metrics, %{rms: 0.05, zcr: 0.5, peak: 0.05}})
      Process.sleep(20)
      send(control_pid, {:metrics, %{rms: 0.9, zcr: 0.5, peak: 0.9}})
      Process.sleep(50)

      history = InMemory.get_history()

      # Should have track control messages but no volume changes
      volume_changes =
        Enum.filter(history, fn
          {:control_change, _, cc, _, _} -> cc in [7, 8]
          _ -> false
        end)

      assert length(volume_changes) == 0,
             "Limited transitions should not trigger parameter changes"
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
        rms = if rem(i, 2) == 0, do: 0.9, else: 0.05
        send(control_pid, {:metrics, %{rms: rms, zcr: 0.5, peak: rms}})
        Process.sleep(20)
      end

      history = InMemory.get_history()

      if length(history) >= 2 do
        timestamps = Enum.map(history, fn {:control_change, _, _, _, ts} -> ts end)
        sorted_timestamps = Enum.sort(timestamps, DateTime)

        assert timestamps == sorted_timestamps,
               "Timestamps should be monotonically increasing"
      end
    end
  end

  describe "realistic control scenarios" do
    test "gradual increase in level eventually triggers action" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      # Gradually increase RMS
      for i <- 1..10 do
        rms = 0.1 + i * 0.08
        send(control_pid, {:metrics, %{rms: rms, zcr: 0.5, peak: rms}})
        Process.sleep(10)
      end

      history = InMemory.get_history()

      assert length(history) > 0, "Gradual increase should eventually trigger action"
    end

    test "stable ok zone maintains state without actions" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      # Send many samples in the ok zone (between too_quiet and too_loud)
      for _ <- 1..20 do
        send(control_pid, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.3}})
        Process.sleep(5)
      end

      Process.sleep(50)

      history = InMemory.get_history()

      assert length(history) == 0, "Stable ok zone should not trigger actions"
    end

    test "alternating extremes creates oscillation" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      InMemory.clear_history()

      # Create clear oscillation pattern
      for i <- 1..15 do
        rms = if rem(i, 2) == 0, do: 0.95, else: 0.02
        send(control_pid, {:metrics, %{rms: rms, zcr: 0.5, peak: rms}})
        Process.sleep(10)
      end

      Process.sleep(100)

      state = :sys.get_state(control_pid)

      # Transition history should show the pattern
      assert length(state.transition_history) > 0,
             "Alternating extremes should be recorded as transitions"
    end
  end
end
