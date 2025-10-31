---
id: task-30
title: Update MIDI config to use stable RC-600 card name
status: To Do
assignee: []
created_date: '2025-10-31'
labels:
  - hardware
  - config
  - midi
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure the Boss RC-600 MIDI device to use ALSA card name instead of numeric identifier for stability across reboots and device reconnections. ALSA numeric device identifiers like `hw:0,0,0` can change if devices are plugged in different orders, while card names (e.g., `hw:RC600`, `hw:MINI`) are stable and more reliable. This approach has been verified with the X-TOUCH MINI test device.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Identify RC-600 ALSA card name using `cat /proc/asound/cards` or `amidi -l` with hardware connected
- [ ] #2 Update config/runtime.exs to use stable card name (e.g., hw:RC600) instead of hw:0,0,0
- [ ] #3 Test MIDI communication works with the new card name configuration
- [ ] #4 Document the card name in comments for future reference
<!-- AC:END -->
