defmodule HendrixHomeostat.Midi.Amidi do
  @moduledoc """
  MIDI implementation using the amidi command-line tool.

  This module shells out to the `amidi` command to send MIDI messages
  to hardware devices.
  """

  @doc """
  Send a program change message via amidi.

  ## Examples

      send_program_change("hw:1,0", 5)
      #=> :ok
  """
  def send_program_change(device, memory) do
    hex_message = "C0#{to_hex(memory)}"

    case System.cmd("amidi", ["-p", device, "-S", hex_message], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, code} -> {:error, {code, output}}
    end
  end

  @doc """
  Send a control change message via amidi.

  ## Examples

      send_control_change("hw:1,0", 7, 127)
      #=> :ok
  """
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
