defmodule HendrixHomeostat.MidiControllerTest do
  use ExUnit.Case, async: true

  alias HendrixHomeostat.MidiController

  describe "GenServer lifecycle on hardware" do
    @describetag :target_only

    setup do
      {:ok, midi_pid} =
        start_supervised({MidiController, ready_notify: self(), startup_delay_ms: 0})

      assert_receive {:midi_ready, ^midi_pid}, 100

      :ok
    end

    test "starts and initializes with config" do
      stop_supervised(MidiController)

      assert {:ok, pid} = MidiController.start_link([])
      assert Process.alive?(pid)

      state = :sys.get_state(pid)
      assert state.midi == HendrixHomeostat.Midi.Amidi
      assert state.device == "hw:CARD=R24,DEV=0"
      assert state.channel == 1

      stop_supervised(MidiController)
    end

    test "send_program_change/1 updates state" do
      MidiController.send_program_change(5)

      # GenServer calls are synchronous, so state should be updated immediately
      state = :sys.get_state(MidiController)
      assert state.last_command == {:program_change, 5}
    end

    test "send_control_change/2 updates state" do
      MidiController.send_control_change(10, 64)

      # GenServer calls are synchronous, so state should be updated immediately
      state = :sys.get_state(MidiController)
      assert state.last_command == {:control_change, 10, 64}
    end
  end

  describe "child_spec" do
    test "has correct child_spec" do
      spec = MidiController.child_spec([])
      assert spec.id == MidiController
      assert spec.shutdown == 5_000
    end
  end

  describe "RC-600 track control API" do
    test "start_recording/1 accepts valid track numbers" do
      assert :ok = MidiController.start_recording(1)
      assert :ok = MidiController.start_recording(6)
    end

    test "stop_track/1 accepts valid track numbers" do
      assert :ok = MidiController.stop_track(1)
      assert :ok = MidiController.stop_track(6)
    end

    test "clear_track/1 accepts valid track numbers" do
      assert :ok = MidiController.clear_track(1)
      assert :ok = MidiController.clear_track(4)
    end

    test "set_track_volume/1 accepts valid track numbers and values" do
      assert :ok = MidiController.set_track_volume(1, 0)
      assert :ok = MidiController.set_track_volume(2, 127)
    end

    test "clear_all_tracks/0 completes without error" do
      assert :ok = MidiController.clear_all_tracks()
    end
  end
end
