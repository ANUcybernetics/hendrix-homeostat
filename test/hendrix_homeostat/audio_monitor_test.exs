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

    Application.put_env(:hendrix_homeostat, :audio, [
      sample_rate: 48000,
      buffer_size: 4800,
      device_name: test_file,
      update_rate: 10
    ])

    Application.put_env(:hendrix_homeostat, :backends, [
      audio_backend: HendrixHomeostat.AudioBackend.File
    ])

    on_exit(fn ->
      File.rm(test_file)

      Enum.each(original_config, fn {key, value} ->
        Application.put_env(:hendrix_homeostat, key, value)
      end)
    end)

    %{test_file: test_file}
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

      {:ok, monitor_pid} = start_supervised(AudioMonitor)

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
