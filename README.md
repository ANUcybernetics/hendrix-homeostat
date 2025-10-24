# Hendrix homeostat

A _Cybernetic Studio_ project.

An audio cybernetic system inspired by W. Ross Ashby's homeostat (1948), using a
hollowbody electric-acoustic guitar, effects pedal, loudspeaker, and Raspberry
Pi control system to create a self-regulating feedback loop.

## Overview

The guitar's pickup(s) captures resonating body vibrations caused by loudspeaker
output, routes the signal through an effects pedal, and back to the
loudspeaker---creating a feedback loop. The Raspberry Pi monitors the audio
signal and controls the RC-600 loop station tracks to maintain dynamic equilibrium.

## Conceptual mapping to Ashby's homeostat

| Homeostat             | Audio system                                               |
| --------------------- | ---------------------------------------------------------- |
| Needle position       | Audio signal level/characteristics                         |
| Uniselector switching | Track recording/stopping/clearing                          |
| Stability seeking     | Maintaining target sonic characteristics                   |
| Ultrastability        | Finding track configurations that keep system "alive" but not blown out |

## Control algorithm

### Core principles

1. **Primary adaptation**: continuous monitoring of audio metrics
2. **Secondary adaptation**: discrete track control actions when hitting limits
3. **Anti-stasis**: deliberate perturbation when system becomes too stable

### Key metrics to monitor

- **RMS level**: primary measure of signal energy
- **Spectral centroid**: brightness/tonal balance
- **Stability**: standard deviation of recent measurements

### Threshold zones

```
Critical high (>0.8) ──┐
                       ├── Stop playing tracks
Comfort zone (0.2-0.5) ──── Stable operation
                       ├── Start recording on tracks
Critical low (<0.05) ──┘
```

### Track control strategies

1. **Too quiet**: start recording on empty tracks to build up material
2. **Too loud**: stop playing tracks to reduce feedback
3. **Too stable**: clear random tracks to force system rebuild and perturbation

The RC-600 loop station provides 6 independent tracks, allowing the homeostat to
layer and remove loops dynamically via MIDI CC messages.

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
