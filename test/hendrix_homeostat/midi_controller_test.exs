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

    test "validates memory number range" do
      MidiController.send_program_change(0)
      MidiController.send_program_change(98)

      assert_raise FunctionClauseError, fn ->
        MidiController.send_program_change(-1)
      end

      assert_raise FunctionClauseError, fn ->
        MidiController.send_program_change(99)
      end
    end

    test "handles backend failures gracefully" do
      stop_supervised(InMemory)

      MidiController.send_program_change(5)
      Process.sleep(10)

      history = InMemory.get_history()
      assert history == []
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

    test "validates CC number and value range" do
      MidiController.send_control_change(0, 0)
      MidiController.send_control_change(127, 127)

      assert_raise FunctionClauseError, fn ->
        MidiController.send_control_change(-1, 64)
      end

      assert_raise FunctionClauseError, fn ->
        MidiController.send_control_change(128, 64)
      end

      assert_raise FunctionClauseError, fn ->
        MidiController.send_control_change(7, -1)
      end

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
  end

  describe "state tracking" do
    test "tracks last command sent" do
      MidiController.send_program_change(1)
      MidiController.send_control_change(7, 64)
      Process.sleep(10)

      state = :sys.get_state(MidiController)
      assert state.last_command == {:control_change, 7, 64}
    end
  end
end
