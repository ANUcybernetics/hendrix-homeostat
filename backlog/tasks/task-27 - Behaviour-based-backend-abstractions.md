---
id: task-27
title: Behaviour-based backend abstractions
status: To Do
assignee: []
created_date: '2025-10-11'
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
- [ ] #1 MidiBackend behaviour defined with callbacks: send_program_change/2, send_control_change/3
- [ ] #2 MidiBackend.Amidi implementation using System.cmd/3 to call amidi
- [ ] #3 MidiBackend.InMemory implementation storing commands in state for test assertions
- [ ] #4 AudioBackend behaviour defined with callbacks: start_link/1, read_buffer/1
- [ ] #5 AudioBackend.Port implementation spawning arecord Port process
- [ ] #6 AudioBackend.File implementation reading from .wav files with header parsing
- [ ] #7 Backend selection configurable via application env (e.g., :midi_backend, :audio_backend)
- [ ] #8 Each backend module documented with usage examples
- [ ] #9 Test helpers provided for backend assertions (e.g., MidiBackend.InMemory.get_commands/1)
- [ ] #10 All backend modules compile without errors
- [ ] #11 Simple integration test demonstrates backend swapping (File -> Port)
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
