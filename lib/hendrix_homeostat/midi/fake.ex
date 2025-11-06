defmodule HendrixHomeostat.Midi.Fake do
  @moduledoc """
  Fake MIDI implementation for testing.

  This module provides a simple no-op implementation that can be used in tests
  where we don't need to verify MIDI commands were sent.
  """

  @doc """
  Fake program change - always succeeds.
  """
  def send_program_change(_device, _memory), do: :ok

  @doc """
  Fake control change - always succeeds.
  """
  def send_control_change(_device, _cc, _value), do: :ok
end
