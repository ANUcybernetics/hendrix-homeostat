defmodule ManualAudioMonitorTest do
  @moduledoc """
  Manual test script for AudioMonitor functionality.
  Run with: elixir test/manual_audio_monitor_test.exs

  This script verifies the AudioMonitor implementation without requiring
  the full Mix test environment (useful when C dependencies like libmnl-dev are missing).
  """

  Code.require_file("../lib/hendrix_homeostat/audio_monitor.ex", __DIR__)
  Code.require_file("../lib/hendrix_homeostat/audio_backend.ex", __DIR__)
  Code.require_file("../lib/hendrix_homeostat/audio_analysis.ex", __DIR__)

  def run do
    IO.puts("\n=== Manual AudioMonitor Tests ===\n")

    test_compilation()
    test_structure()
    test_state_definition()

    IO.puts("\n=== All Manual Tests Passed ===\n")
  end

  defp test_compilation do
    IO.puts("Testing: Module compiles...")
    assert HendrixHomeostat.AudioMonitor.__info__(:module) == HendrixHomeostat.AudioMonitor
    IO.puts("  ✓ Module compiles successfully")
  end

  defp test_structure do
    IO.puts("\nTesting: Module structure...")

    functions = HendrixHomeostat.AudioMonitor.__info__(:functions)

    assert Keyword.has_key?(functions, :start_link)
    assert Keyword.has_key?(functions, :child_spec)
    assert Keyword.has_key?(functions, :init)
    assert Keyword.has_key?(functions, :handle_info)
    assert Keyword.has_key?(functions, :terminate)

    IO.puts("  ✓ Has required GenServer callbacks")
    IO.puts("  ✓ Has start_link/1")
    IO.puts("  ✓ Has child_spec/1")
    IO.puts("  ✓ Has init/1")
    IO.puts("  ✓ Has handle_info/2")
    IO.puts("  ✓ Has terminate/2")
  end

  defp test_state_definition do
    IO.puts("\nTesting: State structure...")

    state_fields = HendrixHomeostat.AudioMonitor.__struct__() |> Map.keys()

    expected_fields = [
      :__struct__,
      :backend,
      :backend_pid,
      :control_loop_pid,
      :update_interval,
      :timer_ref,
      :last_metrics,
      :config
    ]

    Enum.each(expected_fields, fn field ->
      assert field in state_fields
    end)

    IO.puts("  ✓ State has :backend field")
    IO.puts("  ✓ State has :backend_pid field")
    IO.puts("  ✓ State has :control_loop_pid field")
    IO.puts("  ✓ State has :update_interval field")
    IO.puts("  ✓ State has :timer_ref field")
    IO.puts("  ✓ State has :last_metrics field")
    IO.puts("  ✓ State has :config field")
  end

  defp assert(true), do: :ok
  defp assert(false), do: raise("Assertion failed")
end

ManualAudioMonitorTest.run()
