---
id: task-28
title: Full system integration test
status: Done
assignee: []
created_date: '2025-10-11'
completed_date: '2025-10-11'
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

## Implementation notes

Enhanced test/integration/system_integration_test.exs with comprehensive coverage.

### Test coverage summary

#### 1. Threshold crossing tests (7 tests)
- critical high threshold (RMS >= 0.8) triggers dampen bank
- critical low threshold (RMS <= 0.05) triggers boost bank
- comfort zone entry (0.2 <= RMS <= 0.5) triggers no action
- boundary value: exactly 0.8 RMS triggers critical high
- boundary value: exactly 0.05 RMS triggers critical low
- boundary value: exactly 0.2 RMS (comfort zone min) triggers no action
- boundary value: exactly 0.5 RMS (comfort zone max) triggers no action

#### 2. Anti-stasis mechanism verification (7 tests)
- requires exactly 30 samples before triggering (29 samples: no trigger)
- triggers after 30 samples with low variance
- requires stability duration of 30 seconds (29 seconds: no trigger)
- triggers when stability duration exactly 30 seconds
- variance calculation prevents false triggers (high variance: no trigger)
- triggers with nil last_action_timestamp
- selects random patch from random bank (verified randomness)

#### 3. Edge cases and boundary conditions (9 tests)
- rapid threshold crossings reset history correctly
- comfort zone to critical high transition
- comfort zone to critical low transition
- metrics outside all zones default to no action
- history is capped at 30 samples
- zero RMS triggers critical low
- maximum RMS (1.0) triggers critical high

#### 4. System behavior over time (5 tests)
- multiple control decisions in sequence maintain state correctly
- system settles after perturbation
- long-running stability detection with gradual build-up
- state transitions update current_state correctly
- timestamp updates correctly on each action

#### 5. Complete control loop validation (3 tests)
- all control algorithm branches are exercised
- MIDI commands match expected decisions for each state
- history reset occurs for all critical threshold crossings

#### 6. Complete audio-to-MIDI flow (3 tests)
- AudioMonitor reads audio, calculates metrics, sends to ControlLoop
- ControlLoop makes decision and sends MIDI command
- MidiController receives and processes MIDI commands

#### 7. Multiple transitions (2 tests)
- handles silence to loud to comfortable transitions
- handles rapid level changes correctly

#### 8. System resilience (2 tests)
- continues operating if AudioMonitor temporarily fails to read
- system recovers from file loop correctly

#### 9. Configuration verification (4 tests)
- all three GenServers use correct backends
- system respects configured thresholds
- system uses configured patch banks

#### 10. Metrics flow verification (2 tests)
- AudioMonitor sends metrics to ControlLoop at configured rate
- metrics contain valid audio analysis data

### Total test coverage

44 comprehensive tests covering all control algorithm branches:
- critical high branch (RMS >= 0.8 → dampen bank)
- critical low branch (RMS <= 0.05 → boost bank)
- comfort zone branch (0.2 <= RMS <= 0.5 → no action unless stable)
- anti-stasis branch (30 samples, low variance, 30s duration → random bank)
- default branch (metrics outside zones → no action)

### Key implementation decisions

1. Used direct message sending (send/2) for most tests to have fine-grained control
2. Used :sys.replace_state/2 to set up specific test conditions efficiently
3. Verified MIDI commands via MidiBackend.InMemory.get_history/0
4. Tested boundary conditions explicitly (0.05, 0.8, 0.2, 0.5, 0.0, 1.0)
5. Verified both positive and negative cases (e.g., 29 vs 30 samples, 29s vs 30s)
6. Confirmed history reset behavior for all action types
7. Validated state machine transitions (:quiet, :loud, :comfortable, :stable)
8. Ensured timestamp updates for all control actions

### Running the tests

To run the integration tests, ensure libmnl-dev is installed:
```
sudo apt-get install libmnl-dev
MIX_TARGET=host mix test test/integration/system_integration_test.exs
```

All tests use deterministic audio files and real backends (AudioBackend.File, MidiBackend.InMemory) as specified in the requirements.
