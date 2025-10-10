defmodule HendrixHomeostat.AudioBackend.File do
  @behaviour HendrixHomeostat.AudioBackend

  use GenServer

  defstruct [:file_path, :file_handle, :buffer_size, :position]

  @impl true
  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @impl HendrixHomeostat.AudioBackend
  def read_buffer(pid) do
    GenServer.call(pid, :read_buffer)
  end

  @impl GenServer
  def init(config) do
    file_path = Map.fetch!(config, :file_path)
    buffer_size = Map.get(config, :buffer_size, 4096)

    case File.open(file_path, [:read, :binary]) do
      {:ok, file_handle} ->
        state = %__MODULE__{
          file_path: file_path,
          file_handle: file_handle,
          buffer_size: buffer_size,
          position: 0
        }

        {:ok, state}

      {:error, reason} ->
        {:stop, {:file_error, reason}}
    end
  end

  @impl GenServer
  def handle_call(:read_buffer, _from, state) do
    case IO.binread(state.file_handle, state.buffer_size) do
      :eof ->
        File.close(state.file_handle)

        case File.open(state.file_path, [:read, :binary]) do
          {:ok, new_handle} ->
            new_state = %{state | file_handle: new_handle, position: 0}

            case IO.binread(new_handle, state.buffer_size) do
              data when is_binary(data) ->
                {:reply, {:ok, data}, %{new_state | position: byte_size(data)}}

              :eof ->
                {:reply, {:error, :empty_file}, new_state}
            end

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      data when is_binary(data) ->
        new_position = state.position + byte_size(data)
        {:reply, {:ok, data}, %{state | position: new_position}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def terminate(_reason, state) do
    if state.file_handle do
      File.close(state.file_handle)
    end

    :ok
  end
end
