defmodule HendrixHomeostat.Midi.TestSpy do
  use Agent

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{history: [], notify: nil} end, name: __MODULE__)
  end

  def send_program_change(device, memory) do
    event = {:program_change, device, memory, DateTime.utc_now()}

    Agent.update(__MODULE__, fn state ->
      maybe_notify(state.notify, event)
      %{state | history: [event | state.history]}
    end)

    :ok
  end

  def send_control_change(device, cc, value) do
    event = {:control_change, device, cc, value, DateTime.utc_now()}

    Agent.update(__MODULE__, fn state ->
      maybe_notify(state.notify, event)
      %{state | history: [event | state.history]}
    end)

    :ok
  end

  def get_history do
    Agent.get(__MODULE__, fn state -> Enum.reverse(state.history) end)
  end

  def clear_history do
    Agent.update(__MODULE__, fn state -> %{state | history: []} end)
  end

  def set_notify(pid) when is_pid(pid) do
    Agent.update(__MODULE__, fn state -> %{state | notify: pid} end)
  end

  def clear_notify do
    Agent.update(__MODULE__, fn state -> %{state | notify: nil} end)
  end

  def stop do
    Agent.stop(__MODULE__)
  end

  defp maybe_notify(nil, _event), do: :ok

  defp maybe_notify(pid, event) do
    send(pid, {:midi_event, event})
  end
end
