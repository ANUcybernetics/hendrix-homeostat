defmodule HendrixHomeostat.MidiBackend.InMemory do
  @behaviour HendrixHomeostat.MidiBackend

  use Agent

  def start_link(opts \\ []) do
    Agent.start_link(fn -> [] end, opts)
  end

  @impl true
  def send_program_change(device, memory) do
    case Process.whereis(__MODULE__) do
      nil ->
        {:error, :not_started}

      pid ->
        Agent.update(pid, fn history ->
          [{:program_change, device, memory, DateTime.utc_now()} | history]
        end)

        :ok
    end
  end

  @impl true
  def send_control_change(device, cc, value) do
    case Process.whereis(__MODULE__) do
      nil ->
        {:error, :not_started}

      pid ->
        Agent.update(pid, fn history ->
          [{:control_change, device, cc, value, DateTime.utc_now()} | history]
        end)

        :ok
    end
  end

  def get_history do
    case Process.whereis(__MODULE__) do
      nil ->
        []

      pid ->
        Agent.get(pid, fn history -> Enum.reverse(history) end)
    end
  end

  def clear_history do
    case Process.whereis(__MODULE__) do
      nil ->
        :ok

      pid ->
        Agent.update(pid, fn _ -> [] end)
    end
  end
end
