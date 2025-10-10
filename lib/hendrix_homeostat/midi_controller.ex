defmodule HendrixHomeostat.MidiController do
  use GenServer
  require Logger

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      shutdown: 5_000
    }
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def send_program_change(memory_number) when memory_number >= 0 and memory_number <= 98 do
    GenServer.cast(__MODULE__, {:send_program_change, memory_number})
  end

  def send_control_change(cc_number, value)
      when cc_number >= 0 and cc_number <= 127 and value >= 0 and value <= 127 do
    GenServer.cast(__MODULE__, {:send_control_change, cc_number, value})
  end

  @impl true
  def init(_opts) do
    backends = Application.fetch_env!(:hendrix_homeostat, :backends)
    backend_module = Keyword.fetch!(backends, :midi_backend)

    midi_config = Application.fetch_env!(:hendrix_homeostat, :midi)
    device_name = Keyword.fetch!(midi_config, :device_name)
    channel = Keyword.fetch!(midi_config, :channel)

    state = %{
      backend: backend_module,
      device: device_name,
      channel: channel,
      last_command: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:send_program_change, memory_number}, state) do
    result = state.backend.send_program_change(state.device, memory_number)

    case result do
      :ok ->
        new_state = %{state | last_command: {:program_change, memory_number}}
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to send program change #{memory_number}: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:send_control_change, cc_number, value}, state) do
    result = state.backend.send_control_change(state.device, cc_number, value)

    case result do
      :ok ->
        new_state = %{state | last_command: {:control_change, cc_number, value}}
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to send CC #{cc_number} value #{value}: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end
end
