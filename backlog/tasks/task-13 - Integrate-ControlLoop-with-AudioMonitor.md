---
id: task-13
title: Integrate ControlLoop with AudioMonitor
status: Done
assignee: []
created_date: '2025-10-10 10:33'
completed_date: '2025-10-11'
labels:
  - elixir
  - integration
dependencies:
  - task-8
  - task-11
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Connect ControlLoop to AudioMonitor by replacing mock metrics with real metric queries. ControlLoop periodically calls AudioMonitor.get_metrics/0 and uses returned values for control decisions. Test end-to-end flow without hardware using recorded audio.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ControlLoop receives metrics via handle_info({:metrics, map}, state) sent by AudioMonitor
- [x] #2 No mock metric code in ControlLoop (uses real metrics from AudioMonitor)
- [x] #3 AudioMonitor sends metrics to ControlLoop at configured update_rate (10 Hz)
- [x] #4 Integration verified: AudioMonitor → metrics → ControlLoop → MidiController → backend
- [x] #5 Integration test created at test/integration/system_integration_test.exs
- [x] #6 Integration tests verify all control scenarios: silence, loud, comfortable, stable
- [x] #7 Integration tests use real backends (AudioBackend.File, MidiBackend.InMemory)
- [x] #8 Manual integration test created for verification without full build environment
<!-- AC:END -->
