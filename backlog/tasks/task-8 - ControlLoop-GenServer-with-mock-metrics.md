---
id: task-8
title: ControlLoop GenServer with mock metrics
status: Done
assignee: []
created_date: '2025-10-10 10:32'
completed_date: '2025-10-11'
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
- [x] #1 ControlLoop GenServer module created with init/1, handle_info/2 for receiving metrics
- [x] #2 State structure explicitly defined: current_metrics, stability_counter, last_action_timestamp, config
- [x] #3 Threshold logic implemented: critical_high (>0.8), critical_low (<0.05), comfort_zone (0.2-0.5)
- [x] #4 Stability tracking: counts consecutive readings where RMS stays within comfort zone AND doesn't change significantly
- [x] #5 Anti-stasis logic: triggers change after N consecutive stable readings (configurable, default 20)
- [x] #6 Patch selection logic: boost bank when too quiet, dampen bank when too loud, random bank when stable too long
- [x] #7 Uses `GenServer.cast` to send MIDI commands to MidiController (fire-and-forget)
- [x] #8 Handles `:metrics` messages containing {rms, zcr, peak} tuples from AudioMonitor
- [x] #9 Stability counter resets on threshold crossing OR significant metric change (>0.05 RMS delta)
- [x] #10 Module compiles and runs with test metrics sent via `send/2`
<!-- AC:END -->
