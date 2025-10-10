---
id: task-14
title: RC-600 MIDI setup and test procedure documentation
status: To Do
assignee: []
created_date: '2025-10-10 10:33'
labels:
  - documentation
  - midi
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Document the procedure for configuring the BOSS RC-600 loop pedal for MIDI control from the homeostat. Include MIDI assign setup, memory configuration, and testing steps to verify bidirectional communication. This task consolidates research from task-2 with concrete setup instructions.

## MIDI control capabilities (from task-2 research)

### Available CC messages
- **Assignable CC numbers**: CC#1–#31, CC#64–#95
- **Assignment system**: 16 MIDI assigns per memory/preset (99 presets total)
- **Note**: CC#30-60 may be reserved for system functions

### Control capabilities

**Program Change (PC) messages:**
- switch between 99 memories (PC 0 = Memory 1, PC 1 = Memory 2, etc.)

**Assignable controls via MIDI CC:**
- rhythm start/stop
- track record/play
- overdub state control
- drum pattern variation changes
- BPM sync via MIDI clock

### Key limitations

**No direct low-level parameter control:**
The RC-600 uses a **flexible ASSIGN system** rather than fixed MIDI CC mappings. You can map available CC numbers to various functions, but:
- assigns are **per-memory**, not system-wide
- only 16 assigns per preset
- some functions (like "memory write") are not assignable

### Implementation approach

Configure one preset on the RC-600 with the 16 most important assigned functions, then control those via MIDI CC messages from this module. Use PC messages to switch between different memory configurations if needed.

### Resources

- Official documentation: https://www.boss.info/global/support/by_product/rc-600/owners_manuals/
- User discussion: https://forum.morningstar.io/t/anyone-using-mc8-with-boss-rc-600/3514
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
