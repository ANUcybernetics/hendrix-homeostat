defmodule HendrixHomeostat.MidiBackend do
  @callback send_program_change(device :: String.t(), memory :: integer()) ::
              :ok | {:error, term()}

  @callback send_control_change(device :: String.t(), cc :: integer(), value :: integer()) ::
              :ok | {:error, term()}
end
