---
id: task-11
title: AudioMonitor GenServer implementation
status: Done
assignee: []
created_date: '2025-10-10 10:33'
completed_date: '2025-10-11'
labels:
  - elixir
  - audio
dependencies:
  - task-1
  - task-27
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement AudioMonitor GenServer that continuously reads audio input via AudioBackend (abstracts arecord or file input), calculates metrics using AudioAnalysis functions, and sends metrics to ControlLoop via message passing. Uses behaviour-based backend for testability. Depends on task-1 (custom Nerves system) and task-27 (backend abstractions).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 AudioMonitor GenServer module created with init/1, handle_info/2
- [x] #2 State structure explicitly defined: backend, backend_state, control_loop_pid, last_metrics, config
- [x] #3 Uses AudioBackend behaviour for audio input (injected via config)
- [x] #4 On receiving audio buffer from backend, calls AudioAnalysis functions (calculate_rms, zero_crossing_rate, peak)
- [x] #5 Sends metrics to ControlLoop via `send(control_loop_pid, {:metrics, {rms, zcr, peak}})`
- [x] #6 Target update rate ~10Hz (configurable buffer size to achieve this at 48kHz)
- [x] #7 Handles backend errors gracefully, logs warnings but continues operating
- [x] #8 Audio device and buffer parameters configurable via application config
- [x] #9 Module compiles and can run with both File and Port backends
<!-- AC:END -->
