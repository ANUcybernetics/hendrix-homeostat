import Config

target = System.get_env("MIX_TARGET", "host")

config :hendrix_homeostat,
  target: String.to_atom(target)

if target == "host" do
  config :hendrix_homeostat,
    midi_enabled: false,
    audio_enabled: false,
    audio: [
      sample_rate: 48000,
      buffer_size: 4800,
      device_name: "test.wav",
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
      device_name: "hw:2,0",
      update_rate: 10
    ],
    midi: [
      device_name: "/dev/midi1",
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
