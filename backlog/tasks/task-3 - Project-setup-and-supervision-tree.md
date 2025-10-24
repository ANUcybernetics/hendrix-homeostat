---
id: task-3
title: Project setup and supervision tree
status: Done
assignee: []
created_date: '2025-10-10 10:31'
completed_date: '2025-10-11'
labels:
  - elixir
  - nerves
  - setup
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up the Elixir application structure with a flat supervision tree for the three main GenServers (MidiController, AudioMonitor, ControlLoop). Configure mix.exs with Nerves dependencies and create basic application skeleton.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Application module created with start/2 callback
- [x] #2 Supervisor module created with flat child spec for MidiController, AudioMonitor, and ControlLoop
- [x] #3 Supervision strategy set to `:one_for_one` with explicit restart strategy
- [x] #4 All GenServers registered with explicit names (e.g., `HendrixHomeostat.MidiController`)
- [x] #5 Shutdown timeouts configured for graceful Port cleanup (`:shutdown` option)
- [x] #6 Startup order documented (MidiController and AudioMonitor can start in any order, ControlLoop depends on both)
- [x] #7 mix.exs configured with required Nerves dependencies
- [x] #8 Basic config/runtime.exs created with placeholder settings (not config.exs, for Nerves compatibility)
- [x] #9 Application compiles without errors
- [x] #10 Fix `Mix.target()` usage in application.ex to use runtime config instead
<!-- AC:END -->
