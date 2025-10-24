# Hendrix Homeostat configuration

This document describes the configuration options for the Hendrix Homeostat system.

## Configuration file

All configuration is in `config/runtime.exs`. The configuration adapts based on the `MIX_TARGET` environment variable:

- `MIX_TARGET=host` (or unset): development/testing configuration
- `MIX_TARGET=rpi5`: production configuration for Raspberry Pi 5 hardware

## Configuration sections

### Audio configuration

Audio analysis parameters for monitoring the feedback loop.

- **sample_rate** (integer, default: 48000): Audio sample rate in Hz. Must match the audio interface's sample rate.

- **buffer_size** (integer, default: 4800): Number of samples per analysis buffer. At 48kHz, 4800 samples = 100ms, giving an update rate of 10Hz.

- **device_name** (string):
  - Host target: path to a WAV file for testing (e.g., "test.wav")
  - RPi5 target: ALSA device identifier (e.g., "hw:2,0" for Presonus Revelator io24)

- **update_rate** (integer, default: 10): Analysis update frequency in Hz. Should match buffer_size/sample_rate.

### MIDI configuration

MIDI output settings for controlling the Boss RC-600 loop station.

- **device_name** (string):
  - Host target: dummy device name for testing (e.g., "test_midi")
  - RPi5 target: MIDI device path (e.g., "/dev/midi1")

- **channel** (integer, default: 1): MIDI channel number. Valid range: 1-16.

### Control thresholds

Threshold values for the homeostat's decision-making logic. All thresholds are normalized RMS level values (0.0-1.0).

- **critical_high** (float, default: 0.8): Upper threshold. When RMS exceeds this, system applies dampen patches.

- **comfort_zone_max** (float, default: 0.5): Upper bound of comfort zone. No action taken within comfort zone.

- **comfort_zone_min** (float, default: 0.2): Lower bound of comfort zone.

- **critical_low** (float, default: 0.05): Lower threshold. When RMS falls below this, system applies boost patches.

- **stability_threshold** (float, default: 0.02): RMS variance threshold. If variance stays below this for stability_duration, the anti-stasis mechanism triggers.

- **stability_duration** (integer, default: 30000): Time in milliseconds that the system must be stable before triggering perturbation.

**Validation**: The configuration system ensures: critical_low < comfort_zone_min < comfort_zone_max < critical_high

### RC-600 CC mapping

MIDI Control Change numbers for controlling RC-600 loop station tracks. These map to ASSIGN settings configured on the RC-600 hardware.

See `RC600_SETUP.md` for complete configuration instructions.

- **track1_rec_play** through **track6_rec_play** (integers, CC#1-6): Control Change numbers to trigger recording/playback/overdub on each track.

- **track1_stop** through **track6_stop** (integers, CC#11-16): Control Change numbers to stop each track.

- **track1_clear** through **track4_clear** (integers, CC#21-24): Control Change numbers to clear/erase each track.

All CC numbers must be in the valid range supported by RC-600 ASSIGN: 1-31 or 64-95.

### Backend selection

Module names for pluggable backend implementations. Allows testing on host without hardware.

- **midi_backend** (module atom):
  - Host target: `HendrixHomeostat.MidiBackend.InMemory` (logs MIDI commands)
  - RPi5 target: `HendrixHomeostat.MidiBackend.Amidi` (sends actual MIDI via amidi)

- **audio_backend** (module atom):
  - Host target: `HendrixHomeostat.AudioBackend.File` (reads from WAV file)
  - RPi5 target: `HendrixHomeostat.AudioBackend.Port` (reads from ALSA via Port)

## Configuration validation

Configuration is validated at application startup in `HendrixHomeostat.Application.start/2`. The validation ensures:

1. All required configuration keys are present
2. Values have correct types (integers, floats, strings, atoms)
3. Numeric values are within valid ranges
4. Threshold relationships are logically consistent
5. RC-600 CC numbers are in valid range (1-31 or 64-95)
6. MIDI channel is in valid range (1-16)

If validation fails, the application will not start and will raise an error describing the problem.

## Accessing configuration

Configuration values should be accessed using `Application.fetch_env!/2`:

```elixir
audio_config = Application.fetch_env!(:hendrix_homeostat, :audio)
sample_rate = Keyword.fetch!(audio_config, :sample_rate)
```

This pattern ensures configuration is read at runtime, not compile time, which is essential for Nerves compatibility.

## Customizing configuration

To customize configuration values:

1. Edit `config/runtime.exs`
2. Update the appropriate section (host or rpi5 target)
3. Recompile: `mix compile`
4. For hardware deployment: `mix firmware` and `mix burn`

All configuration values have sensible defaults that allow the system to run without modification.
