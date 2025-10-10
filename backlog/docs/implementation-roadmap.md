# Implementation roadmap

This document outlines the implementation phases for the Hendrix homeostat project, showing how individual tasks group together into logical phases and explaining dependencies between them.

## Overview

The project implements a cybernetic control system that monitors audio feedback and controls a BOSS RC-600 loop pedal to maintain dynamic equilibrium. The implementation follows a bottom-up approach, building testable components that can be developed without hardware, then integrating them in phases.

## Phase 1: Foundation and pure logic (no hardware required)

**Goal**: establish project structure, pure functions, and testable abstractions

### Tasks
- task-3: project setup and supervision tree
- task-27: behaviour-based backend abstractions (NEW)
- task-6: audio analysis pure functions
- task-7: audio analysis unit tests
- task-10: configuration system

### Key decisions
- supervision tree uses `:one_for_one` strategy with explicit process naming
- behaviour abstractions (MidiBackend, AudioBackend) enable testing without mocking
- pure functions for audio analysis (RMS, ZCR, peak) use simple Elixir stdlib
- configuration uses `config/runtime.exs` for Nerves compatibility

### Notes
- all tasks in this phase can be completed on macOS/Linux without Nerves hardware
- tests run with in-memory backends, no external dependencies
- pure functions provide foundation for later integration

## Phase 2: Core GenServers with test backends (no hardware required)

**Goal**: implement the three main GenServers using behaviour-based backends for testing

### Tasks
- task-4: MidiController GenServer implementation
- task-5: MidiController unit tests
- task-8: ControlLoop GenServer implementation
- task-9: ControlLoop unit tests
- task-11: AudioMonitor GenServer implementation
- task-12: AudioMonitor integration tests

### Architecture patterns
- **MidiController**: uses MidiBackend behaviour, sends program changes and CC messages
- **AudioMonitor**: uses AudioBackend behaviour, calculates metrics on audio buffers
- **ControlLoop**: receives metrics via message passing (push, not poll), makes control decisions

### Important changes from initial plan
- **Push-based metrics**: AudioMonitor sends metrics directly to ControlLoop instead of polling
- **Backend abstractions**: no mocking of `System.cmd/3`, use behaviours instead
- **State management**: GenServers explicitly define state structures

### Notes
- all GenServers can be tested independently using test backends
- MidiBackend.InMemory records MIDI commands for assertion
- AudioBackend.File reads from .wav files for deterministic testing
- ControlLoop receives metrics as `handle_info` messages

## Phase 3: System integration (no hardware required)

**Goal**: integrate all components and test end-to-end behaviour with simulated scenarios

### Tasks
- task-13: integrate ControlLoop with AudioMonitor and MidiController
- task-28: full system integration test (NEW)

### Integration approach
- all three GenServers running under supervision tree
- AudioMonitor reads from test audio files (via AudioBackend.File)
- MidiController uses in-memory backend to capture decisions
- integration tests verify complete control loop behaviour

### Test scenarios
- silence detection → boost bank selection
- overload detection → dampen bank selection
- extended stability → random bank selection (anti-stasis)
- recovery from metric unavailability

### Notes
- this is the last phase before hardware deployment
- tests should cover all control algorithm branches
- provides confidence before Nerves firmware build

## Phase 4: Hardware integration and validation (requires Raspberry Pi 5)

**Goal**: deploy to Nerves, integrate with real hardware, validate control loop

### Tasks
- task-1: add audio kernel modules (custom Nerves system)
- task-14: RC-600 MIDI setup and test procedure documentation
- task-15: hardware testing on Pi 5 with real audio and MIDI
- task-16: threshold and timing parameter tuning

### Critical milestone
This phase is the **hardware validation checkpoint**. The system must:
- correctly capture audio from Presonus Revelator io24
- successfully send MIDI to RC-600 and observe patch changes
- maintain control loop without crashes
- show expected behaviour (boost when quiet, dampen when loud, etc.)

### Hardware-specific concerns
- USB audio device detection and initialization
- ALSA configuration for low-latency capture
- MIDI device identification (amidi -l)
- Port process management and cleanup

### Notes
- task-1 is already in progress (custom system build on Ubuntu)
- AudioBackend.Port implementation uses `arecord` subprocess
- MidiBackend.Amidi implementation uses `amidi` subprocess
- initial testing should use verbose logging to verify behaviour

## Phase 5: Robustness and error recovery

**Goal**: handle failures gracefully, implement fault tolerance

### Tasks
- task-19: logging and observability instrumentation
- task-20: error recovery and fault tolerance
- task-29: startup, shutdown, and calibration (NEW)

### Error scenarios
- USB device unplugged during operation
- Port process crashes or hangs
- GenServer crashes and restarts
- MIDI commands fail (device not responding)
- audio buffer overruns

### Recovery strategies
- exponential backoff for Port restart
- circuit breaker for repeated failures
- graceful degradation when AudioMonitor unavailable
- supervisor restart intensity limits
- USB hotplug detection

### Observability
- structured logging using Logger metadata
- remote IEx access via SSH (nerves_pack)
- telemetry instrumentation for metrics
- RingLogger for persistent logs

### Notes
- remote debugging is essential for headless deployment
- logs should indicate why decisions were made (metric values, thresholds crossed)
- proper shutdown ensures Port cleanup

## Phase 6: Operational polish

**Goal**: make system easy to configure, tune, and maintain in production

### Tasks
- task-17: patch bank configuration and mapping
- task-22: system state persistence across reboots
- task-23: interactive runtime configuration via IEx

### Configuration approach
- static config in `config/runtime.exs` (device paths, sample rates)
- runtime-tunable parameters in GenServer state (thresholds, timing)
- optional persistence to restore state after reboot
- IEx commands for live parameter adjustment

### Tuning workflow
1. deploy firmware with default config
2. SSH into device, attach IEx shell
3. adjust thresholds/timing interactively
4. observe behaviour changes in real-time
5. persist working config if desired

### Notes
- persistence is optional (can run stateless)
- configuration changes via `GenServer.call` to ControlLoop
- patch banks defined as lists of RC-600 memory numbers

## Phase 7: Documentation and handoff

**Goal**: document the system for future maintenance and understanding

### Tasks
- task-18: firmware building and flashing documentation
- task-25: project README and architecture documentation

### Documentation coverage
- architecture overview (GenServer responsibilities, data flow)
- control algorithm explanation (thresholds, anti-stasis logic)
- hardware setup instructions (gain staging, device configuration)
- firmware build process (custom system, Docker workflow)
- troubleshooting guide (common issues, debugging steps)

### Notes
- README should explain conceptual mapping to Ashby's homeostat
- architecture docs should include supervision tree diagram
- build docs should cover both macOS and Linux workflows

## Removed tasks

The following tasks from the original plan have been removed as unnecessary for initial implementation:

- **task-21** (performance profiling): premature optimization; fold into task-15 if issues arise
- **task-24** (visualization): awkward for headless device; use telemetry or Phoenix LiveDashboard if needed later

## New tasks added

- **task-27**: behaviour-based backend abstractions (MidiBackend, AudioBackend)
- **task-28**: full system integration test with simulated scenarios
- **task-29**: startup, shutdown, and calibration procedures

## Consolidated tasks

- **task-2** merged into **task-14**: RC-600 documentation is part of MIDI setup
- **tasks 10, 22, 23** remain separate but closely related: configuration system, persistence, runtime tuning

## Dependencies between phases

- **Phase 1 → Phase 2**: pure functions and backends required before GenServers
- **Phase 2 → Phase 3**: individual GenServers must work before integration
- **Phase 3 → Phase 4**: integration tests must pass before hardware deployment
- **Phase 4 → Phase 5**: basic hardware operation required before error handling
- **Phase 5 → Phase 6**: robust system required before operational polish
- **Phase 6 → Phase 7**: working system required before final documentation

## Parallel work opportunities

These phases/tasks can be done concurrently:
- Phase 1 tasks are mostly independent (can parallelize)
- task-6/7 (audio analysis) can be done in parallel with task-10 (config)
- Phase 2 GenServers can be developed in parallel (4, 8, 11)
- task-19 (logging) can be added throughout development
- Phase 7 documentation can be written alongside implementation

## Tasks that require hardware

Only these tasks absolutely require Raspberry Pi 5 hardware:
- task-1: custom Nerves system build (requires Ubuntu VM)
- task-15: hardware testing
- task-16: parameter tuning
- task-18: firmware flashing documentation

All other tasks (including integration testing) can be completed on development machine.

## Critical path

The minimum viable implementation follows this path:

1. task-3 → task-27 → task-6 → task-10 (foundation)
2. task-4 → task-8 → task-11 (GenServers)
3. task-13 → task-28 (integration)
4. task-1 → task-14 → task-15 (hardware deployment)
5. task-16 (tuning)

This represents ~12 tasks to get a working system deployed and tuned.

## Performance considerations

**Audio processing performance**: initial implementation uses pure Elixir for audio analysis (RMS, ZCR, peak). At 10Hz update rate with 48kHz audio, this means processing ~4800 samples per buffer. The Pi 5 has sufficient CPU for this workload.

**If optimization needed** (discovered during task-15):
- option 1: simple C NIF compiled locally (no external deps)
- option 2: Rustler for safer NIF development
- option 3: Nx/EXLA (brings heavy dependencies)

**Recommendation**: start with pure Elixir, only optimize if task-15 reveals bottlenecks.

## Architecture decision rationale

### Why push-based metrics (not polling)?
- lower latency (immediate reaction to threshold crossings)
- no timer drift accumulation
- simpler code (no polling loop in ControlLoop)
- natural message flow (AudioMonitor → ControlLoop → MidiController)

### Why behaviour abstractions (not mocks)?
- aligns with your coding guidelines (no mocking)
- tests use real code paths
- clearer architecture (explicit backend interfaces)
- easier to add new backends (e.g., audio from network stream)

### Why flat supervision tree?
- simple failure isolation (one GenServer crash doesn't affect others)
- explicit startup order via process registration
- easy to reason about restart behaviour
- sufficient for three-process system

### Why GenServers (not GenStage)?
- simpler mental model for small system
- adequate for three processes
- no backpressure needed (10Hz update rate is manageable)
- GenStage would be over-engineering

## Next steps after implementation

Future enhancements beyond initial scope:
- Phoenix LiveDashboard for real-time visualization
- telemetry metrics export (Prometheus, etc.)
- web UI for configuration (instead of IEx)
- audio recording/playback for offline analysis
- more sophisticated audio features (spectral centroid, onset detection)
- machine learning for patch selection (instead of rule-based)

These should only be considered after the core system is deployed and validated in production use.
