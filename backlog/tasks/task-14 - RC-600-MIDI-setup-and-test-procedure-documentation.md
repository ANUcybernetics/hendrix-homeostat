---
id: task-14
title: RC-600 MIDI setup and test procedure documentation
status: To Do
assignee: []
created_date: '2025-10-10 10:33'
labels:
  - documentation
  - midi
dependencies:
  - task-2
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Document the procedure for configuring the BOSS RC-600 loop pedal for MIDI control from the homeostat. Include MIDI assign setup, memory configuration, and testing steps to verify bidirectional communication. Expand on task-2's research with concrete setup instructions.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Documentation file created at docs/rc600_midi_setup.md
- [ ] #2 Documents how to configure MIDI assigns on RC-600 (16 assigns per memory)
- [ ] #3 Provides recommended assign mapping for homeostat control (rhythm, track, overdub, etc.)
- [ ] #4 Documents Program Change mapping (PC 0-98 for memories 1-99)
- [ ] #5 Includes testing procedure with amidi to verify commands received by RC-600
- [ ] #6 Documents limitations (no direct low-level parameter control, per-memory assigns)
- [ ] #7 Includes reference links to RC-600 manual and MIDI implementation chart
<!-- AC:END -->
