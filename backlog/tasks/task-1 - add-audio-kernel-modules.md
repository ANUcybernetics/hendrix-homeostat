---
id: task-1
title: add audio kernel modules
status: To Do
assignee: []
created_date: '2025-10-10 05:02'
updated_date: '2025-10-10 05:02'
labels:
  - nerves
  - audio
  - midi
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add USB audio/MIDI support to custom Nerves system for Raspberry Pi 5. The base nerves_system_rpi5 doesn't include USB audio/MIDI support by default. Need to create a custom system with the required kernel modules for Presonus Revelator io24 interface (audio in from guitar pickup, MIDI out to RC-600).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Fork or create custom Nerves system based on nerves_system_rpi5
- [ ] #2 Enable required kernel modules via Buildroot menuconfig (BR2_PACKAGE_ALSA_UTILS, BR2_PACKAGE_ALSA_UTILS_APLAY, BR2_PACKAGE_ALSA_UTILS_AMIDI, USB sound device support, snd_usbmidi_lib)
- [ ] #3 Rebuild system with audio/MIDI modules included
- [ ] #4 Verify USB device recognition with lsusb
- [ ] #5 Test audio playback/capture with aplay -l and arecord -l
- [ ] #6 Test MIDI devices with amidi -l
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Review nerves_system_rpi5 documentation and fork/create custom system
2. Configure Buildroot menuconfig to enable ALSA and USB audio modules
3. Add kernel config for snd_usbmidi_lib and USB sound support
4. Build custom Nerves system
5. Flash to Pi 5 and test USB device recognition
6. Verify audio and MIDI functionality
7. Document any Presonus-specific limitations (StudioLive mode, UC Surface, vendor DSP won't work)
8. Research MIDI library options for Elixir integration (amidi shell commands, MidiEx, Sonic Pi MIDI, or custom port driver)

Hardware: Raspberry Pi 5, Presonus Revelator io24

Resources:
- Elixir Forum: "What are the options for Midi + Nerves?"
- Elixir Forum: "Enabling audio on Nerves with Raspberry Pi"
- https://hexdocs.pm/nerves_system_rpi5/readme.html

Fallback: If Nerves proves too complex, use standard Raspberry Pi OS with Elixir (USB audio/MIDI works OOTB), migrate to Nerves later
<!-- SECTION:PLAN:END -->
