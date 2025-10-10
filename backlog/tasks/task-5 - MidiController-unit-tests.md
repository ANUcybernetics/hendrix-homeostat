---
id: task-5
title: MidiController unit tests
status: To Do
assignee: []
created_date: '2025-10-10 10:31'
labels:
  - elixir
  - midi
  - testing
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Write comprehensive unit tests for MidiController GenServer. Test Program Change and Control Change message sending, error handling when backend fails, and proper GenServer lifecycle. Uses MidiBackend.InMemory for testing without actual MIDI hardware (no mocking required).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Test file created at test/hendrix_homeostat/midi_controller_test.exs
- [ ] #2 Tests configured to use MidiBackend.InMemory via test config
- [ ] #3 Tests for send_program_change/1 with valid memory numbers (1-99)
- [ ] #4 Tests for send_control_change/2 with valid CC numbers and values
- [ ] #5 Tests verify correct MIDI messages sent to backend (inspect InMemory backend state)
- [ ] #6 Tests for invalid inputs (out of range values, negative numbers)
- [ ] #7 Tests for backend failure scenario (InMemory configured to return errors)
- [ ] #8 Tests for GenServer start_link, init, and shutdown
- [ ] #9 All tests pass without requiring MIDI hardware
- [ ] #10 Test coverage >90% for MidiController module
<!-- AC:END -->
