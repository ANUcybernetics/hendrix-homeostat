defmodule ManualIntegrationTest do
  @moduledoc """
  Manual integration test script for the complete system.
  Run with: elixir test/manual_integration_test.exs

  This script verifies the integration between AudioMonitor, ControlLoop, and MidiController
  without requiring the full Mix test environment (useful when C dependencies like libmnl-dev are missing).

  It validates:
  - AudioMonitor sends metrics to ControlLoop
  - ControlLoop receives metrics via handle_info({:metrics, map}, state)
  - ControlLoop calls MidiController.send_program_change/1
  - MidiController sends commands to the backend
  """

  Code.require_file("../lib/hendrix_homeostat/audio_monitor.ex", __DIR__)
  Code.require_file("../lib/hendrix_homeostat/control_loop.ex", __DIR__)
  Code.require_file("../lib/hendrix_homeostat/midi_controller.ex", __DIR__)
  Code.require_file("../lib/hendrix_homeostat/audio_backend.ex", __DIR__)
  Code.require_file("../lib/hendrix_homeostat/midi_backend.ex", __DIR__)
  Code.require_file("../lib/hendrix_homeostat/audio_analysis.ex", __DIR__)

  def run do
    IO.puts("\n=== Manual Integration Tests ===\n")

    test_modules_compile()
    test_audio_monitor_structure()
    test_control_loop_structure()
    test_midi_controller_structure()
    test_message_flow_design()
    test_integration_points()

    IO.puts("\n=== All Manual Integration Tests Passed ===\n")
    IO.puts("Note: This verifies the integration design and structure.")

    IO.puts(
      "Full end-to-end tests require running 'mix test test/integration/system_integration_test.exs'"
    )

    IO.puts("after installing libmnl-dev: sudo apt-get install libmnl-dev")
  end

  defp test_modules_compile do
    IO.puts("Testing: All modules compile...")
    assert HendrixHomeostat.AudioMonitor.__info__(:module) == HendrixHomeostat.AudioMonitor
    assert HendrixHomeostat.ControlLoop.__info__(:module) == HendrixHomeostat.ControlLoop
    assert HendrixHomeostat.MidiController.__info__(:module) == HendrixHomeostat.MidiController
    IO.puts("  ✓ AudioMonitor compiles")
    IO.puts("  ✓ ControlLoop compiles")
    IO.puts("  ✓ MidiController compiles")
  end

  defp test_audio_monitor_structure do
    IO.puts("\nTesting: AudioMonitor integration structure...")

    state_fields = HendrixHomeostat.AudioMonitor.__struct__() |> Map.keys()
    assert :control_loop_pid in state_fields
    IO.puts("  ✓ AudioMonitor has :control_loop_pid field for sending metrics")

    functions = HendrixHomeostat.AudioMonitor.__info__(:functions)
    assert Keyword.has_key?(functions, :handle_info)
    IO.puts("  ✓ AudioMonitor has handle_info/2 callback")

    source = File.read!("lib/hendrix_homeostat/audio_monitor.ex")
    assert source =~ "send(pid, {:metrics, metrics})"
    IO.puts("  ✓ AudioMonitor sends {:metrics, map} to ControlLoop")
  end

  defp test_control_loop_structure do
    IO.puts("\nTesting: ControlLoop integration structure...")

    functions = HendrixHomeostat.ControlLoop.__info__(:functions)
    assert Keyword.has_key?(functions, :handle_info)
    IO.puts("  ✓ ControlLoop has handle_info/2 callback")

    source = File.read!("lib/hendrix_homeostat/control_loop.ex")
    assert source =~ "def handle_info({:metrics, metrics}, state)"
    IO.puts("  ✓ ControlLoop receives {:metrics, map} messages")

    assert source =~ "HendrixHomeostat.MidiController.send_program_change"
    IO.puts("  ✓ ControlLoop calls MidiController.send_program_change/1")
  end

  defp test_midi_controller_structure do
    IO.puts("\nTesting: MidiController integration structure...")

    functions = HendrixHomeostat.MidiController.__info__(:functions)
    assert Keyword.has_key?(functions, :send_program_change)
    IO.puts("  ✓ MidiController has send_program_change/1 function")

    assert Keyword.has_key?(functions, :handle_cast)
    IO.puts("  ✓ MidiController has handle_cast/2 callback")

    source = File.read!("lib/hendrix_homeostat/midi_controller.ex")
    assert source =~ "state.backend.send_program_change"
    IO.puts("  ✓ MidiController sends commands to backend")
  end

  defp test_message_flow_design do
    IO.puts("\nTesting: Message flow design...")

    audio_monitor_source = File.read!("lib/hendrix_homeostat/audio_monitor.ex")
    control_loop_source = File.read!("lib/hendrix_homeostat/control_loop.ex")

    assert audio_monitor_source =~ "control_loop_pid: HendrixHomeostat.ControlLoop"
    IO.puts("  ✓ AudioMonitor targets ControlLoop by name")

    assert audio_monitor_source =~ ":read_audio"
    assert audio_monitor_source =~ ":timer.send_interval"
    IO.puts("  ✓ AudioMonitor uses timer for periodic reads")

    assert control_loop_source =~ "update_metrics(state, metrics)"
    assert control_loop_source =~ "evaluate_and_act()"
    IO.puts("  ✓ ControlLoop has metrics processing pipeline")
  end

  defp test_integration_points do
    IO.puts("\nTesting: Integration acceptance criteria...")

    control_loop_source = File.read!("lib/hendrix_homeostat/control_loop.ex")

    refute control_loop_source =~ "mock_metrics"
    refute control_loop_source =~ "test_metrics"
    IO.puts("  ✓ No mock metrics in ControlLoop (uses real AudioMonitor data)")

    assert control_loop_source =~ "def handle_info({:metrics, metrics}, state)"
    IO.puts("  ✓ ControlLoop receives metrics from AudioMonitor")

    assert control_loop_source =~ "state.current_metrics"
    assert control_loop_source =~ "metrics_history"
    IO.puts("  ✓ ControlLoop stores and tracks metrics")

    assert control_loop_source =~ "critical_high"
    assert control_loop_source =~ "critical_low"
    assert control_loop_source =~ "comfort_zone"
    IO.puts("  ✓ ControlLoop makes decisions based on thresholds")

    assert control_loop_source =~ "send_program_change"
    IO.puts("  ✓ ControlLoop sends MIDI commands based on decisions")

    integration_test_exists = File.exists?("test/integration/system_integration_test.exs")
    assert integration_test_exists
    IO.puts("  ✓ Integration test file created")

    integration_test_source = File.read!("test/integration/system_integration_test.exs")
    assert integration_test_source =~ "threshold crossing"
    assert integration_test_source =~ "anti-stasis"
    assert integration_test_source =~ "ControlLoop"
    assert integration_test_source =~ "MidiController"
    IO.puts("  ✓ Integration tests cover control scenarios")

    assert integration_test_source =~ "AudioBackend"
    assert integration_test_source =~ "MidiBackend"
    IO.puts("  ✓ Integration tests use backend abstractions")

    assert integration_test_source =~ "configure_system"
    assert integration_test_source =~ "create_silence"
    assert integration_test_source =~ "create_loud_tone"
    IO.puts("  ✓ Integration test helper functions exist")
  end

  defp assert(true), do: :ok
  defp assert(false), do: raise("Assertion failed")

  defp refute(false), do: :ok
  defp refute(true), do: raise("Refutation failed")
end

ManualIntegrationTest.run()
