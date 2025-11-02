# RC-600 MIDI setup for homeostat control

This document describes the MIDI CC mapping between the homeostat and the Boss RC-600 loop station.

## Control philosophy

The homeostat implements Ashby-style ultrastability with a double feedback loop:

**First-order control (homeostasis):**
- **Starting recording** on tracks 1-2 when RMS too low (≤0.05)
- **Stopping tracks** 1-2 when RMS too high (≥0.8)
- **Clearing tracks** 1-2 when stable for too long (anti-stasis)

**Second-order control (ultrastability):**
- When the system oscillates excessively (>10 critical crossings in 100 samples
  over 60 seconds), it randomly changes track volume and speed parameters
- This searches through ~125 configurations to find one that achieves equilibrium
- Like Ashby's original homeostat uniselector mechanism

## RC-600 ASSIGN configuration

You must configure the following ASSIGN mappings on the RC-600 (Menu → ASSIGN):

### Track rec/play/overdub (6 assigns)

- **ASSIGN1**: Source = MIDI CC#1, Target = TRK1 REC/PLY, Source Mode = TOGGLE
- **ASSIGN2**: Source = MIDI CC#2, Target = TRK2 REC/PLY, Source Mode = TOGGLE
- **ASSIGN3**: Source = MIDI CC#3, Target = TRK3 REC/PLY, Source Mode = TOGGLE
- **ASSIGN4**: Source = MIDI CC#4, Target = TRK4 REC/PLY, Source Mode = TOGGLE
- **ASSIGN5**: Source = MIDI CC#5, Target = TRK5 REC/PLY, Source Mode = TOGGLE
- **ASSIGN6**: Source = MIDI CC#6, Target = TRK6 REC/PLY, Source Mode = TOGGLE

### Track stop (6 assigns)

- **ASSIGN7**: Source = MIDI CC#11, Target = TRK1 STOP, Source Mode = TOGGLE
- **ASSIGN8**: Source = MIDI CC#12, Target = TRK2 STOP, Source Mode = TOGGLE
- **ASSIGN9**: Source = MIDI CC#13, Target = TRK3 STOP, Source Mode = TOGGLE
- **ASSIGN10**: Source = MIDI CC#14, Target = TRK4 STOP, Source Mode = TOGGLE
- **ASSIGN11**: Source = MIDI CC#15, Target = TRK5 STOP, Source Mode = TOGGLE
- **ASSIGN12**: Source = MIDI CC#16, Target = TRK6 STOP, Source Mode = TOGGLE

### Track clear (2 assigns)

- **ASSIGN13**: Source = MIDI CC#21, Target = TRK1 CLEAR, Source Mode = TOGGLE
- **ASSIGN14**: Source = MIDI CC#22, Target = TRK2 CLEAR, Source Mode = TOGGLE

### Track volume (ultrastable parameter - 2 assigns)

- **ASSIGN15**: Source = MIDI CC#30, Target = TRK1 LEVEL, Source Mode = CONTINUOUS
- **ASSIGN16**: Source = MIDI CC#32, Target = TRK2 LEVEL, Source Mode = CONTINUOUS

### Track 1 speed (ultrastable parameter - 1 assign, if supported by RC-600)

- **ASSIGN17**: Source = MIDI CC#31, Target = TRK1 SPEED, Source Mode = CONTINUOUS

Note: Only Track 1 has speed control for sonic variety. Track 2 uses volume only.
The RC-600 may not support per-track speed control via ASSIGN. If not available,
you can use alternative parameters like FX level or pan for Track 1.

## MIDI configuration

Ensure the RC-600 MIDI settings are:
- **RX CH CTL**: 1 (or match the channel in config/runtime.exs)
- **CLOCK SYNC**: MIDI or AUTO (if syncing to external clock)

## CC mapping reference

The mapping is defined in `config/runtime.exs` under `:rc600_cc_map`:

```elixir
rc600_cc_map: [
  # First-order control (track start/stop/clear)
  track1_rec_play: 1,
  track2_rec_play: 2,
  track3_rec_play: 3,
  track4_rec_play: 4,
  track5_rec_play: 5,
  track6_rec_play: 6,
  track1_stop: 11,
  track2_stop: 12,
  track3_stop: 13,
  track4_stop: 14,
  track5_stop: 15,
  track6_stop: 16,
  track1_clear: 21,
  track2_clear: 22,
  track3_clear: 23,
  track4_clear: 24,
  # Second-order control (ultrastable parameters)
  track1_volume: 30,
  track1_speed: 31,
  track2_volume: 32
]
```

## Homeostat behavior

### First-order loop (homeostasis)

**When RMS too quiet (≤0.05):**
- Start recording on track 1 or 2
- Sends CC#1 or CC#2 with value 127

**When RMS too loud (≥0.8):**
- Stop track 1 or 2
- Sends CC#11 or CC#12 with value 127

**When stable too long (30 seconds, variance <0.02):**
- Clear track 1 or 2 to prevent stasis
- Sends CC#21 or CC#22 with value 127

### Second-order loop (ultrastability)

**When system oscillating (>10 critical crossings in 100 samples over 60s):**
- Randomly change track 1 volume: CC#30 with value ∈ {25, 50, 75, 100, 127}
- Randomly change track 1 speed: CC#31 with value ∈ {64, 80, 96, 112, 127}
- Randomly change track 2 volume: CC#32 with value ∈ {25, 50, 75, 100, 127}
- This searches through 125 possible configurations to find equilibrium
- Track 1 becomes the "experimental" track with pitch shifting, Track 2 is the "anchor"

## Overdubbing Behavior

The system **embraces overdubbing** as part of its emergent complexity:

- When `start_recording` is called on a **playing** track, it will **overdub** new material
- This creates evolving textures: sparse → dense → sparse cycles
- When a track repeatedly causes critical_high (5 times in a row), it gets **cleared** instead of stopped
- This prevents tracks from becoming infinitely dense and muddy
- The result is natural sonic cycles driven by the homeostat's adaptive behavior

## Notes

- The system primarily controls tracks 1-2 (ultrastable control)
- Tracks 3-6 can still be manually controlled or left for future expansion
- First-order controls (rec/play/stop/clear) use TOGGLE mode with value 127
- Second-order controls (volume/speed) use CONTINUOUS mode with variable values
- Total ASSIGN slots needed: 15 (fits comfortably in RC-600's 16 limit)
- Track 1 has both volume and speed control (for sonic variety)
- Track 2 has volume control only (functional asymmetry aids stability)
