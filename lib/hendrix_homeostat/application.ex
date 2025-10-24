defmodule HendrixHomeostat.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    validate_config!()

    children = [
      {HendrixHomeostat.MidiController, []},
      {HendrixHomeostat.AudioMonitor, []},
      {HendrixHomeostat.ControlLoop, []}
    ]

    opts = [strategy: :one_for_one, name: HendrixHomeostat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp validate_config! do
    validate_audio_config!()
    validate_midi_config!()
    validate_control_config!()
    validate_rc600_cc_map_config!()
    validate_backends_config!()
  end

  defp validate_audio_config! do
    audio = Application.fetch_env!(:hendrix_homeostat, :audio)

    unless Keyword.keyword?(audio) do
      raise "audio configuration must be a keyword list"
    end

    sample_rate = Keyword.fetch!(audio, :sample_rate)
    buffer_size = Keyword.fetch!(audio, :buffer_size)
    device_name = Keyword.fetch!(audio, :device_name)
    update_rate = Keyword.fetch!(audio, :update_rate)

    unless is_integer(sample_rate) and sample_rate > 0 do
      raise "audio.sample_rate must be a positive integer"
    end

    unless is_integer(buffer_size) and buffer_size > 0 do
      raise "audio.buffer_size must be a positive integer"
    end

    unless is_binary(device_name) do
      raise "audio.device_name must be a string"
    end

    unless is_integer(update_rate) and update_rate > 0 do
      raise "audio.update_rate must be a positive integer"
    end
  end

  defp validate_midi_config! do
    midi = Application.fetch_env!(:hendrix_homeostat, :midi)

    unless Keyword.keyword?(midi) do
      raise "midi configuration must be a keyword list"
    end

    device_name = Keyword.fetch!(midi, :device_name)
    channel = Keyword.fetch!(midi, :channel)

    unless is_binary(device_name) do
      raise "midi.device_name must be a string"
    end

    unless is_integer(channel) and channel >= 1 and channel <= 16 do
      raise "midi.channel must be an integer between 1 and 16"
    end
  end

  defp validate_control_config! do
    control = Application.fetch_env!(:hendrix_homeostat, :control)

    unless Keyword.keyword?(control) do
      raise "control configuration must be a keyword list"
    end

    critical_high = Keyword.fetch!(control, :critical_high)
    comfort_zone_min = Keyword.fetch!(control, :comfort_zone_min)
    comfort_zone_max = Keyword.fetch!(control, :comfort_zone_max)
    critical_low = Keyword.fetch!(control, :critical_low)
    stability_threshold = Keyword.fetch!(control, :stability_threshold)
    stability_duration = Keyword.fetch!(control, :stability_duration)

    validate_threshold!(:critical_high, critical_high)
    validate_threshold!(:comfort_zone_min, comfort_zone_min)
    validate_threshold!(:comfort_zone_max, comfort_zone_max)
    validate_threshold!(:critical_low, critical_low)
    validate_threshold!(:stability_threshold, stability_threshold)

    unless is_integer(stability_duration) and stability_duration > 0 do
      raise "control.stability_duration must be a positive integer (milliseconds)"
    end

    unless critical_low < comfort_zone_min do
      raise "control.critical_low must be less than control.comfort_zone_min"
    end

    unless comfort_zone_min < comfort_zone_max do
      raise "control.comfort_zone_min must be less than control.comfort_zone_max"
    end

    unless comfort_zone_max < critical_high do
      raise "control.comfort_zone_max must be less than control.critical_high"
    end
  end

  defp validate_threshold!(name, value) do
    unless is_float(value) and value >= 0.0 and value <= 1.0 do
      raise "control.#{name} must be a float between 0.0 and 1.0"
    end
  end

  defp validate_rc600_cc_map_config! do
    cc_map = Application.fetch_env!(:hendrix_homeostat, :rc600_cc_map)

    unless Keyword.keyword?(cc_map) do
      raise "rc600_cc_map configuration must be a keyword list"
    end

    for track <- 1..6 do
      rec_play_key = String.to_atom("track#{track}_rec_play")
      stop_key = String.to_atom("track#{track}_stop")

      rec_play_cc = Keyword.fetch!(cc_map, rec_play_key)
      stop_cc = Keyword.fetch!(cc_map, stop_key)

      validate_cc_number!(rec_play_key, rec_play_cc)
      validate_cc_number!(stop_key, stop_cc)
    end

    for track <- 1..4 do
      clear_key = String.to_atom("track#{track}_clear")
      clear_cc = Keyword.fetch!(cc_map, clear_key)
      validate_cc_number!(clear_key, clear_cc)
    end
  end

  defp validate_cc_number!(name, value) do
    unless is_integer(value) and ((value >= 1 and value <= 31) or (value >= 64 and value <= 95)) do
      raise "rc600_cc_map.#{name} must be an integer in range 1-31 or 64-95"
    end
  end

  defp validate_backends_config! do
    backends = Application.fetch_env!(:hendrix_homeostat, :backends)

    unless Keyword.keyword?(backends) do
      raise "backends configuration must be a keyword list"
    end

    midi_backend = Keyword.fetch!(backends, :midi_backend)
    audio_backend = Keyword.fetch!(backends, :audio_backend)

    unless is_atom(midi_backend) do
      raise "backends.midi_backend must be a module name (atom)"
    end

    unless is_atom(audio_backend) do
      raise "backends.audio_backend must be a module name (atom)"
    end
  end
end
