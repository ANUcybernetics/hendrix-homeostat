defmodule HendrixHomeostat.MidiControllerTest do
  use ExUnit.Case

  alias HendrixHomeostat.MidiController
  alias HendrixHomeostat.Midi.TestSpy

  setup do
    {:ok, _pid} = start_supervised({TestSpy, []})
    TestSpy.clear_history()

    {:ok, _pid} = start_supervised(MidiController)

    :ok
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
      # Need to wait for handle_continue to complete (1000ms sleep + clear_all_tracks)
      Process.sleep(1100)
      TestSpy.clear_history()

      MidiController.send_program_change(42)
      Process.sleep(20)

      history = TestSpy.get_history()
      assert [{:program_change, "test_midi", 42, _timestamp}] = history
    end

    test "updates state after successful send" do
      Process.sleep(1100)

      MidiController.send_program_change(5)
      Process.sleep(20)

      state = :sys.get_state(MidiController)
      assert state.last_command == {:program_change, 5}
    end

    test "handles backend failures gracefully" do
      Process.sleep(1100)
      stop_supervised(TestSpy)
      MidiController.send_program_change(5)
      Process.sleep(20)

      assert Process.alive?(Process.whereis(MidiController))
    end
  end

  describe "send_control_change/2" do
    test "sends control change to backend" do
      Process.sleep(1100)
      TestSpy.clear_history()

      MidiController.send_control_change(7, 127)
      Process.sleep(20)

      history = TestSpy.get_history()
      assert [{:control_change, "test_midi", 7, 127, _timestamp}] = history
    end

    test "updates state after successful send" do
      Process.sleep(1100)

      MidiController.send_control_change(10, 64)
      Process.sleep(20)

      state = :sys.get_state(MidiController)
      assert state.last_command == {:control_change, 10, 64}
    end
  end

  describe "RC-600 track control" do
    test "start_recording/1 sends correct CC" do
      Process.sleep(1100)
      TestSpy.clear_history()

      MidiController.start_recording(1)
      Process.sleep(20)

      history = TestSpy.get_history()
      assert [{:control_change, _device, cc, 127, _timestamp}] = history
      assert is_integer(cc)
    end

    test "stop_track/1 sends correct CC" do
      Process.sleep(1100)
      TestSpy.clear_history()

      MidiController.stop_track(3)
      Process.sleep(20)

      history = TestSpy.get_history()
      assert [{:control_change, _device, cc, 127, _timestamp}] = history
      assert is_integer(cc)
    end

    test "clear_track/1 sends correct CC" do
      Process.sleep(1100)
      TestSpy.clear_history()

      MidiController.clear_track(2)
      Process.sleep(20)

      history = TestSpy.get_history()
      assert [{:control_change, _device, cc, 127, _timestamp}] = history
      assert is_integer(cc)
    end
  end
end
