---
id: task-15
title: Hardware testing on Pi 5 with real audio and MIDI
status: To Do
assignee: []
created_date: '2025-10-10 10:34'
labels:
  - testing
  - hardware
  - nerves
dependencies:
  - task-1
  - task-11
  - task-4
  - task-13
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Perform comprehensive hardware testing on Raspberry Pi 5 with Presonus Revelator io24 (audio) and BOSS RC-600 (MIDI). Verify USB device recognition, audio capture, MIDI output, and full system operation. Document any hardware-specific issues or tuning requirements.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pi 5 boots successfully with custom Nerves system firmware
- [ ] #2 lsusb shows Presonus Revelator io24 and RC-600 recognized
- [ ] #3 arecord -l and aplay -l show correct audio device
- [ ] #4 amidi -l shows RC-600 MIDI port
- [ ] #5 AudioMonitor successfully captures audio from guitar input
- [ ] #6 MidiController successfully sends commands to RC-600
- [ ] #7 ControlLoop operates continuously without crashes
- [ ] #8 Full feedback loop verified: audio in, metric calculation, MIDI command out, RC-600 responds
- [ ] #9 Document any latency, stability, or performance issues observed
<!-- AC:END -->
