---
id: task-12
title: AudioMonitor integration tests with recorded audio
status: To Do
assignee: []
created_date: '2025-10-10 10:33'
labels:
  - elixir
  - audio
  - testing
dependencies:
  - task-1
  - task-11
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Write integration tests for AudioMonitor using pre-recorded audio files. Test with various audio patterns (silence, sustained notes, dynamic playing) to verify metric calculation and Port handling. Use aplay to feed test audio or mock the Port interface.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Test suite created at test/audio_monitor_integration_test.exs
- [ ] #2 Test audio files created or sourced (silence.wav, sustained_note.wav, dynamic_playing.wav)
- [ ] #3 Tests verify AudioMonitor starts and initializes Port correctly
- [ ] #4 Tests verify metric extraction from audio buffers with known content
- [ ] #5 Tests verify Port restart on crash
- [ ] #6 Tests verify configuration loading for device and parameters
- [ ] #7 Tests verify get_metrics/0 returns current values
- [ ] #8 All tests pass with 'mix test'
<!-- AC:END -->
