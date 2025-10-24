defmodule HendrixHomeostat.AudioMonitor do
  use GenServer
  require Logger

  alias HendrixHomeostat.AudioAnalysis

  defstruct [
    :backend,
    :backend_pid,
    :control_loop_pid,
    :update_interval,
    :timer_ref,
    :last_metrics,
    :config
  ]

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

  @impl true
  def init(_opts) do
    backends = Application.fetch_env!(:hendrix_homeostat, :backends)
    audio_config = Application.fetch_env!(:hendrix_homeostat, :audio)

    backend_module = Keyword.fetch!(backends, :audio_backend)
    update_rate = Keyword.fetch!(audio_config, :update_rate)
    buffer_size = Keyword.fetch!(audio_config, :buffer_size)

    backend_config = build_backend_config(audio_config)

    case backend_module.start_link(backend_config) do
      {:ok, backend_pid} ->
        update_interval = div(1000, update_rate)
        {:ok, timer_ref} = :timer.send_interval(update_interval, :read_audio)

        state = %__MODULE__{
          backend: backend_module,
          backend_pid: backend_pid,
          control_loop_pid: HendrixHomeostat.ControlLoop,
          update_interval: update_interval,
          timer_ref: timer_ref,
          last_metrics: nil,
          config: %{
            buffer_size: buffer_size,
            sample_rate: Keyword.fetch!(audio_config, :sample_rate),
            update_rate: update_rate
          }
        }

        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to start audio backend: #{inspect(reason)}")
        {:stop, {:backend_error, reason}}
    end
  end

  @impl true
  def handle_info(:read_audio, state) do
    case state.backend.read_buffer(state.backend_pid) do
      {:ok, buffer} ->
        metrics = AudioAnalysis.calculate_metrics(buffer)
        send(state.control_loop_pid, {:metrics, metrics})

        {:noreply, %{state | last_metrics: metrics}}

      {:error, reason} ->
        Logger.warning("Failed to read audio buffer: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    if state.timer_ref do
      :timer.cancel(state.timer_ref)
    end

    :ok
  end

  defp build_backend_config(audio_config) do
    device_name = Keyword.fetch!(audio_config, :device_name)
    buffer_size = Keyword.fetch!(audio_config, :buffer_size)
    sample_rate = Keyword.fetch!(audio_config, :sample_rate)

    %{
      file_path: device_name,
      device_name: device_name,
      buffer_size: buffer_size,
      sample_rate: sample_rate
    }
  end
end
