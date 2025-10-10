---
id: task-3
title: Project setup and supervision tree
status: To Do
assignee: []
created_date: '2025-10-10 10:31'
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
- [ ] #1 Application module created with start/2 callback
- [ ] #2 Supervisor module created with flat child spec for MidiController, AudioMonitor, and ControlLoop
- [ ] #3 Supervision strategy set to `:one_for_one` with explicit restart strategy
- [ ] #4 All GenServers registered with explicit names (e.g., `HendrixHomeostat.MidiController`)
- [ ] #5 Shutdown timeouts configured for graceful Port cleanup (`:shutdown` option)
- [ ] #6 Startup order documented (MidiController and AudioMonitor can start in any order, ControlLoop depends on both)
- [ ] #7 mix.exs configured with required Nerves dependencies
- [ ] #8 Basic config/runtime.exs created with placeholder settings (not config.exs, for Nerves compatibility)
- [ ] #9 Application compiles without errors
- [ ] #10 Fix `Mix.target()` usage in application.ex to use runtime config instead
<!-- AC:END -->
