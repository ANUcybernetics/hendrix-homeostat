---
id: task-2
title: BOSS RC-600 loop pedal control module
status: To Do
assignee: []
created_date: '2025-10-10 05:59'
updated_date: '2025-10-10 10:36'
labels:
  - midi
  - documentation
  - research
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
This project needs to control a BOSS RC-600 loop pedal via MIDI cc messages. It needs to be able to change as many of the loop parameters as possible.

## MIDI control capabilities

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
