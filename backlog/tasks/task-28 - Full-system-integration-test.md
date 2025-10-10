---
id: task-28
title: Full system integration test
status: To Do
assignee: []
created_date: '2025-10-11'
labels:
  - elixir
  - testing
  - integration
dependencies:
  - task-13
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create comprehensive integration test that validates the complete control loop with all three GenServers running together. Uses simulated audio scenarios (via AudioBackend.File) to trigger specific control decisions and verifies correct MIDI commands sent (via MidiBackend.InMemory). This is the final validation before hardware deployment.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Integration test file created at test/integration/control_loop_integration_test.exs
- [ ] #2 Test starts full supervision tree with test backends (AudioBackend.File, MidiBackend.InMemory)
- [ ] #3 Test audio files created for each scenario: silence.wav, quiet.wav, loud.wav, stable.wav
- [ ] #4 Scenario 1: silence detection → boost bank selection verified
- [ ] #5 Scenario 2: overload detection → dampen bank selection verified
- [ ] #6 Scenario 3: extended stability → random bank selection (anti-stasis) verified
- [ ] #7 Scenario 4: AudioMonitor crash/restart → ControlLoop recovers, continues operating
- [ ] #8 Scenario 5: metric fluctuation → stability counter resets correctly
- [ ] #9 All MIDI commands verified via MidiBackend.InMemory inspection
- [ ] #10 Test verifies timing (anti-stasis after N readings, not before)
- [ ] #11 Test verifies state persistence (stability counter, last action timestamp)
- [ ] #12 All integration tests pass, full system behaviour validated
<!-- AC:END -->

## Test scenarios detail

### Scenario 1: silence detection
- input: silence.wav (RMS < 0.05 for 5 consecutive readings)
- expected: program change to boost bank memory number
- verify: correct PC message, no premature anti-stasis trigger

### Scenario 2: overload detection
- input: loud.wav (RMS > 0.8 for 3 consecutive readings)
- expected: program change to dampen bank memory number
- verify: correct PC message, stability counter reset

### Scenario 3: extended stability
- input: stable.wav (RMS in comfort zone 0.2-0.5, stable for 20 readings)
- expected: anti-stasis random bank selection
- verify: random PC message after exactly N readings

### Scenario 4: recovery from failure
- input: normal audio, then kill AudioMonitor process
- expected: ControlLoop continues with last known metrics, recovers when AudioMonitor restarts
- verify: no crashes, graceful degradation

### Scenario 5: metric fluctuation
- input: audio with small RMS changes within comfort zone
- expected: stability counter increments only if change < 0.05
- verify: counter resets on significant change
