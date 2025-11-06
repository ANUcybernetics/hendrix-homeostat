defmodule HendrixHomeostat.MidiController do
  use GenServer
  require Logger

  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      shutdown: 5_000
    }
  end

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def send_program_change(memory_number) when memory_number >= 0 and memory_number <= 98 do
    GenServer.cast(__MODULE__, {:send_program_change, memory_number})
  end

  def send_control_change(cc_number, value)
      when cc_number >= 0 and cc_number <= 127 and value >= 0 and value <= 127 do
    GenServer.cast(__MODULE__, {:send_control_change, cc_number, value})
  end

  def start_recording(track_number) when track_number >= 1 and track_number <= 6 do
    cc_map = Application.fetch_env!(:hendrix_homeostat, :rc600_cc_map)
    cc = get_track_cc(cc_map, track_number, :rec_play)
    send_control_change(cc, 127)
  end

  def stop_track(track_number) when track_number >= 1 and track_number <= 6 do
    cc_map = Application.fetch_env!(:hendrix_homeostat, :rc600_cc_map)
    cc = get_track_cc(cc_map, track_number, :stop)
    send_control_change(cc, 127)
  end

  def clear_track(track_number) when track_number >= 1 and track_number <= 4 do
    cc_map = Application.fetch_env!(:hendrix_homeostat, :rc600_cc_map)
    cc = get_track_cc(cc_map, track_number, :clear)
    send_control_change(cc, 127)
  end

  def set_track_volume(track_number, value)
      when track_number >= 1 and track_number <= 2 and value >= 0 and value <= 127 do
    cc_map = Application.fetch_env!(:hendrix_homeostat, :rc600_cc_map)
    cc = get_track_cc(cc_map, track_number, :volume)
    send_control_change(cc, value)
  end

  def clear_all_tracks do
    Enum.each(1..4, &clear_track/1)
  end

  defp get_track_cc(cc_map, track_number, action) do
    key = String.to_atom("track#{track_number}_#{action}")
    Keyword.fetch!(cc_map, key)
  end

  @impl true
  def init(opts) do
    backends = Application.fetch_env!(:hendrix_homeostat, :backends)
    midi_module = Keyword.fetch!(backends, :midi)

    midi_config = Application.fetch_env!(:hendrix_homeostat, :midi)
    device_name = Keyword.fetch!(midi_config, :device_name)
    channel = Keyword.fetch!(midi_config, :channel)
    ready_notify = Keyword.get(opts, :ready_notify)
    startup_delay_ms = Keyword.get(opts, :startup_delay_ms, 1000)

    state = %{
      midi: midi_module,
      device: device_name,
      channel: channel,
      last_command: nil,
      ready_notify: ready_notify,
      startup_delay_ms: startup_delay_ms
    }

    {:ok, state, {:continue, :clear_tracks}}
  end

  @impl true
  def handle_continue(:clear_tracks, state) do
    # Give the RC-600 a moment to be ready after system startup
    Process.sleep(state.startup_delay_ms)
    Logger.info("Clearing all RC-600 tracks on startup")
    clear_all_tracks()

    if state.ready_notify do
      send(state.ready_notify, {:midi_ready, self()})
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_program_change, memory_number}, state) do
    result = state.midi.send_program_change(state.device, memory_number)

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
    result = state.midi.send_control_change(state.device, cc_number, value)

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
