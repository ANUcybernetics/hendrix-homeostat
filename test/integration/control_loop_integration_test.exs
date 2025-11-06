defmodule HendrixHomeostat.Integration.ControlLoopIntegrationTest do
  use ExUnit.Case, async: false

  alias HendrixHomeostat.ControlLoop
  alias HendrixHomeostat.MidiController
  alias HendrixHomeostat.Midi.TestSpy

  setup do
    {:ok, _spy_pid} = start_supervised({TestSpy, []})
    TestSpy.set_notify(self())

    {:ok, midi_pid} =
      start_supervised({MidiController, ready_notify: self(), startup_delay_ms: 0})

    assert_receive {:midi_ready, ^midi_pid}, 100

    _ = :sys.get_state(MidiController)
    drain_midi_events()
    TestSpy.clear_history()

    :ok
  end

  describe "control orchestration" do
    test "extreme RMS values trigger MIDI actions" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      send(control_pid, {:metrics, %{rms: 0.92, zcr: 0.4, peak: 0.92}})

      assert_receive {:midi_event, {:control_change, _device, _cc, _value, _timestamp}}, 500
    end

    test "oscillation drives ultrastable reconfiguration" do
      {:ok, control_pid} = start_supervised(ControlLoop)

      for i <- 1..20 do
        rms = if rem(i, 2) == 0, do: 0.9, else: 0.05
        send(control_pid, {:metrics, %{rms: rms, zcr: 0.5, peak: rms}})
      end

      assert_volume_change()
    end
  end

  defp drain_midi_events do
    receive do
      {:midi_event, _} -> drain_midi_events()
    after
      0 -> :ok
    end
  end

  defp assert_volume_change(timeout \\ 500) do
    deadline = System.monotonic_time(:millisecond) + timeout
    wait_for_volume_change(deadline)
  end

  defp wait_for_volume_change(deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      flunk("expected a volume control change (cc 7 or 8)")
    end

    receive do
      {:midi_event, {:control_change, _device, cc, _value, _timestamp}} when cc in [7, 8] ->
        :ok

      {:midi_event, _other} ->
        wait_for_volume_change(deadline)
    after
      remaining ->
        flunk("expected a volume control change (cc 7 or 8)")
    end
  end
end
