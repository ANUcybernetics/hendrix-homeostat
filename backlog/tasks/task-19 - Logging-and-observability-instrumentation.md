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
- [ ] #1 Logger calls added to MidiController for all MIDI commands sent
- [ ] #2 Logger calls added to AudioMonitor for metric calculations and Port events
- [ ] #3 Logger calls added to ControlLoop for state transitions, threshold crossings, and patch changes
- [ ] #4 Log levels appropriate for each message type (debug for metrics, info for state changes, warn for errors)
- [ ] #5 Configurable log level via config.exs (debug in dev, info in prod)
- [ ] #6 Log messages include relevant context (current metrics, selected patch, reason for change)
- [ ] #7 Verified logs are readable and useful for debugging on actual hardware
- [ ] #8 Logs do not negatively impact performance or timing
<!-- AC:END -->
