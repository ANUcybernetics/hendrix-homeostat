defmodule HendrixHomeostat.Midi.TestSpy do
  use Agent

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def send_program_change(device, memory) do
    Agent.update(__MODULE__, fn history ->
      [{:program_change, device, memory, DateTime.utc_now()} | history]
    end)
    :ok
  end

  def send_control_change(device, cc, value) do
    Agent.update(__MODULE__, fn history ->
      [{:control_change, device, cc, value, DateTime.utc_now()} | history]
    end)
    :ok
  end

  def get_history do
    Agent.get(__MODULE__, &Enum.reverse/1)
  end

  def clear_history do
    Agent.update(__MODULE__, fn _ -> [] end)
  end

  def stop do
    Agent.stop(__MODULE__)
  end
end
