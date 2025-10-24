defmodule HendrixHomeostat.MidiBackend.Amidi do
  @behaviour HendrixHomeostat.MidiBackend

  @impl true
  def send_program_change(device, memory) do
    hex_message = "C0#{to_hex(memory)}"

    case System.cmd("amidi", ["-p", device, "-S", hex_message], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, code} -> {:error, {code, output}}
    end
  end

  @impl true
  def send_control_change(device, cc, value) do
    hex_message = "B0#{to_hex(cc)}#{to_hex(value)}"

    case System.cmd("amidi", ["-p", device, "-S", hex_message], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, code} -> {:error, {code, output}}
    end
  end

  defp to_hex(n) do
    n
    |> Integer.to_string(16)
    |> String.upcase()
    |> String.pad_leading(2, "0")
  end
end
