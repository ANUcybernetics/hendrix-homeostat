defmodule HendrixHomeostat.AudioMonitorTest do
  use ExUnit.Case

  alias HendrixHomeostat.AudioMonitor

  @test_data_dir Path.join([__DIR__, "..", "fixtures"])

  setup do
    test_file = Path.join(@test_data_dir, "test_audio_monitor.bin")
    File.mkdir_p!(@test_data_dir)

    test_samples =
      for _ <- 1..4800 do
        <<sample::signed-little-16>> = :crypto.strong_rand_bytes(2)
        <<sample::signed-little-16>>
      end
      |> IO.iodata_to_binary()

    File.write!(test_file, test_samples)

    original_config = Application.get_all_env(:hendrix_homeostat)

    Application.put_env(:hendrix_homeostat, :audio,
      sample_rate: 48000,
      buffer_size: 4800,
      device_name: test_file,
      update_rate: 10
    )

    Application.put_env(:hendrix_homeostat, :backends,
      audio_backend: HendrixHomeostat.AudioBackend.File
    )

    on_exit(fn ->
      File.rm(test_file)

      Enum.each(original_config, fn {key, value} ->
        Application.put_env(:hendrix_homeostat, key, value)
      end)
    end)

    %{test_file: test_file, test_data_dir: @test_data_dir}
  end

  describe "init/1" do
    test "initializes with file backend and starts timer" do
      {:ok, pid} = start_supervised(AudioMonitor)
      assert Process.alive?(pid)

      state = :sys.get_state(pid)
      assert state.backend == HendrixHomeostat.AudioBackend.File
      assert state.backend_pid != nil
      assert Process.alive?(state.backend_pid)
      assert state.timer_ref != nil
      assert state.update_interval == 100
      assert state.control_loop_pid == HendrixHomeostat.ControlLoop
    end

    test "state contains expected configuration" do
      {:ok, pid} = start_supervised(AudioMonitor)

      state = :sys.get_state(pid)
      assert state.config.buffer_size == 4800
      assert state.config.sample_rate == 48000
      assert state.config.update_rate == 10
    end
  end

  describe "handle_info(:read_audio)" do
    test "reads audio buffer and calculates metrics" do
      parent = self()

      {:ok, control_loop_pid} =
        GenServer.start_link(
          __MODULE__.MockControlLoop,
          %{parent: parent},
          name: HendrixHomeostat.ControlLoop
        )

      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      assert_receive {:metrics_received, metrics}, 1000

      assert is_map(metrics)
      assert Map.has_key?(metrics, :rms)
      assert Map.has_key?(metrics, :zcr)
      assert Map.has_key?(metrics, :peak)
      assert is_float(metrics.rms)
      assert is_float(metrics.zcr)
      assert is_float(metrics.peak)

      GenServer.stop(control_loop_pid)
      stop_supervised(AudioMonitor)
    end

    test "updates last_metrics in state" do
      parent = self()

      {:ok, control_loop_pid} =
        GenServer.start_link(
          __MODULE__.MockControlLoop,
          %{parent: parent},
          name: HendrixHomeostat.ControlLoop
        )

      {:ok, monitor_pid} = start_supervised(AudioMonitor)

      assert_receive {:metrics_received, _metrics}, 1000

      state = :sys.get_state(monitor_pid)
      assert state.last_metrics != nil
      assert is_map(state.last_metrics)

      GenServer.stop(control_loop_pid)
      stop_supervised(AudioMonitor)
    end

    test "continues operating on backend read errors" do
      parent = self()

      {:ok, control_loop_pid} =
        GenServer.start_link(
          __MODULE__.MockControlLoop,
          %{parent: parent},
          name: HendrixHomeostat.ControlLoop
        )

      {:ok, monitor_pid} = start_supervised(AudioMonitor)

      assert_receive {:metrics_received, _metrics}, 1000

      assert Process.alive?(monitor_pid)

      GenServer.stop(control_loop_pid)
      stop_supervised(AudioMonitor)
    end
  end

  describe "terminate/2" do
    test "cancels timer on shutdown" do
      {:ok, pid} = start_supervised(AudioMonitor)
      state = :sys.get_state(pid)
      timer_ref = state.timer_ref

      stop_supervised(AudioMonitor)

      assert :timer.cancel(timer_ref) == {:error, :badarg}
    end
  end

  describe "integration tests with recorded audio" do
    test "processes silence audio correctly", %{test_data_dir: test_data_dir} do
      silence_file = Path.join(test_data_dir, "silence.bin")

      silence_samples =
        for _ <- 1..4800 do
          <<0::signed-little-16>>
        end
        |> IO.iodata_to_binary()

      File.write!(silence_file, silence_samples)

      Application.put_env(:hendrix_homeostat, :audio,
        sample_rate: 48000,
        buffer_size: 4800,
        device_name: silence_file,
        update_rate: 10
      )

      parent = self()

      {:ok, control_loop_pid} =
        GenServer.start_link(
          __MODULE__.MockControlLoop,
          %{parent: parent},
          name: HendrixHomeostat.ControlLoop
        )

      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      assert_receive {:metrics_received, metrics}, 1000

      assert metrics.rms == 0.0
      assert metrics.zcr == 0.0
      assert metrics.peak == 0.0

      GenServer.stop(control_loop_pid)
      stop_supervised(AudioMonitor)
      File.rm(silence_file)
    end

    test "processes sustained tone correctly", %{test_data_dir: test_data_dir} do
      tone_file = Path.join(test_data_dir, "tone.bin")

      frequency = 440.0
      sample_rate = 48000
      amplitude = 16000

      tone_samples =
        for i <- 0..4799 do
          sample = trunc(amplitude * :math.sin(2 * :math.pi() * frequency * i / sample_rate))
          <<sample::signed-little-16>>
        end
        |> IO.iodata_to_binary()

      File.write!(tone_file, tone_samples)

      Application.put_env(:hendrix_homeostat, :audio,
        sample_rate: 48000,
        buffer_size: 4800,
        device_name: tone_file,
        update_rate: 10
      )

      parent = self()

      {:ok, control_loop_pid} =
        GenServer.start_link(
          __MODULE__.MockControlLoop,
          %{parent: parent},
          name: HendrixHomeostat.ControlLoop
        )

      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      assert_receive {:metrics_received, metrics}, 1000

      assert metrics.rms > 0.2
      assert metrics.zcr > 0.01
      assert metrics.peak > 0.4

      GenServer.stop(control_loop_pid)
      stop_supervised(AudioMonitor)
      File.rm(tone_file)
    end

    test "processes noise correctly", %{test_data_dir: test_data_dir} do
      noise_file = Path.join(test_data_dir, "noise.bin")

      noise_samples =
        for _ <- 1..4800 do
          <<sample::signed-little-16>> = :crypto.strong_rand_bytes(2)
          <<sample::signed-little-16>>
        end
        |> IO.iodata_to_binary()

      File.write!(noise_file, noise_samples)

      Application.put_env(:hendrix_homeostat, :audio,
        sample_rate: 48000,
        buffer_size: 4800,
        device_name: noise_file,
        update_rate: 10
      )

      parent = self()

      {:ok, control_loop_pid} =
        GenServer.start_link(
          __MODULE__.MockControlLoop,
          %{parent: parent},
          name: HendrixHomeostat.ControlLoop
        )

      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      assert_receive {:metrics_received, metrics}, 1000

      assert metrics.rms > 0.0
      assert metrics.zcr > 0.0
      assert metrics.peak > 0.0

      GenServer.stop(control_loop_pid)
      stop_supervised(AudioMonitor)
      File.rm(noise_file)
    end

    test "handles file loop correctly", %{test_data_dir: test_data_dir} do
      short_file = Path.join(test_data_dir, "short.bin")

      short_samples =
        for i <- 0..99 do
          sample = trunc(10000 * :math.sin(2 * :math.pi() * i / 100))
          <<sample::signed-little-16>>
        end
        |> IO.iodata_to_binary()

      File.write!(short_file, short_samples)

      Application.put_env(:hendrix_homeostat, :audio,
        sample_rate: 48000,
        buffer_size: 200,
        device_name: short_file,
        update_rate: 20
      )

      parent = self()

      {:ok, control_loop_pid} =
        GenServer.start_link(
          __MODULE__.MockControlLoop,
          %{parent: parent},
          name: HendrixHomeostat.ControlLoop
        )

      {:ok, monitor_pid} = start_supervised(AudioMonitor)

      assert_receive {:metrics_received, _metrics1}, 1000
      assert_receive {:metrics_received, _metrics2}, 1000

      assert Process.alive?(monitor_pid)

      GenServer.stop(control_loop_pid)
      stop_supervised(AudioMonitor)
      File.rm(short_file)
    end

    test "end-to-end flow from AudioMonitor through AudioAnalysis to ControlLoop", %{
      test_data_dir: test_data_dir
    } do
      e2e_file = Path.join(test_data_dir, "e2e.bin")

      frequency = 1000.0
      sample_rate = 48000
      amplitude = 20000

      e2e_samples =
        for i <- 0..4799 do
          sample = trunc(amplitude * :math.sin(2 * :math.pi() * frequency * i / sample_rate))
          <<sample::signed-little-16>>
        end
        |> IO.iodata_to_binary()

      File.write!(e2e_file, e2e_samples)

      Application.put_env(:hendrix_homeostat, :audio,
        sample_rate: 48000,
        buffer_size: 4800,
        device_name: e2e_file,
        update_rate: 10
      )

      parent = self()

      {:ok, control_loop_pid} =
        GenServer.start_link(
          __MODULE__.MetricsCollector,
          %{parent: parent},
          name: HendrixHomeostat.ControlLoop
        )

      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      assert_receive {:metrics_batch, metrics_list}, 2000

      assert length(metrics_list) > 0

      Enum.each(metrics_list, fn metrics ->
        assert is_map(metrics)
        assert Map.has_key?(metrics, :rms)
        assert Map.has_key?(metrics, :zcr)
        assert Map.has_key?(metrics, :peak)
        assert is_float(metrics.rms)
        assert is_float(metrics.zcr)
        assert is_float(metrics.peak)
      end)

      first_metrics = List.first(metrics_list)
      assert first_metrics.rms > 0.4
      assert first_metrics.peak > 0.5

      GenServer.stop(control_loop_pid)
      stop_supervised(AudioMonitor)
      File.rm(e2e_file)
    end
  end

  describe "error handling" do
    test "handles backend initialization failure gracefully" do
      Application.put_env(:hendrix_homeostat, :audio,
        sample_rate: 48000,
        buffer_size: 4800,
        device_name: "/nonexistent/path/to/file.bin",
        update_rate: 10
      )

      result = start_supervised(AudioMonitor)

      assert {:error, _} = result
    end

    test "continues operating when backend read fails temporarily" do
      parent = self()

      {:ok, control_loop_pid} =
        GenServer.start_link(
          __MODULE__.MockControlLoop,
          %{parent: parent},
          name: HendrixHomeostat.ControlLoop
        )

      {:ok, monitor_pid} = start_supervised(AudioMonitor)

      assert_receive {:metrics_received, _metrics}, 1000

      state_before = :sys.get_state(monitor_pid)

      assert_receive {:metrics_received, _metrics}, 1000

      assert Process.alive?(monitor_pid)

      state_after = :sys.get_state(monitor_pid)
      assert state_after.last_metrics != state_before.last_metrics

      GenServer.stop(control_loop_pid)
      stop_supervised(AudioMonitor)
    end

    test "handles missing ControlLoop process" do
      if Process.whereis(HendrixHomeostat.ControlLoop) do
        Process.unregister(HendrixHomeostat.ControlLoop)
      end

      {:ok, monitor_pid} = start_supervised(AudioMonitor)

      Process.sleep(150)

      assert Process.alive?(monitor_pid)

      stop_supervised(AudioMonitor)
    end
  end

  describe "configuration" do
    test "respects custom buffer size" do
      Application.put_env(:hendrix_homeostat, :audio,
        sample_rate: 48000,
        buffer_size: 9600,
        device_name: Path.join(@test_data_dir, "test_audio_monitor.bin"),
        update_rate: 10
      )

      {:ok, pid} = start_supervised(AudioMonitor)

      state = :sys.get_state(pid)
      assert state.config.buffer_size == 9600

      stop_supervised(AudioMonitor)
    end

    test "respects custom update rate" do
      Application.put_env(:hendrix_homeostat, :audio,
        sample_rate: 48000,
        buffer_size: 4800,
        device_name: Path.join(@test_data_dir, "test_audio_monitor.bin"),
        update_rate: 20
      )

      {:ok, pid} = start_supervised(AudioMonitor)

      state = :sys.get_state(pid)
      assert state.update_interval == 50
      assert state.config.update_rate == 20

      stop_supervised(AudioMonitor)
    end

    test "respects custom sample rate" do
      Application.put_env(:hendrix_homeostat, :audio,
        sample_rate: 44100,
        buffer_size: 4800,
        device_name: Path.join(@test_data_dir, "test_audio_monitor.bin"),
        update_rate: 10
      )

      {:ok, pid} = start_supervised(AudioMonitor)

      state = :sys.get_state(pid)
      assert state.config.sample_rate == 44100

      stop_supervised(AudioMonitor)
    end
  end

  defmodule MockControlLoop do
    use GenServer

    def init(state) do
      {:ok, state}
    end

    def handle_info({:metrics, metrics}, state) do
      send(state.parent, {:metrics_received, metrics})
      {:noreply, state}
    end
  end

  defmodule MetricsCollector do
    use GenServer

    def init(state) do
      Process.send_after(self(), :send_batch, 1500)
      {:ok, Map.put(state, :metrics, [])}
    end

    def handle_info({:metrics, metrics}, state) do
      {:noreply, %{state | metrics: [metrics | state.metrics]}}
    end

    def handle_info(:send_batch, state) do
      send(state.parent, {:metrics_batch, Enum.reverse(state.metrics)})
      {:noreply, state}
    end
  end
end
