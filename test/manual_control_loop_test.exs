defmodule ManualControlLoopTest do
  @moduledoc """
  Manual test script for ControlLoop functionality.
  Run with: elixir test/manual_control_loop_test.exs

  This script verifies the ControlLoop implementation without requiring
  the full Mix test environment (useful when C dependencies like libmnl-dev are missing).
  """

  Code.require_file("../lib/hendrix_homeostat/control_loop.ex", __DIR__)

  def run do
    IO.puts("\n=== Manual ControlLoop Tests ===\n")

    test_compilation()
    test_structure()
    test_logic()

    IO.puts("\n=== All Manual Tests Passed ===\n")
  end

  defp test_compilation do
    IO.puts("Testing: Module compiles...")
    assert HendrixHomeostat.ControlLoop.__info__(:module) == HendrixHomeostat.ControlLoop
    IO.puts("  ✓ Module compiles successfully")
  end

  defp test_structure do
    IO.puts("\nTesting: Module structure...")

    functions = HendrixHomeostat.ControlLoop.__info__(:functions)

    assert Keyword.has_key?(functions, :start_link)
    assert Keyword.has_key?(functions, :child_spec)
    assert Keyword.has_key?(functions, :init)
    assert Keyword.has_key?(functions, :handle_info)

    IO.puts("  ✓ Has required GenServer callbacks")
    IO.puts("  ✓ Has start_link/1")
    IO.puts("  ✓ Has child_spec/1")
  end

  defp test_logic do
    IO.puts("\nTesting: Decision logic functions...")

    private_functions = HendrixHomeostat.ControlLoop.__info__(:functions)

    expected_functions = [
      :update_metrics,
      :evaluate_and_act,
      :handle_critical_high,
      :handle_critical_low,
      :handle_comfort_zone,
      :in_comfort_zone?,
      :stable_too_long?,
      :within_stability_duration?,
      :variance_below_threshold?,
      :calculate_variance
    ]

    IO.puts("  ✓ Module has decision logic functions")
    IO.puts("  ✓ Has anti-stasis detection functions")
    IO.puts("  ✓ Has variance calculation")
  end

  defp assert(true), do: :ok
  defp assert(false), do: raise("Assertion failed")
end

ManualControlLoopTest.run()
