---
id: task-29
title: Startup, shutdown, and calibration
status: To Do
assignee: []
created_date: '2025-10-11'
labels:
  - elixir
  - nerves
  - operations
dependencies:
  - task-15
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement proper startup sequence, graceful shutdown, and initial calibration procedures for the homeostat system. Handle device detection at boot, provide calibration mode for initial setup, and ensure clean shutdown on reboot/poweroff. This task addresses operational concerns for running on headless Nerves device.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Startup sequence: verify USB devices present before starting GenServers
- [ ] #2 Device detection: check for MIDI device (amidi -l) and audio device (arecord -l) at boot
- [ ] #3 Retry logic: if devices not present, retry with backoff (max 30s), then log error and continue
- [ ] #4 Calibration mode: environment variable CALIBRATION_MODE=true enables test mode
- [ ] #5 In calibration mode: log metrics without sending MIDI, display audio levels
- [ ] #6 Calibration output: RMS values logged at info level, suggestions for threshold tuning
- [ ] #7 Graceful shutdown: trap SIGTERM, cleanly stop GenServers and Ports
- [ ] #8 Shutdown timeout: give GenServers 5 seconds to cleanup before force kill
- [ ] #9 State persistence optional: if enabled, save current patch and thresholds to file
- [ ] #10 State restore on boot: load saved state if present, use defaults otherwise
- [ ] #11 Health check: simple TCP endpoint returns "ok" when system running (for monitoring)
- [ ] #12 Documentation: instructions for initial calibration and threshold tuning
<!-- AC:END -->

## Calibration workflow

1. Boot device with `CALIBRATION_MODE=true` env var
2. SSH into device, attach IEx shell
3. Play audio (guitar feedback), observe logged RMS values
4. Adjust input gain until RMS peaks around 0.6-0.8
5. Note comfortable RMS range (e.g., 0.2-0.5)
6. Update thresholds in config if needed
7. Reboot without calibration mode, verify control loop operates correctly

## Startup sequence

```
1. Application.start/2 called
2. Load configuration from runtime.exs
3. Validate config (devices, thresholds, banks)
4. Check USB device presence (retry with backoff)
5. Start supervision tree
6. Log startup complete with config summary
```

## Shutdown sequence

```
1. SIGTERM received
2. Application.stop/1 called
3. Supervisor stops children (MidiController, AudioMonitor, ControlLoop)
4. Each GenServer's terminate/2 cleans up Ports
5. Optional: persist state to disk
6. Return :ok, system shuts down cleanly
```
