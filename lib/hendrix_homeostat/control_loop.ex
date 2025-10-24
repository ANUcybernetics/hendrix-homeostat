defmodule HendrixHomeostat.ControlLoop do
  use GenServer
  require Logger

  @history_size 30

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      shutdown: 5_000
    }
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    control_config = Application.fetch_env!(:hendrix_homeostat, :control)

    config = %{
      critical_high: Keyword.fetch!(control_config, :critical_high),
      comfort_zone_min: Keyword.fetch!(control_config, :comfort_zone_min),
      comfort_zone_max: Keyword.fetch!(control_config, :comfort_zone_max),
      critical_low: Keyword.fetch!(control_config, :critical_low),
      stability_threshold: Keyword.fetch!(control_config, :stability_threshold),
      stability_duration: Keyword.fetch!(control_config, :stability_duration)
    }

    state = %{
      current_metrics: nil,
      metrics_history: [],
      last_action_timestamp: nil,
      config: config
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:metrics, metrics}, state) do
    new_state =
      state
      |> update_metrics(metrics)
      |> evaluate_and_act()

    {:noreply, new_state}
  end

  defp update_metrics(state, metrics) do
    new_history = [metrics.rms | state.metrics_history] |> Enum.take(@history_size)

    %{state | current_metrics: metrics, metrics_history: new_history}
  end

  defp evaluate_and_act(state) do
    rms = state.current_metrics.rms

    cond do
      rms >= state.config.critical_high ->
        handle_critical_high(state)

      rms <= state.config.critical_low ->
        handle_critical_low(state)

      in_comfort_zone?(rms, state.config) ->
        handle_comfort_zone(state)

      true ->
        state
    end
  end

  defp handle_critical_high(state) do
    track = Enum.random(1..6)
    Logger.debug("Critical high detected, stopping track #{track}")
    HendrixHomeostat.MidiController.stop_track(track)

    %{
      state
      | last_action_timestamp: System.monotonic_time(:millisecond),
        metrics_history: []
    }
  end

  defp handle_critical_low(state) do
    track = Enum.random(1..6)
    Logger.debug("Critical low detected, starting recording on track #{track}")
    HendrixHomeostat.MidiController.start_recording(track)

    %{
      state
      | last_action_timestamp: System.monotonic_time(:millisecond),
        metrics_history: []
    }
  end

  defp handle_comfort_zone(state) do
    if stable_too_long?(state) do
      track = Enum.random(1..4)
      Logger.debug("System stable too long, clearing track #{track}")
      HendrixHomeostat.MidiController.clear_track(track)

      %{
        state
        | last_action_timestamp: System.monotonic_time(:millisecond),
          metrics_history: []
      }
    else
      state
    end
  end

  defp in_comfort_zone?(rms, config) do
    rms >= config.comfort_zone_min and rms <= config.comfort_zone_max
  end

  defp stable_too_long?(state) do
    with true <- length(state.metrics_history) >= @history_size,
         true <- within_stability_duration?(state),
         true <- variance_below_threshold?(state) do
      true
    else
      _ -> false
    end
  end

  defp within_stability_duration?(%{last_action_timestamp: nil}), do: true

  defp within_stability_duration?(state) do
    elapsed = System.monotonic_time(:millisecond) - state.last_action_timestamp
    elapsed >= state.config.stability_duration
  end

  defp variance_below_threshold?(state) do
    variance = calculate_variance(state.metrics_history)
    variance < state.config.stability_threshold
  end

  defp calculate_variance([]), do: 0.0

  defp calculate_variance(values) do
    mean = Enum.sum(values) / length(values)
    variance = Enum.reduce(values, 0.0, fn x, acc -> acc + :math.pow(x - mean, 2) end)
    variance / length(values)
  end
end
