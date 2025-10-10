---
id: task-4
title: MidiController GenServer implementation
status: To Do
assignee: []
created_date: '2025-10-10 10:31'
labels:
  - elixir
  - midi
dependencies:
  - task-27
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement MidiController GenServer that sends MIDI commands via MidiBackend behaviour (abstracts amidi or in-memory recording). Provides clean API for Program Change and Control Change messages. Uses behaviour-based backend for testability without hardware. Depends on task-27 (backend abstractions).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 MidiController GenServer module created with init/1, handle_cast/2 callbacks
- [ ] #2 Uses MidiBackend behaviour for sending MIDI (injected via config)
- [ ] #3 Implements `send_program_change(memory_number)` as cast (PC 0-98 for RC-600 memories 1-99)
- [ ] #4 Implements `send_control_change(cc_number, value)` as cast (CC#1-31, CC#64-95, values 0-127)
- [ ] #5 State tracks backend, device config, and last sent command (for debugging)
- [ ] #6 Graceful error handling when backend reports failure (logs error, continues operating)
- [ ] #7 Device selection configurable via application config
- [ ] #8 Module compiles and can be started under supervision with both Amidi and InMemory backends
<!-- AC:END -->
