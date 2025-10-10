defmodule HendrixHomeostat.AudioBackend do
  @callback start_link(config :: map()) :: {:ok, pid()} | {:error, term()}

  @callback read_buffer(pid()) :: {:ok, binary()} | {:error, term()}
end
