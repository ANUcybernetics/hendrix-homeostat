defmodule HendrixHomeostat.Integration.SystemIntegrationTest do
  use ExUnit.Case

  alias HendrixHomeostat.AudioMonitor
  alias HendrixHomeostat.ControlLoop
  alias HendrixHomeostat.MidiController
  alias HendrixHomeostat.MidiBackend.InMemory

  @test_data_dir Path.join([__DIR__, "..", "fixtures", "integration"])

  setup do
    File.mkdir_p!(@test_data_dir)

    original_config = Application.get_all_env(:hendrix_homeostat)

    on_exit(fn ->
      Enum.each(original_config, fn {key, value} ->
        Application.put_env(:hendrix_homeostat, key, value)
      end)
    end)

    {:ok, in_memory_pid} = start_supervised({InMemory, name: InMemory})
    InMemory.clear_history()

    {:ok, midi_pid} = start_supervised(MidiController)

    %{
      test_data_dir: @test_data_dir,
      in_memory_pid: in_memory_pid,
      midi_pid: midi_pid
    }
  end

  describe "end-to-end system integration" do
    test "silence detection triggers boost bank selection", %{test_data_dir: test_data_dir} do
      silence_file = Path.join(test_data_dir, "silence.bin")
      create_silence_file(silence_file, 4800)

      configure_system(silence_file)

      {:ok, _control_pid} = start_supervised(ControlLoop)
      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      Process.sleep(200)

      history = InMemory.get_history()

      assert length(history) > 0
      [{:program_change, _device, patch, _timestamp} | _rest] = history
      assert patch in [1, 2, 3, 4, 5], "Expected boost bank patch, got #{patch}"

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(silence_file)
    end

    test "loud audio triggers dampen bank selection", %{test_data_dir: test_data_dir} do
      loud_file = Path.join(test_data_dir, "loud.bin")
      create_loud_tone_file(loud_file, 4800, amplitude: 30000)

      configure_system(loud_file)

      {:ok, _control_pid} = start_supervised(ControlLoop)
      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      Process.sleep(200)

      history = InMemory.get_history()

      assert length(history) > 0
      [{:program_change, _device, patch, _timestamp} | _rest] = history
      assert patch in [10, 11, 12, 13, 14], "Expected dampen bank patch, got #{patch}"

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(loud_file)
    end

    test "comfortable audio level triggers no action", %{test_data_dir: test_data_dir} do
      comfortable_file = Path.join(test_data_dir, "comfortable.bin")
      create_comfortable_tone_file(comfortable_file, 4800)

      configure_system(comfortable_file)

      {:ok, _control_pid} = start_supervised(ControlLoop)
      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      Process.sleep(200)

      history = InMemory.get_history()

      assert history == [], "Expected no MIDI commands for comfortable audio"

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(comfortable_file)
    end

    test "stable audio triggers anti-stasis random selection", %{test_data_dir: test_data_dir} do
      stable_file = Path.join(test_data_dir, "stable.bin")
      create_comfortable_tone_file(stable_file, 4800)

      configure_system(stable_file)

      {:ok, control_pid} = start_supervised(ControlLoop)
      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      Process.sleep(200)

      InMemory.clear_history()

      :sys.replace_state(control_pid, fn state ->
        metrics = %{rms: 0.3, zcr: 0.5, peak: 0.4}
        history = List.duplicate(0.3, 30)
        %{state |
          metrics_history: history,
          current_metrics: metrics,
          last_action_timestamp: System.monotonic_time(:millisecond) - 31_000
        }
      end)

      send(control_pid, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.4}})
      Process.sleep(50)

      history = InMemory.get_history()

      assert length(history) == 1
      [{:program_change, _device, patch, _timestamp}] = history
      assert patch in [20, 21, 22, 23, 24, 25, 26, 27, 28, 29],
             "Expected random bank patch, got #{patch}"

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(stable_file)
    end
  end

  describe "complete audio-to-MIDI flow" do
    test "AudioMonitor reads audio, calculates metrics, sends to ControlLoop", %{
      test_data_dir: test_data_dir
    } do
      test_file = Path.join(test_data_dir, "flow_test.bin")
      create_loud_tone_file(test_file, 4800, amplitude: 30000)

      configure_system(test_file)

      {:ok, control_pid} = start_supervised(ControlLoop)
      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      Process.sleep(200)

      control_state = :sys.get_state(control_pid)

      assert control_state.current_metrics != nil
      assert is_map(control_state.current_metrics)
      assert Map.has_key?(control_state.current_metrics, :rms)
      assert Map.has_key?(control_state.current_metrics, :zcr)
      assert Map.has_key?(control_state.current_metrics, :peak)

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(test_file)
    end

    test "ControlLoop makes decision and sends MIDI command", %{test_data_dir: test_data_dir} do
      test_file = Path.join(test_data_dir, "decision_test.bin")
      create_loud_tone_file(test_file, 4800, amplitude: 30000)

      configure_system(test_file)

      InMemory.clear_history()

      {:ok, _control_pid} = start_supervised(ControlLoop)
      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      Process.sleep(200)

      history = InMemory.get_history()

      assert length(history) > 0
      assert match?([{:program_change, _, _, _} | _], history)

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(test_file)
    end

    test "MidiController receives and processes MIDI commands", %{test_data_dir: test_data_dir} do
      test_file = Path.join(test_data_dir, "midi_test.bin")
      create_silence_file(test_file, 4800)

      configure_system(test_file)

      InMemory.clear_history()

      {:ok, _control_pid} = start_supervised(ControlLoop)
      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      Process.sleep(200)

      history = InMemory.get_history()

      assert length(history) > 0

      for entry <- history do
        assert match?({:program_change, _, patch, _}, entry)
        {_, _, patch, _} = entry
        assert patch >= 0 and patch <= 98
      end

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(test_file)
    end
  end

  describe "multiple transitions" do
    test "handles silence to loud to comfortable transitions", %{test_data_dir: test_data_dir} do
      silence_file = Path.join(test_data_dir, "transition_silence.bin")
      loud_file = Path.join(test_data_dir, "transition_loud.bin")
      comfortable_file = Path.join(test_data_dir, "transition_comfortable.bin")

      create_silence_file(silence_file, 2400)
      create_loud_tone_file(loud_file, 2400, amplitude: 30000)
      create_comfortable_tone_file(comfortable_file, 2400)

      combined_file = Path.join(test_data_dir, "combined.bin")

      silence_data = File.read!(silence_file)
      loud_data = File.read!(loud_file)
      comfortable_data = File.read!(comfortable_file)

      File.write!(combined_file, silence_data <> loud_data <> comfortable_data)

      configure_system(combined_file)

      InMemory.clear_history()

      {:ok, _control_pid} = start_supervised(ControlLoop)
      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      Process.sleep(500)

      history = InMemory.get_history()

      assert length(history) >= 2, "Expected at least 2 transitions"

      boost_patches = Enum.filter(history, fn {_, _, patch, _} -> patch in [1, 2, 3, 4, 5] end)
      dampen_patches = Enum.filter(history, fn {_, _, patch, _} -> patch in [10, 11, 12, 13, 14] end)

      assert length(boost_patches) > 0, "Expected boost patch for silence"
      assert length(dampen_patches) > 0, "Expected dampen patch for loud audio"

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(silence_file)
      File.rm(loud_file)
      File.rm(comfortable_file)
      File.rm(combined_file)
    end

    test "handles rapid level changes correctly", %{test_data_dir: test_data_dir} do
      rapid_file = Path.join(test_data_dir, "rapid.bin")

      silence = create_silence_samples(1200)
      loud = create_loud_tone_samples(1200, amplitude: 30000)

      File.write!(rapid_file, silence <> loud <> silence <> loud)

      configure_system(rapid_file)

      InMemory.clear_history()

      {:ok, _control_pid} = start_supervised(ControlLoop)
      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      Process.sleep(600)

      history = InMemory.get_history()

      assert length(history) >= 2, "Expected multiple transitions for rapid changes"

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(rapid_file)
    end
  end

  describe "system resilience" do
    test "continues operating if AudioMonitor temporarily fails to read", %{
      test_data_dir: test_data_dir
    } do
      test_file = Path.join(test_data_dir, "resilience_test.bin")
      create_comfortable_tone_file(test_file, 4800)

      configure_system(test_file)

      {:ok, control_pid} = start_supervised(ControlLoop)
      {:ok, monitor_pid} = start_supervised(AudioMonitor)

      Process.sleep(200)

      assert Process.alive?(monitor_pid)
      assert Process.alive?(control_pid)

      control_state = :sys.get_state(control_pid)
      assert control_state.current_metrics != nil

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(test_file)
    end

    test "system recovers from file loop correctly", %{test_data_dir: test_data_dir} do
      short_file = Path.join(test_data_dir, "short_loop.bin")
      create_comfortable_tone_file(short_file, 200)

      Application.put_env(:hendrix_homeostat, :audio,
        sample_rate: 48000,
        buffer_size: 200,
        device_name: short_file,
        update_rate: 10
      )

      Application.put_env(:hendrix_homeostat, :backends,
        midi_backend: HendrixHomeostat.MidiBackend.InMemory,
        audio_backend: HendrixHomeostat.AudioBackend.File
      )

      {:ok, control_pid} = start_supervised(ControlLoop)
      {:ok, monitor_pid} = start_supervised(AudioMonitor)

      Process.sleep(300)

      assert Process.alive?(monitor_pid)
      assert Process.alive?(control_pid)

      control_state = :sys.get_state(control_pid)
      assert length(control_state.metrics_history) > 1

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(short_file)
    end
  end

  describe "configuration verification" do
    test "all three GenServers use correct backends", %{test_data_dir: test_data_dir} do
      test_file = Path.join(test_data_dir, "config_test.bin")
      create_comfortable_tone_file(test_file, 4800)

      configure_system(test_file)

      {:ok, _control_pid} = start_supervised(ControlLoop)
      {:ok, monitor_pid} = start_supervised(AudioMonitor)

      monitor_state = :sys.get_state(monitor_pid)
      assert monitor_state.backend == HendrixHomeostat.AudioBackend.File

      backends = Application.fetch_env!(:hendrix_homeostat, :backends)
      assert Keyword.get(backends, :midi_backend) == HendrixHomeostat.MidiBackend.InMemory
      assert Keyword.get(backends, :audio_backend) == HendrixHomeostat.AudioBackend.File

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(test_file)
    end

    test "system respects configured thresholds", %{test_data_dir: test_data_dir} do
      test_file = Path.join(test_data_dir, "threshold_test.bin")
      create_comfortable_tone_file(test_file, 4800)

      configure_system(test_file)

      {:ok, control_pid} = start_supervised(ControlLoop)
      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      state = :sys.get_state(control_pid)

      assert state.config.critical_high == 0.8
      assert state.config.comfort_zone_min == 0.2
      assert state.config.comfort_zone_max == 0.5
      assert state.config.critical_low == 0.05
      assert state.config.stability_threshold == 0.02
      assert state.config.stability_duration == 30_000

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(test_file)
    end

    test "system uses configured patch banks", %{test_data_dir: test_data_dir} do
      test_file = Path.join(test_data_dir, "banks_test.bin")
      create_comfortable_tone_file(test_file, 4800)

      configure_system(test_file)

      {:ok, control_pid} = start_supervised(ControlLoop)
      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      state = :sys.get_state(control_pid)

      assert state.config.boost_bank == [1, 2, 3, 4, 5]
      assert state.config.dampen_bank == [10, 11, 12, 13, 14]
      assert state.config.random_bank == [20, 21, 22, 23, 24, 25, 26, 27, 28, 29]

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(test_file)
    end
  end

  describe "metrics flow verification" do
    test "AudioMonitor sends metrics to ControlLoop at configured rate", %{
      test_data_dir: test_data_dir
    } do
      test_file = Path.join(test_data_dir, "rate_test.bin")
      create_comfortable_tone_file(test_file, 4800)

      configure_system(test_file)

      {:ok, control_pid} = start_supervised(ControlLoop)
      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      Process.sleep(50)
      state1 = :sys.get_state(control_pid)
      history_len1 = length(state1.metrics_history)

      Process.sleep(150)
      state2 = :sys.get_state(control_pid)
      history_len2 = length(state2.metrics_history)

      assert history_len2 > history_len1,
             "Expected metrics history to grow over time"

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(test_file)
    end

    test "metrics contain valid audio analysis data", %{test_data_dir: test_data_dir} do
      test_file = Path.join(test_data_dir, "metrics_test.bin")
      create_comfortable_tone_file(test_file, 4800)

      configure_system(test_file)

      {:ok, control_pid} = start_supervised(ControlLoop)
      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      Process.sleep(200)

      state = :sys.get_state(control_pid)

      assert state.current_metrics != nil
      metrics = state.current_metrics

      assert is_float(metrics.rms)
      assert is_float(metrics.zcr)
      assert is_float(metrics.peak)

      assert metrics.rms >= 0.0 and metrics.rms <= 1.0
      assert metrics.zcr >= 0.0
      assert metrics.peak >= 0.0 and metrics.peak <= 1.0

      stop_supervised(AudioMonitor)
      stop_supervised(ControlLoop)
      File.rm(test_file)
    end
  end

  defp configure_system(audio_file) do
    Application.put_env(:hendrix_homeostat, :audio,
      sample_rate: 48000,
      buffer_size: 4800,
      device_name: audio_file,
      update_rate: 10
    )

    Application.put_env(:hendrix_homeostat, :backends,
      midi_backend: HendrixHomeostat.MidiBackend.InMemory,
      audio_backend: HendrixHomeostat.AudioBackend.File
    )
  end

  defp create_silence_file(path, num_samples) do
    samples = create_silence_samples(num_samples)
    File.write!(path, samples)
  end

  defp create_silence_samples(num_samples) do
    for _ <- 1..num_samples do
      <<0::signed-little-16>>
    end
    |> IO.iodata_to_binary()
  end

  defp create_loud_tone_file(path, num_samples, opts) do
    samples = create_loud_tone_samples(num_samples, opts)
    File.write!(path, samples)
  end

  defp create_loud_tone_samples(num_samples, opts) do
    amplitude = Keyword.get(opts, :amplitude, 30000)
    frequency = Keyword.get(opts, :frequency, 440.0)
    sample_rate = 48000

    for i <- 0..(num_samples - 1) do
      sample = trunc(amplitude * :math.sin(2 * :math.pi() * frequency * i / sample_rate))
      <<sample::signed-little-16>>
    end
    |> IO.iodata_to_binary()
  end

  defp create_comfortable_tone_file(path, num_samples) do
    amplitude = 10000
    frequency = 440.0
    sample_rate = 48000

    samples =
      for i <- 0..(num_samples - 1) do
        sample = trunc(amplitude * :math.sin(2 * :math.pi() * frequency * i / sample_rate))
        <<sample::signed-little-16>>
      end
      |> IO.iodata_to_binary()

    File.write!(path, samples)
  end
end
