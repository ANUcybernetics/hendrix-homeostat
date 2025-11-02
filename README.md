# Hendrix homeostat

A _Cybernetic Studio_ project.

An audio cybernetic system inspired by W. Ross Ashby's homeostat (1948), using a
hollowbody electric-acoustic guitar, effects pedal, loudspeaker, and Raspberry
Pi control system to create a self-regulating feedback loop.

## Overview

This is a [Nerves](https://nerves-project.org/) embedded systems project built
with Elixir, targeting Raspberry Pi 5 hardware. The firmware runs a custom OTP
application that interfaces with audio hardware to monitor and control a guitar
feedback loop system.

The guitar's pickup(s) captures resonating body vibrations caused by loudspeaker
output, routes the signal through an effects pedal, and back to the
loudspeaker---creating a feedback loop. The Raspberry Pi monitors the audio
signal and controls the RC-600 loop station tracks to maintain dynamic equilibrium.

**Note**: This project requires a custom Nerves system with ALSA audio support.
See [nerves_system_rpi5_audio](https://github.com/ANUcybernetics/nerves_system_rpi5_audio)
for the modified Nerves system that enables audio capture on Raspberry Pi 5.

## Conceptual mapping to Ashby's homeostat

| Ashby's Homeostat          | Audio System                                               |
| -------------------------- | ---------------------------------------------------------- |
| Magnetic needle position   | Audio RMS level                                            |
| Essential variable bounds  | Critical thresholds (0.05 < RMS < 0.8)                     |
| First-order feedback       | Start/stop/clear tracks to maintain RMS bounds             |
| Uniselector switching      | Random parameter changes (volume, speed)                   |
| Second-order adaptation    | Finding parameter configurations that achieve equilibrium  |
| Ultrastability             | System reconfigures itself when first-order control fails  |

## Control algorithm: Ashby-style ultrastability

This system implements a **double feedback loop** faithful to Ashby's original design:

### First-order loop (homeostasis)

Maintains RMS audio level within bounds by controlling tracks 1-2:

```
Critical high (≥0.8) ──→ Stop random track (damping)

Comfort zone (0.2-0.5) ──→ Stable operation / anti-stasis check

Critical low (≤0.05) ──→ Start recording (excitation)
```

**Track actions:**
- **Too quiet (RMS ≤ 0.05)**: Start recording on track 1 or 2
- **Too loud (RMS ≥ 0.8)**: Stop track 1 or 2
- **Too stable (30s, variance <0.02)**: Clear track 1 or 2 (anti-stasis)

### Second-order loop (ultrastability)

When first-order control fails to stabilize (>10 oscillations between critical
thresholds over 60 seconds), the system triggers **parameter reconfiguration**:

**Randomly changes track parameters:**
- Track 1 volume: {25, 50, 75, 100, 127} (5 levels)
- Track 1 speed: {64, 80, 96, 112, 127} (5 levels) - pitch shifting for sonic variety
- Track 2 volume: {25, 50, 75, 100, 127} (5 levels)
- **Configuration space**: 5 × 5 × 5 = 125 combinations

This is analogous to Ashby's uniselector mechanism, which randomly changed
circuit parameters until finding a stable configuration. The system performs
**trial-and-error learning** by exploring the parameter space.

### Why it works

- **Negative feedback**: Maintains essential variable (RMS) within bounds
- **Parameter adaptation**: Searches for configurations that enable stability
- **Emergent behavior**: System discovers equilibrium rather than following
  pre-programmed setpoints
- **Requisite variety**: Random parameter selection provides variety to match
  environmental disturbances

## Audio behaviour goals

1. **Dynamic equilibrium**: system seeks balance but never stasis
2. **Sonic variety**: track configurations change based on both necessity and boredom
3. **Self-organisation**: system finds its own stable loop configurations
4. **Resilience**: recovers from both silence and overload

## Hardware

- Boss Katana Gen3 100w combo amp
- Boss RC-600 loop station pedal
- hollowbody electric-acoustic guitar (e.g. Gretsch, Gibson ES series)
- Raspberry Pi 5 with audio in (from guitar pickup) and MIDI out (to control
  RC-600 track recording/playback)
- Presonus Revelator io24 (USB audio/MIDI interface)

## Hardware setup notes

1. **Gain staging**: critical to prevent runaway feedback or silence
2. **Guitar placement**: distance and angle from speaker affects resonance
   characteristics
3. **Effects send/return**: use pre-fader send if available
4. **Ground loops**: use isolated interfaces if getting hum
5. **Guitar damping**: partial muting/damping of strings affects feedback
   behaviour

### RC-600 MIDI configuration

The RC-600 must be configured to receive MIDI control from the Raspberry Pi. On the RC-600, configure ASSIGN mappings (Menu → ASSIGN):

**Essential mappings (tracks 1-2 for ultrastable control):**
- ASSIGN1-2: CC#1-2 → TRK1-2 REC/PLY (TOGGLE mode)
- ASSIGN7-8: CC#11-12 → TRK1-2 STOP (TOGGLE mode)
- ASSIGN13-14: CC#21-22 → TRK1-2 CLEAR (TOGGLE mode)
- ASSIGN15-16: CC#30,32 → TRK1-2 LEVEL (CONTINUOUS mode)
- ASSIGN17: CC#31 → TRK1 SPEED (CONTINUOUS mode, if available)

**Optional mappings (tracks 3-6 for manual control):**
- ASSIGN3-6: CC#3-6 → TRK3-6 REC/PLY (TOGGLE mode)
- ASSIGN9-12: CC#13-16 → TRK3-6 STOP (TOGGLE mode)

**RC-600 MIDI settings:**
- RX CH CTL: 1 (or match channel in `config/runtime.exs`)
- CLOCK SYNC: MIDI or AUTO (if syncing to external clock)

The complete MIDI CC mapping is defined in `config/runtime.exs`. If the RC-600 doesn't support per-track SPEED control via ASSIGN, substitute with an alternative parameter (FX level, pan, etc.) for Track 1.

## Getting started

To start your Nerves app:

- `export MIX_TARGET=my_target` or prefix every command with
  `MIX_TARGET=my_target`. For example, `MIX_TARGET=rpi5`
- Install dependencies with `mix deps.get`
- Create firmware with `mix firmware`
- Burn to an SD card with `mix burn`

## References

- Ashby, W. R. (1960). _Design for a Brain: The Origin of Adaptive Behaviour_
- Ashby, W. R. (1948). "Design for a brain". _Electronic Engineering_, 20,
  379-383
- Pickering, A. (2010). _The Cybernetic Brain: Sketches of Another Future_

## Licence

Copyright (c) 2025 Ben Swift

Licensed under the MIT License. See LICENSE file for details.
