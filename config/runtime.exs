import Config

# At runtime, MIX_TARGET isn't set. We need to detect if we're on real hardware.
# On Nerves devices, Mix.target/0 returns the actual target.
# During development/test on host, it returns :host.
target =
  if Code.ensure_loaded?(Mix) and function_exported?(Mix, :target, 0) do
    Mix.target()
  else
    # Fallback: check if we're in a Nerves runtime environment
    if Code.ensure_loaded?(Nerves.Runtime) do
      :rpi5
    else
      :host
    end
  end

config :hendrix_homeostat,
  target: target

if target == :host do
  config :hendrix_homeostat,
    midi_enabled: false,
    audio_enabled: false,
    audio: [
      sample_rate: 48000,
      buffer_size: 4800,
      device_name: "test/fixtures/test.wav",
      update_rate: 10
    ],
    midi: [
      device_name: "test_midi",
      channel: 1
    ],
    control: [
      critical_high: 0.8,
      comfort_zone_min: 0.2,
      comfort_zone_max: 0.5,
      critical_low: 0.05,
      stability_threshold: 0.02,
      stability_duration: 30_000
    ],
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
    ],
    backends: [
      midi_backend: HendrixHomeostat.MidiBackend.InMemory,
      audio_backend: HendrixHomeostat.AudioBackend.File
    ]
else
  config :hendrix_homeostat,
    midi_enabled: true,
    audio_enabled: true,
    audio: [
      sample_rate: 48000,
      buffer_size: 4800,
      device_name: "hw:0,0",
      update_rate: 10,
      format: "S32_LE",
      channels: 6
    ],
    midi: [
      device_name: "hw:0,0,0",
      channel: 1
    ],
    control: [
      critical_high: 0.8,
      comfort_zone_min: 0.2,
      comfort_zone_max: 0.5,
      critical_low: 0.05,
      stability_threshold: 0.02,
      stability_duration: 30_000
    ],
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
    ],
    backends: [
      midi_backend: HendrixHomeostat.MidiBackend.Amidi,
      audio_backend: HendrixHomeostat.AudioBackend.Port
    ]
end
