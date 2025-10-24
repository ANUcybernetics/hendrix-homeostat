defmodule HendrixHomeostat.MidiBackend.InMemoryTest do
  use ExUnit.Case

  alias HendrixHomeostat.MidiBackend.InMemory

  setup do
    {:ok, _pid} = start_supervised({InMemory, name: InMemory})
    InMemory.clear_history()
    :ok
  end

  describe "send_program_change/2" do
    test "records program change commands" do
      assert :ok = InMemory.send_program_change("hw:1,0", 5)

      history = InMemory.get_history()
      assert length(history) == 1

      [{:program_change, device, memory, timestamp}] = history
      assert device == "hw:1,0"
      assert memory == 5
      assert %DateTime{} = timestamp
    end

    test "records multiple commands in order" do
      assert :ok = InMemory.send_program_change("hw:1,0", 1)
      assert :ok = InMemory.send_program_change("hw:1,0", 2)
      assert :ok = InMemory.send_program_change("hw:1,0", 3)

      history = InMemory.get_history()
      assert length(history) == 3

      memories = Enum.map(history, fn {:program_change, _, memory, _} -> memory end)
      assert memories == [1, 2, 3]
    end
  end

  describe "send_control_change/3" do
    test "records control change commands" do
      assert :ok = InMemory.send_control_change("hw:1,0", 7, 127)

      history = InMemory.get_history()
      assert length(history) == 1

      [{:control_change, device, cc, value, timestamp}] = history
      assert device == "hw:1,0"
      assert cc == 7
      assert value == 127
      assert %DateTime{} = timestamp
    end

    test "records mixed command types in order" do
      assert :ok = InMemory.send_program_change("hw:1,0", 1)
      assert :ok = InMemory.send_control_change("hw:1,0", 7, 64)
      assert :ok = InMemory.send_program_change("hw:1,0", 2)

      history = InMemory.get_history()
      assert length(history) == 3

      assert [
               {:program_change, _, 1, _},
               {:control_change, _, 7, 64, _},
               {:program_change, _, 2, _}
             ] = history
    end
  end

  describe "clear_history/0" do
    test "clears all recorded commands" do
      InMemory.send_program_change("hw:1,0", 1)
      InMemory.send_control_change("hw:1,0", 7, 64)

      assert length(InMemory.get_history()) == 2

      InMemory.clear_history()
      assert InMemory.get_history() == []
    end
  end
end
