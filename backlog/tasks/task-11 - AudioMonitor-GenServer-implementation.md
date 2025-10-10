---
id: task-11
title: AudioMonitor GenServer implementation
status: To Do
assignee: []
created_date: '2025-10-10 10:33'
labels:
  - elixir
  - audio
dependencies:
  - task-1
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement AudioMonitor GenServer that continuously reads audio input via arecord command-line tool, parses PCM samples, and calculates metrics using AudioAnalysis functions. Provides current metrics to ControlLoop via handle_call. Depends on task-1 completing (custom Nerves system with USB audio support).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 AudioMonitor GenServer module created with init/1, handle_call/3, handle_info/3
- [ ] #2 Spawns Port process running 'arecord' with appropriate parameters (device, format, rate, channels)
- [ ] #3 Parses binary PCM data from arecord stdout into lists of integer samples
- [ ] #4 Calls AudioAnalysis functions (calculate_rms, zero_crossing_rate, peak) on sample buffers
- [ ] #5 Implements get_metrics/0 function returning current RMS, ZCR, and peak values
- [ ] #6 Handles Port exit and restarts arecord if it crashes
- [ ] #7 Audio device and parameters configurable via application config
- [ ] #8 Module compiles and can run on hardware with audio input
<!-- AC:END -->
