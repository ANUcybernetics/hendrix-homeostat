---
id: task-13
title: Integrate ControlLoop with AudioMonitor
status: To Do
assignee: []
created_date: '2025-10-10 10:33'
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
- [ ] #1 ControlLoop modified to call AudioMonitor.get_metrics/0 instead of using mock values
- [ ] #2 Mock metric code removed or moved to test helpers
- [ ] #3 Error handling added for when AudioMonitor is unavailable
- [ ] #4 Verified polling loop calls AudioMonitor at configured interval
- [ ] #5 Integration test created verifying ControlLoop receives metrics from AudioMonitor
- [ ] #6 Integration test verifies control decisions based on real metric values
- [ ] #7 System runs end-to-end with recorded audio input
<!-- AC:END -->
