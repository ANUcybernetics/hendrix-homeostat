---
id: task-9
title: ControlLoop unit tests with mock metrics
status: To Do
assignee: []
created_date: '2025-10-10 10:32'
labels:
  - elixir
  - control-logic
  - testing
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Write comprehensive unit tests for ControlLoop control logic. Test threshold detection, stability tracking, anti-stasis behavior, and patch selection using mock metric values. Verify correct MIDI commands sent for each scenario.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Test suite created at test/control_loop_test.exs
- [ ] #2 Tests verify critical_high threshold triggers dampen bank selection
- [ ] #3 Tests verify critical_low threshold triggers boost bank selection
- [ ] #4 Tests verify comfort_zone maintains current state
- [ ] #5 Tests verify stability counter increments in comfort zone
- [ ] #6 Tests verify anti-stasis triggers random bank after N stable readings
- [ ] #7 Tests verify stability counter resets when leaving comfort zone
- [ ] #8 Tests verify correct Program Change messages sent via MidiController
- [ ] #9 Tests verify configurable polling interval
- [ ] #10 All tests pass with 'mix test'
<!-- AC:END -->
