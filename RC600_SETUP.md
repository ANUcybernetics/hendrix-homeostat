# RC-600 MIDI setup for homeostat control

This document describes the MIDI CC mapping between the homeostat and the Boss RC-600 loop station.

## Control philosophy

The homeostat controls the RC-600 entirely via MIDI CC messages. There is no manual intervention. The algorithm seeks equilibrium by:

- **Starting recording** on tracks when the system is too quiet
- **Stopping tracks** when the system is too loud
- **Clearing tracks** when the system is stable for too long (anti-stasis)

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

### Track clear (4 assigns)

- **ASSIGN13**: Source = MIDI CC#21, Target = TRK1 CLEAR, Source Mode = TOGGLE
- **ASSIGN14**: Source = MIDI CC#22, Target = TRK2 CLEAR, Source Mode = TOGGLE
- **ASSIGN15**: Source = MIDI CC#23, Target = TRK3 CLEAR, Source Mode = TOGGLE
- **ASSIGN16**: Source = MIDI CC#24, Target = TRK4 CLEAR, Source Mode = TOGGLE

## MIDI configuration

Ensure the RC-600 MIDI settings are:
- **RX CH CTL**: 1 (or match the channel in config/runtime.exs)
- **CLOCK SYNC**: MIDI or AUTO (if syncing to external clock)

## CC mapping reference

The mapping is defined in `config/runtime.exs` under `:rc600_cc_map`:

```elixir
rc600_cc_map: [
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
  track4_clear: 24
]
```

## Homeostat behavior

### When RMS too quiet (critical_low)
- Start recording on an empty track
- Sends CC#1-6 with value 127

### When RMS too loud (critical_high)
- Stop a playing track
- Sends CC#11-16 with value 127

### When stable too long (anti-stasis)
- Clear a random track to force system rebuild
- Sends CC#21-24 with value 127

## Notes

- The RC-600 has 16 ASSIGN slots total, this configuration uses all 16
- Track clear is only mapped for tracks 1-4 to save ASSIGN slots
- All controls use TOGGLE mode since they are triggered by discrete events
- CC values sent are always 127 (max) since these are on/off controls
