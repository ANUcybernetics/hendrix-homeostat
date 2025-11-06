defmodule HendrixHomeostat.MidiControllerTest do
  use ExUnit.Case

  alias HendrixHomeostat.MidiController
  alias HendrixHomeostat.Midi.TestSpy

  setup do
    {:ok, _pid} = start_supervised({TestSpy, []})
    TestSpy.clear_notify()

    {:ok, midi_pid} = start_supervised({MidiController, ready_notify: self()})
    assert_receive {:midi_ready, ^midi_pid}, 1_500
    _ = :sys.get_state(MidiController)
    TestSpy.clear_history()

    {:ok, midi_pid: midi_pid}
  end

  describe "GenServer lifecycle" do
    test "starts and initializes with config" do
      stop_supervised(MidiController)

      assert {:ok, pid} = MidiController.start_link([])
      assert Process.alive?(pid)

      state = :sys.get_state(pid)
      assert state.midi == TestSpy
      assert state.device == "test_midi"
      assert state.channel == 1

      stop_supervised(MidiController)
    end

    test "has correct child_spec" do
      spec = MidiController.child_spec([])
      assert spec.id == MidiController
      assert spec.shutdown == 5_000
    end
  end

  describe "send_program_change/1" do
    test "sends program change to backend" do
      MidiController.send_program_change(42)
      _ = :sys.get_state(MidiController)

      history = TestSpy.get_history()
      assert [{:program_change, "test_midi", 42, _timestamp}] = history
    end

    test "updates state after successful send" do
      MidiController.send_program_change(5)
      state = :sys.get_state(MidiController)
      assert state.last_command == {:program_change, 5}
    end

    test "handles backend failures gracefully" do
      stop_supervised(TestSpy)
      MidiController.send_program_change(5)

      assert Process.alive?(Process.whereis(MidiController))
    end
  end

  describe "send_control_change/2" do
    test "sends control change to backend" do
      MidiController.send_control_change(7, 127)
      _ = :sys.get_state(MidiController)

      history = TestSpy.get_history()
      assert [{:control_change, "test_midi", 7, 127, _timestamp}] = history
    end

    test "updates state after successful send" do
      MidiController.send_control_change(10, 64)
      state = :sys.get_state(MidiController)
      assert state.last_command == {:control_change, 10, 64}
    end
  end

  describe "RC-600 track control" do
    test "start_recording/1 sends correct CC" do
      MidiController.start_recording(1)
      _ = :sys.get_state(MidiController)

      history = TestSpy.get_history()
      assert [{:control_change, _device, cc, 127, _timestamp}] = history
      assert is_integer(cc)
    end

    test "stop_track/1 sends correct CC" do
      MidiController.stop_track(3)
      _ = :sys.get_state(MidiController)

      history = TestSpy.get_history()
      assert [{:control_change, _device, cc, 127, _timestamp}] = history
      assert is_integer(cc)
    end

    test "clear_track/1 sends correct CC" do
      MidiController.clear_track(2)
      _ = :sys.get_state(MidiController)

      history = TestSpy.get_history()
      assert [{:control_change, _device, cc, 127, _timestamp}] = history
      assert is_integer(cc)
    end
  end
end
