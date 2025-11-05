# Test Tagging Guide
#
# This project has two testing modes:
#
# 1. Host testing (default, recommended)
#    - Tests run on development machine using test backends
#    - Uses MidiBackend.InMemory and AudioBackend.File
#    - Does not require hardware or libmnl-dev dependency
#    - Run with: mix test
#
# 2. Target testing (hardware only)
#    - Tests run on actual Raspberry Pi 5 hardware
#    - Uses MidiBackend.Amidi and AudioBackend.Port
#    - Requires real hardware and all dependencies
#    - Run with: MIX_TARGET=rpi5 mix test --only target_only
#
# When to tag tests with @tag :target_only
# ========================================
#
# Use this tag ONLY for tests that truly require real hardware:
# - Testing actual MIDI device communication via amidi
# - Testing actual audio capture from Presonus interface
# - Hardware-specific edge cases or timing
#
# DO NOT use this tag for:
# - Regular unit tests (use backend abstractions)
# - Integration tests (use test backends)
# - Most GenServer tests (use test backends)
#
# The vast majority of tests should NOT have this tag and should use
# the backend abstractions to run on host.
#
# Running tests
# =============
#
# Normal development (host with test backends):
#   mix test
#
# Only target-specific tests (on actual hardware):
#   MIX_TARGET=rpi5 mix test --only target_only
#
# All tests on target hardware:
#   MIX_TARGET=rpi5 mix test --include target_only

# Compile test support files
Code.require_file("support/conn_case.ex", __DIR__)

# Detect if we're running on host or target
target = System.get_env("MIX_TARGET", "host")

# Don't start the application automatically in tests
# Tests will start supervised processes as needed
Application.stop(:hendrix_homeostat)

# Start PubSub and RuntimeConfig for all tests
# This allows ControlLoop to broadcast state updates and access runtime config even in unit tests
{:ok, _} =
  Supervisor.start_link(
    [
      {Phoenix.PubSub, name: HendrixHomeostat.PubSub},
      {HendrixHomeostat.RuntimeConfig, []}
    ],
    strategy: :one_for_one
  )

# Configure ExUnit based on target
exclude_tags =
  if target == "host" do
    IO.puts("\n=== Running tests on :host target ===")
    IO.puts("Excluding tests tagged with :target_only")
    IO.puts("To run target-only tests: MIX_TARGET=rpi5 mix test --only target_only\n")
    [:target_only]
  else
    IO.puts("\n=== Running tests on :#{target} target ===")
    IO.puts("Including tests tagged with :target_only")
    IO.puts("Make sure you're on actual hardware!\n")
    []
  end

ExUnit.start(exclude: exclude_tags)
