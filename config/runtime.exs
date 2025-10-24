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
    patch_banks: [
      boost_bank: [1, 2, 3, 4, 5],
      dampen_bank: [10, 11, 12, 13, 14],
      random_bank: [20, 21, 22, 23, 24, 25, 26, 27, 28, 29]
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
      device_name: "/dev/snd/midiC0D0",
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
    patch_banks: [
      boost_bank: [1, 2, 3, 4, 5],
      dampen_bank: [10, 11, 12, 13, 14],
      random_bank: [20, 21, 22, 23, 24, 25, 26, 27, 28, 29]
    ],
    backends: [
      midi_backend: HendrixHomeostat.MidiBackend.Amidi,
      audio_backend: HendrixHomeostat.AudioBackend.Port
    ]
end
