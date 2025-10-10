---
id: task-8
title: ControlLoop GenServer with mock metrics
status: To Do
assignee: []
created_date: '2025-10-10 10:32'
labels:
  - elixir
  - control-logic
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement ControlLoop GenServer that contains the homeostat control logic. Receives metrics via message passing from AudioMonitor (push-based, not polling). Initially uses hardcoded test metrics to validate decision logic independently. Sends MIDI commands via MidiController based on thresholds and stability tracking.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ControlLoop GenServer module created with init/1, handle_info/2 for receiving metrics
- [ ] #2 State structure explicitly defined: current_metrics, stability_counter, last_action_timestamp, config
- [ ] #3 Threshold logic implemented: critical_high (>0.8), critical_low (<0.05), comfort_zone (0.2-0.5)
- [ ] #4 Stability tracking: counts consecutive readings where RMS stays within comfort zone AND doesn't change significantly
- [ ] #5 Anti-stasis logic: triggers change after N consecutive stable readings (configurable, default 20)
- [ ] #6 Patch selection logic: boost bank when too quiet, dampen bank when too loud, random bank when stable too long
- [ ] #7 Uses `GenServer.cast` to send MIDI commands to MidiController (fire-and-forget)
- [ ] #8 Handles `:metrics` messages containing {rms, zcr, peak} tuples from AudioMonitor
- [ ] #9 Stability counter resets on threshold crossing OR significant metric change (>0.05 RMS delta)
- [ ] #10 Module compiles and runs with test metrics sent via `send/2`
<!-- AC:END -->
