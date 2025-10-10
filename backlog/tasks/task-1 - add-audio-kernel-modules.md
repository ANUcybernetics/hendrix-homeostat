---
id: task-1
title: add audio kernel modules
status: In Progress
assignee: []
created_date: '2025-10-10 05:02'
updated_date: '2025-10-10 05:43'
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
- [x] #1 Fork or create custom Nerves system based on nerves_system_rpi5
- [x] #2 Enable required kernel modules via Buildroot menuconfig (BR2_PACKAGE_ALSA_UTILS, BR2_PACKAGE_ALSA_UTILS_APLAY, BR2_PACKAGE_ALSA_UTILS_AMIDI, USB sound device support, snd_usbmidi_lib)
- [ ] #3 Rebuild system with audio/MIDI modules included (IN PROGRESS - firmware build running)
- [ ] #4 Verify USB device recognition with lsusb
- [ ] #5 Test audio playback/capture with aplay -l and arecord -l
- [ ] #6 Test MIDI devices with amidi -l
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. ✅ Review nerves_system_rpi5 documentation and fork/create custom system
2. ✅ Configure Buildroot menuconfig to enable ALSA and USB audio modules
3. ✅ Add kernel config for snd_usbmidi_lib and USB sound support
4. 🔄 Build custom Nerves system (IN PROGRESS - started on macOS, can continue on Ubuntu)
5. Flash to Pi 5 and test USB device recognition
6. Verify audio and MIDI functionality
7. Document any Presonus-specific limitations (StudioLive mode, UC Surface, vendor DSP won't work)
8. Research MIDI library options for Elixir integration (amidi shell commands, MidiEx, Sonic Pi MIDI, or custom port driver)

Hardware: Raspberry Pi 5, Presonus Revelator io24

Resources:
- Elixir Forum: "What are the options for Midi + Nerves?"
- Elixir Forum: "Enabling audio on Nerves with Raspberry Pi"
- https://hexdocs.pm/nerves_system_rpi5/readme.html
- Reference project: strobe-audio/strobe_receiver_rpi3 (multi-room audio system using Nerves with custom ALSA config)

Fallback: If Nerves proves too complex, use standard Raspberry Pi OS with Elixir (USB audio/MIDI works OOTB), migrate to Nerves later

## Progress Notes

### 2025-10-10

**Custom system created:**
- Repository: https://github.com/ANUcybernetics/nerves_system_rpi5_audio
- Based on: nerves_system_rpi5 v0.6.4

**Buildroot config changes (nerves_defconfig):**
- Added `BR2_PACKAGE_ALSA_UTILS_ARECORD=y` (audio recording)
- Added `BR2_PACKAGE_ALSA_UTILS_AMIDI=y` (MIDI utilities)
- Enabled `BR2_PACKAGE_ALSA_LIB_RAWMIDI=y` (raw MIDI support)
- Enabled `BR2_PACKAGE_ALSA_LIB_SEQ=y` (MIDI sequencer)

**Kernel config changes (linux-6.12.defconfig):**
- Added `CONFIG_SND_USB=m` (USB audio support)
- Added `CONFIG_SND_USB_AUDIO=m` (USB audio driver)

**Main project repository:**
- Repository: https://github.com/ANUcybernetics/hendrix-homeostat
- Updated mix.exs to use custom system with `nerves: [compile: true]`

**To continue on Ubuntu:**
```bash
git clone https://github.com/ANUcybernetics/hendrix-homeostat.git
cd hendrix-homeostat
export MIX_TARGET=rpi5
mix deps.get
tmux new -s nerves-build
mix firmware
```

**After firmware builds:**
- Firmware will be at: `_build/rpi5_dev/nerves/images/hendrix_homeostat.fw`
- Burn to SD card with: `mix burn` (or transfer .fw file to Mac for burning)
- Insert SD card into Pi 5, boot, and test with `lsusb`, `aplay -l`, `arecord -l`, `amidi -l`

**Known limitations:**
- Presonus vendor-specific features won't work (StudioLive mode, UC Surface, DSP)
- Device will operate as class-compliant USB audio/MIDI interface only
<!-- SECTION:PLAN:END -->
