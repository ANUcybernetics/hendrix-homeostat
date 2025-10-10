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
Implement ControlLoop GenServer that contains the homeostat control logic. Initially use hardcoded/mock metrics to test the decision-making logic without requiring AudioMonitor. Polls metrics at configurable intervals and sends MIDI commands via MidiController based on thresholds and stability tracking.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ControlLoop GenServer module created with init/1, handle_info/3 for periodic polling
- [ ] #2 State structure tracks current metrics, stability counter, and last action timestamp
- [ ] #3 Threshold logic implemented: critical_high (>0.8), critical_low (<0.05), comfort_zone (0.2-0.5)
- [ ] #4 Stability tracking counts consecutive readings in comfort zone
- [ ] #5 Anti-stasis logic triggers change after N consecutive stable readings (configurable)
- [ ] #6 Patch selection logic: boost bank when too quiet, dampen bank when too loud, random bank when stable too long
- [ ] #7 Calls MidiController.send_program_change/1 when changing patches
- [ ] #8 Polling interval configurable via application config (default 100-500ms)
- [ ] #9 Module compiles and runs with mock metrics
<!-- AC:END -->
