defmodule HendrixHomeostat.MidiControllerTest do
  use ExUnit.Case

  alias HendrixHomeostat.MidiController
  alias HendrixHomeostat.MidiBackend.InMemory

  setup do
    {:ok, _pid} = start_supervised({InMemory, name: InMemory})
    InMemory.clear_history()

    {:ok, _pid} = start_supervised(MidiController)

    :ok
  end

  describe "GenServer lifecycle" do
    test "starts with start_link/1" do
      stop_supervised(MidiController)

      assert {:ok, pid} = MidiController.start_link([])
      assert Process.alive?(pid)

      stop_supervised(MidiController)
    end

    test "initializes with correct state from config" do
      state = :sys.get_state(MidiController)

      assert state.backend == HendrixHomeostat.MidiBackend.InMemory
      assert state.device == "test_midi"
      assert state.channel == 1
      assert state.last_command == nil
    end

    test "terminates gracefully" do
      pid = Process.whereis(MidiController)
      assert Process.alive?(pid)

      stop_supervised(MidiController)

      refute Process.alive?(pid)
    end

    test "has correct child_spec" do
      spec = MidiController.child_spec([])

      assert spec.id == MidiController
      assert spec.start == {MidiController, :start_link, [[]]}
      assert spec.shutdown == 5_000
    end
  end

  describe "send_program_change/1" do
    test "sends program change to backend" do
      MidiController.send_program_change(5)
      Process.sleep(10)

      history = InMemory.get_history()
      assert length(history) == 1

      [{:program_change, device, memory, _timestamp}] = history
      assert device == "test_midi"
      assert memory == 5
    end

    test "sends program change with minimum valid value" do
      MidiController.send_program_change(0)
      Process.sleep(10)

      history = InMemory.get_history()
      [{:program_change, _device, memory, _timestamp}] = history
      assert memory == 0
    end

    test "sends program change with maximum valid value" do
      MidiController.send_program_change(98)
      Process.sleep(10)

      history = InMemory.get_history()
      [{:program_change, _device, memory, _timestamp}] = history
      assert memory == 98
    end

    test "rejects negative memory numbers" do
      assert_raise FunctionClauseError, fn ->
        MidiController.send_program_change(-1)
      end
    end

    test "rejects memory numbers above 98" do
      assert_raise FunctionClauseError, fn ->
        MidiController.send_program_change(99)
      end

      assert_raise FunctionClauseError, fn ->
        MidiController.send_program_change(127)
      end
    end

    test "handles backend failures gracefully" do
      stop_supervised(InMemory)

      MidiController.send_program_change(5)
      Process.sleep(10)

      history = InMemory.get_history()
      assert history == []
    end

    test "updates state after successful send" do
      MidiController.send_program_change(42)
      Process.sleep(10)

      state = :sys.get_state(MidiController)
      assert state.last_command == {:program_change, 42}
    end

    test "does not update state on backend failure" do
      initial_state = :sys.get_state(MidiController)

      stop_supervised(InMemory)
      MidiController.send_program_change(5)
      Process.sleep(10)

      final_state = :sys.get_state(MidiController)
      assert final_state.last_command == initial_state.last_command
    end
  end

  describe "send_control_change/2" do
    test "sends control change to backend" do
      MidiController.send_control_change(7, 127)
      Process.sleep(10)

      history = InMemory.get_history()
      assert length(history) == 1

      [{:control_change, device, cc, value, _timestamp}] = history
      assert device == "test_midi"
      assert cc == 7
      assert value == 127
    end

    test "sends CC with minimum valid values" do
      MidiController.send_control_change(0, 0)
      Process.sleep(10)

      history = InMemory.get_history()
      [{:control_change, _device, cc, value, _timestamp}] = history
      assert cc == 0
      assert value == 0
    end

    test "sends CC with maximum valid values" do
      MidiController.send_control_change(127, 127)
      Process.sleep(10)

      history = InMemory.get_history()
      [{:control_change, _device, cc, value, _timestamp}] = history
      assert cc == 127
      assert value == 127
    end

    test "rejects negative CC numbers" do
      assert_raise FunctionClauseError, fn ->
        MidiController.send_control_change(-1, 64)
      end
    end

    test "rejects CC numbers above 127" do
      assert_raise FunctionClauseError, fn ->
        MidiController.send_control_change(128, 64)
      end
    end

    test "rejects negative values" do
      assert_raise FunctionClauseError, fn ->
        MidiController.send_control_change(7, -1)
      end
    end

    test "rejects values above 127" do
      assert_raise FunctionClauseError, fn ->
        MidiController.send_control_change(7, 128)
      end
    end

    test "handles backend failures gracefully" do
      stop_supervised(InMemory)

      MidiController.send_control_change(7, 64)
      Process.sleep(10)

      history = InMemory.get_history()
      assert history == []
    end

    test "updates state after successful send" do
      MidiController.send_control_change(10, 100)
      Process.sleep(10)

      state = :sys.get_state(MidiController)
      assert state.last_command == {:control_change, 10, 100}
    end

    test "does not update state on backend failure" do
      initial_state = :sys.get_state(MidiController)

      stop_supervised(InMemory)
      MidiController.send_control_change(7, 64)
      Process.sleep(10)

      final_state = :sys.get_state(MidiController)
      assert final_state.last_command == initial_state.last_command
    end
  end

  describe "backend integration" do
    test "uses configured backend module" do
      state = :sys.get_state(MidiController)
      assert state.backend == HendrixHomeostat.MidiBackend.InMemory
    end

    test "uses configured device name" do
      MidiController.send_program_change(1)
      Process.sleep(10)

      [{:program_change, device, _memory, _timestamp}] = InMemory.get_history()
      assert device == "test_midi"
    end

    test "maintains command history in correct order" do
      MidiController.send_program_change(1)
      MidiController.send_control_change(7, 64)
      MidiController.send_program_change(2)
      MidiController.send_control_change(10, 100)
      Process.sleep(20)

      history = InMemory.get_history()
      assert length(history) == 4

      [first, second, third, fourth] = history
      assert match?({:program_change, _, 1, _}, first)
      assert match?({:control_change, _, 7, 64, _}, second)
      assert match?({:program_change, _, 2, _}, third)
      assert match?({:control_change, _, 10, 100, _}, fourth)
    end

    test "backend receives all parameters correctly" do
      MidiController.send_program_change(42)
      MidiController.send_control_change(11, 99)
      Process.sleep(10)

      history = InMemory.get_history()
      [pc, cc] = history

      assert {:program_change, "test_midi", 42, %DateTime{}} = pc
      assert {:control_change, "test_midi", 11, 99, %DateTime{}} = cc
    end

    test "can send many commands in sequence" do
      for i <- 1..10 do
        MidiController.send_program_change(i)
      end

      Process.sleep(50)

      history = InMemory.get_history()
      assert length(history) == 10

      memory_numbers = Enum.map(history, fn {:program_change, _, mem, _} -> mem end)
      assert memory_numbers == Enum.to_list(1..10)
    end
  end

  describe "state tracking" do
    test "tracks last program change" do
      MidiController.send_program_change(15)
      Process.sleep(10)

      state = :sys.get_state(MidiController)
      assert state.last_command == {:program_change, 15}
    end

    test "tracks last control change" do
      MidiController.send_control_change(7, 64)
      Process.sleep(10)

      state = :sys.get_state(MidiController)
      assert state.last_command == {:control_change, 7, 64}
    end

    test "updates last command when sending multiple commands" do
      MidiController.send_program_change(1)
      MidiController.send_control_change(7, 64)
      MidiController.send_program_change(2)
      Process.sleep(20)

      state = :sys.get_state(MidiController)
      assert state.last_command == {:program_change, 2}
    end

    test "preserves state across multiple operations" do
      state_before = :sys.get_state(MidiController)

      MidiController.send_program_change(5)
      Process.sleep(10)

      state_after = :sys.get_state(MidiController)

      assert state_before.backend == state_after.backend
      assert state_before.device == state_after.device
      assert state_before.channel == state_after.channel
    end
  end

  describe "configuration" do
    test "reads backend from application config" do
      backends = Application.fetch_env!(:hendrix_homeostat, :backends)
      backend_module = Keyword.fetch!(backends, :midi_backend)

      assert backend_module == HendrixHomeostat.MidiBackend.InMemory

      state = :sys.get_state(MidiController)
      assert state.backend == backend_module
    end

    test "reads device name from application config" do
      midi_config = Application.fetch_env!(:hendrix_homeostat, :midi)
      device_name = Keyword.fetch!(midi_config, :device_name)

      assert device_name == "test_midi"

      state = :sys.get_state(MidiController)
      assert state.device == device_name
    end

    test "reads channel from application config" do
      midi_config = Application.fetch_env!(:hendrix_homeostat, :midi)
      channel = Keyword.fetch!(midi_config, :channel)

      assert channel == 1

      state = :sys.get_state(MidiController)
      assert state.channel == channel
    end

    test "reads rc600_cc_map from application config" do
      cc_map = Application.fetch_env!(:hendrix_homeostat, :rc600_cc_map)

      assert Keyword.get(cc_map, :track1_rec_play) == 1
      assert Keyword.get(cc_map, :track1_stop) == 11
      assert Keyword.get(cc_map, :track1_clear) == 21
    end
  end

  describe "RC-600 track control" do
    test "start_recording/1 sends correct CC for track 1" do
      MidiController.start_recording(1)
      Process.sleep(10)

      history = InMemory.get_history()
      [{:control_change, _device, cc, value, _timestamp}] = history
      assert cc == 1
      assert value == 127
    end

    test "start_recording/1 sends correct CC for track 6" do
      MidiController.start_recording(6)
      Process.sleep(10)

      history = InMemory.get_history()
      [{:control_change, _device, cc, value, _timestamp}] = history
      assert cc == 6
      assert value == 127
    end

    test "stop_track/1 sends correct CC for track 1" do
      MidiController.stop_track(1)
      Process.sleep(10)

      history = InMemory.get_history()
      [{:control_change, _device, cc, value, _timestamp}] = history
      assert cc == 11
      assert value == 127
    end

    test "stop_track/1 sends correct CC for track 6" do
      MidiController.stop_track(6)
      Process.sleep(10)

      history = InMemory.get_history()
      [{:control_change, _device, cc, value, _timestamp}] = history
      assert cc == 16
      assert value == 127
    end

    test "clear_track/1 sends correct CC for track 1" do
      MidiController.clear_track(1)
      Process.sleep(10)

      history = InMemory.get_history()
      [{:control_change, _device, cc, value, _timestamp}] = history
      assert cc == 21
      assert value == 127
    end

    test "clear_track/1 sends correct CC for track 4" do
      MidiController.clear_track(4)
      Process.sleep(10)

      history = InMemory.get_history()
      [{:control_change, _device, cc, value, _timestamp}] = history
      assert cc == 24
      assert value == 127
    end

    test "start_recording/1 rejects invalid track numbers" do
      assert_raise FunctionClauseError, fn ->
        MidiController.start_recording(0)
      end

      assert_raise FunctionClauseError, fn ->
        MidiController.start_recording(7)
      end
    end

    test "stop_track/1 rejects invalid track numbers" do
      assert_raise FunctionClauseError, fn ->
        MidiController.stop_track(0)
      end

      assert_raise FunctionClauseError, fn ->
        MidiController.stop_track(7)
      end
    end

    test "clear_track/1 rejects invalid track numbers" do
      assert_raise FunctionClauseError, fn ->
        MidiController.clear_track(0)
      end

      assert_raise FunctionClauseError, fn ->
        MidiController.clear_track(5)
      end
    end
  end
end
