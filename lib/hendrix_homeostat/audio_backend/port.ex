defmodule HendrixHomeostat.AudioBackend.Port do
  @behaviour HendrixHomeostat.AudioBackend

  use GenServer
  require Logger

  defstruct [:port, :buffer_size, :device_name, :sample_rate, :format, :accumulator]

  @impl true
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @impl HendrixHomeostat.AudioBackend
  def read_buffer(pid) do
    GenServer.call(pid, :read_buffer, 10_000)
  end

  @impl GenServer
  def init(config) do
    device_name = Map.fetch!(config, :device_name)
    buffer_size = Map.get(config, :buffer_size, 4800)
    sample_rate = Map.get(config, :sample_rate, 48000)
    format = Map.get(config, :format, "S32_LE")

    bytes_per_sample =
      case format do
        "S16_LE" -> 2
        "S32_LE" -> 4
        _ -> raise ArgumentError, "Unsupported audio format: #{format}"
      end

    channels = Map.get(config, :channels, 6)
    frame_size = bytes_per_sample * channels
    num_frames = div(buffer_size, frame_size)
    actual_buffer_bytes = num_frames * frame_size

    port_opts = [
      :binary,
      :stream,
      :exit_status,
      args: [
        "-D",
        device_name,
        "-f",
        format,
        "-r",
        to_string(sample_rate),
        "-c",
        to_string(channels),
        "-t",
        "raw"
      ]
    ]

    port = Port.open({:spawn_executable, "/usr/bin/arecord"}, port_opts)

    state = %__MODULE__{
      port: port,
      buffer_size: actual_buffer_bytes,
      device_name: device_name,
      sample_rate: sample_rate,
      format: format,
      accumulator: <<>>
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:read_buffer, from, state) do
    collect_buffer(from, state, state.accumulator)
  end

  @impl GenServer
  def handle_info({port, {:data, data}}, state) when port == state.port do
    {:noreply, %{state | accumulator: state.accumulator <> data}}
  end

  @impl GenServer
  def handle_info({port, {:exit_status, status}}, state) when port == state.port do
    Logger.error("arecord exited with status #{status}")
    {:stop, {:port_exit, status}, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    if state.port do
      Port.close(state.port)
    end

    :ok
  end

  defp collect_buffer(from, state, acc) do
    if byte_size(acc) >= state.buffer_size do
      <<buffer::binary-size(state.buffer_size), rest::binary>> = acc
      GenServer.reply(from, {:ok, buffer})
      {:noreply, %{state | accumulator: rest}}
    else
      receive do
        {port, {:data, data}} when port == state.port ->
          collect_buffer(from, state, acc <> data)

        {port, {:exit_status, status}} when port == state.port ->
          Logger.error("arecord exited with status #{status}")
          GenServer.reply(from, {:error, {:port_exit, status}})
          {:stop, {:port_exit, status}, state}
      after
        5_000 ->
          GenServer.reply(from, {:error, :timeout})
          {:noreply, %{state | accumulator: acc}}
      end
    end
  end
end
