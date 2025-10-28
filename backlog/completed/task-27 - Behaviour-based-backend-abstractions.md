---
id: task-27
title: Behaviour-based backend abstractions
status: Done
assignee: []
created_date: '2025-10-11'
completed_date: '2025-10-24'
labels:
  - elixir
  - architecture
  - testing
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create behaviour-based abstractions for MIDI and audio I/O to enable testing without hardware and without mocking. Define MidiBackend and AudioBackend behaviours with multiple implementations: production backends (Amidi, Port) and test backends (InMemory, File). This architectural pattern eliminates the need for mocking libraries while providing clean testability.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 MidiBackend behaviour defined with callbacks: send_program_change/2, send_control_change/3
- [ ] #2 MidiBackend.Amidi implementation using System.cmd/3 to call amidi (deferred to Phase 4 - hardware deployment)
- [x] #3 MidiBackend.InMemory implementation storing commands in state for test assertions
- [x] #4 AudioBackend behaviour defined with callbacks: start_link/1, read_buffer/1
- [ ] #5 AudioBackend.Port implementation spawning arecord Port process (deferred to Phase 4 - hardware deployment)
- [x] #6 AudioBackend.File implementation reading from raw binary files (loops on EOF)
- [x] #7 Backend selection configurable via application env (e.g., :midi_backend, :audio_backend)
- [x] #8 Backend modules are self-documenting through clear function signatures and behaviour contracts
- [x] #9 Test helpers provided for backend assertions (MidiBackend.InMemory.get_history/0, clear_history/0)
- [x] #10 All backend modules compile without errors
- [x] #11 Integration tests demonstrate backend usage (File/InMemory backends used throughout test suite)
<!-- AC:END -->

## Implementation notes

### MidiBackend behaviour

```elixir
defmodule HendrixHomeostat.MidiBackend do
  @callback send_program_change(device :: String.t(), memory :: integer()) :: :ok | {:error, term()}
  @callback send_control_change(device :: String.t(), cc :: integer(), value :: integer()) :: :ok | {:error, term()}
end
```

### AudioBackend behaviour

```elixir
defmodule HendrixHomeostat.AudioBackend do
  @callback start_link(config :: map()) :: {:ok, pid()} | {:error, term()}
  @callback read_buffer(pid()) :: {:ok, binary()} | {:error, term()}
end
```

### Benefits

- No mocking libraries required (aligns with coding guidelines)
- Tests use real code paths with different backends
- Easy to add new backends (network audio, different MIDI protocols)
- Clear architectural boundaries
- Behaviour contracts ensure implementation compatibility

## Completion notes

### Implemented test backends (Phase 1-3)

**MidiBackend.InMemory** (`lib/hendrix_homeostat/midi_backend/in_memory.ex`)
- Agent-based implementation storing MIDI commands with timestamps
- `get_history/0` returns commands in chronological order
- `clear_history/0` resets state for test isolation
- Used successfully in all MidiController and integration tests

**AudioBackend.File** (`lib/hendrix_homeostat/audio_backend/file.ex`)
- GenServer-based implementation reading raw 16-bit PCM binary data
- Loops back to file start on EOF for continuous testing
- Tracks file position for debugging
- Used successfully in AudioMonitor and integration tests

### Production backends (deferred to Phase 4)

**MidiBackend.Amidi** - not yet implemented
- Will use `System.cmd/3` to invoke `amidi` for hardware MIDI
- Required for Raspberry Pi 5 deployment

**AudioBackend.Port** - not yet implemented
- Will spawn `arecord` as Port process for real-time audio capture
- Required for Raspberry Pi 5 deployment

### Configuration

Backend selection is fully configurable in `config/runtime.exs`:
- Host target: uses InMemory and File backends for testing
- Hardware target (rpi5): configured for Amidi and Port backends

All test backends have been validated through comprehensive test suite (300+ tests) and full system integration testing.
