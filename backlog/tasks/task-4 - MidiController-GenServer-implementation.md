---
id: task-4
title: MidiController GenServer implementation
status: To Do
assignee: []
created_date: '2025-10-10 10:31'
labels:
  - elixir
  - midi
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement MidiController GenServer that sends MIDI commands via the amidi command-line tool. This module wraps System.cmd/3 calls to amidi and provides a clean API for Program Change and Control Change messages. Can be tested independently without audio hardware using 'amidi -l' to verify MIDI device presence.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 MidiController GenServer module created with init/1, handle_call/3, and handle_cast/2 callbacks
- [ ] #2 Function send_program_change(memory_number) implemented (PC 0-98 for RC-600 memories 1-99)
- [ ] #3 Function send_control_change(cc_number, value) implemented (CC#1-31, CC#64-95, values 0-127)
- [ ] #4 Device selection configurable via application config
- [ ] #5 Graceful error handling when MIDI device not present
- [ ] #6 Module compiles and can be started under supervision
<!-- AC:END -->
