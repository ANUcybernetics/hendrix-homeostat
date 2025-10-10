---
id: task-19
title: Logging and observability instrumentation
status: To Do
assignee: []
created_date: '2025-10-10 10:34'
labels:
  - elixir
  - observability
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add comprehensive logging throughout the system to enable debugging and observation of homeostat behavior. Include metric values, control decisions, MIDI commands sent, and state transitions. Implement configurable log levels for production vs. development.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Logger calls added to MidiController for all MIDI commands sent (info level)
- [ ] #2 Logger calls added to AudioMonitor for metric calculations (debug) and Port events (info/warn)
- [ ] #3 Logger calls added to ControlLoop for state transitions, threshold crossings, patch changes (info level)
- [ ] #4 Logger metadata used for structured logging (module, function, genserver pid)
- [ ] #5 Remote IEx access configured via nerves_pack SSH support
- [ ] #6 RingLogger configured for persistent logs across reboots (nerves_pack)
- [ ] #7 Telemetry instrumentation added for key metrics (audio RMS, patch changes, errors)
- [ ] #8 Telemetry metrics can be observed via `:telemetry.list_handlers/1` in IEx
- [ ] #9 Log levels configurable via runtime.exs (debug in dev, info in prod)
- [ ] #10 Log messages include relevant context (metrics, selected patch, reason for decision)
- [ ] #11 Instructions documented for: SSH access, viewing logs via RingLogger.attach, using :observer
- [ ] #12 Logs verified readable and useful for debugging on hardware
- [ ] #13 Logging overhead measured, no impact on control loop timing
<!-- AC:END -->
