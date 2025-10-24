defmodule HendrixHomeostat.AudioMonitorTest do
  use ExUnit.Case

  alias HendrixHomeostat.AudioMonitor

  @test_data_dir Path.join([__DIR__, "..", "fixtures"])

  setup do
    test_file = Path.join(@test_data_dir, "test_audio_monitor.bin")
    File.mkdir_p!(@test_data_dir)

    test_samples =
      for i <- 0..4799 do
        sample = trunc(10000 * :math.sin(2 * :math.pi() * 440 * i / 48000))
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

    %{test_file: test_file}
  end

  describe "GenServer lifecycle" do
    test "starts successfully with file backend" do
      {:ok, pid} = start_supervised(AudioMonitor)
      assert Process.alive?(pid)
    end

    test "loads configuration from application environment" do
      {:ok, pid} = start_supervised(AudioMonitor)

      state = :sys.get_state(pid)
      assert state.config.buffer_size == 4800
      assert state.config.sample_rate == 48000
      assert state.config.update_rate == 10
    end

    test "initializes backend and starts timer" do
      {:ok, pid} = start_supervised(AudioMonitor)

      state = :sys.get_state(pid)
      assert state.backend == HendrixHomeostat.AudioBackend.File
      assert state.backend_pid != nil
      assert Process.alive?(state.backend_pid)
      assert state.timer_ref != nil
      assert state.update_interval == 100
    end

    test "registers ControlLoop as destination for metrics" do
      {:ok, pid} = start_supervised(AudioMonitor)

      state = :sys.get_state(pid)
      assert state.control_loop_pid == HendrixHomeostat.ControlLoop
    end
  end

  describe "audio processing and metrics" do
    test "reads audio buffer and sends metrics to ControlLoop" do
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

    test "updates last_metrics in state after processing" do
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
      assert Map.has_key?(state.last_metrics, :rms)

      GenServer.stop(control_loop_pid)
      stop_supervised(AudioMonitor)
    end

    test "continues sending metrics over multiple cycles" do
      parent = self()

      {:ok, control_loop_pid} =
        GenServer.start_link(
          __MODULE__.MockControlLoop,
          %{parent: parent},
          name: HendrixHomeostat.ControlLoop
        )

      {:ok, _monitor_pid} = start_supervised(AudioMonitor)

      assert_receive {:metrics_received, _metrics1}, 1000
      assert_receive {:metrics_received, _metrics2}, 1000

      GenServer.stop(control_loop_pid)
      stop_supervised(AudioMonitor)
    end
  end

  describe "error handling" do
    test "handles backend initialization failure" do
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

      assert Process.alive?(monitor_pid)

      GenServer.stop(control_loop_pid)
      stop_supervised(AudioMonitor)
    end

    test "handles missing ControlLoop process gracefully" do
      if Process.whereis(HendrixHomeostat.ControlLoop) do
        Process.unregister(HendrixHomeostat.ControlLoop)
      end

      {:ok, monitor_pid} = start_supervised(AudioMonitor)

      Process.sleep(150)

      assert Process.alive?(monitor_pid)

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
end
