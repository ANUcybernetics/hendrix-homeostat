defmodule HendrixHomeostat.ControlLoop do
  @moduledoc """
  Ultrastable control loop implementing W. Ross Ashby's homeostat principle.

  This module implements a double feedback loop for adaptive audio control:

  ## First-Order Loop (Homeostasis)
  Actively seeks and maintains audio level (RMS) within the comfort zone (0.2-0.5):
  - RMS ≥ critical_high (0.8) → Stop random track (emergency damping)
  - RMS < comfort_zone_min (0.2) → Start recording (excitation, including from silence)
  - RMS > comfort_zone_max (0.5) → Stop random track (gentle damping)
  - Stable too long in comfort zone → Clear track (anti-stasis)

  The system actively seeks equilibrium in the comfort zone rather than passively
  waiting at extremes. Silence triggers excitation just like being too quiet.

  ## Second-Order Loop (Ultrastability)
  When the first-order loop fails to achieve stability (e.g., oscillating between
  too quiet and too loud), the system randomly changes track volume parameters to find
  a configuration that can stabilize in the comfort zone. This is analogous to Ashby's
  uniselector mechanism, which randomly changed circuit parameters until equilibrium
  was found.

  ## Overdubbing Behavior
  The system embraces overdubbing as part of its emergent complexity:
  - Calling start_recording on a playing track will overdub new material
  - This creates evolving textures and density over time
  - When a track becomes problematic (repeatedly causing critical_high), it gets cleared
  - This creates natural sparse → dense → sparse cycles

  ## Why It Works
  - **Negative feedback**: High levels trigger damping, low levels trigger excitation
  - **Parameter adaptation**: When current settings don't work, random search finds
    new settings that do (trial-and-error learning)
  - **Emergent stability**: System discovers equilibrium rather than being programmed
    for it
  - **Requisite variety**: Random parameter selection provides variety to match
    environmental disturbances

  The system explores a configuration space of 25 combinations (5 volume levels ×
  5 volume levels on tracks 1 and 2) until finding parameters that achieve homeostasis.
  """

  use GenServer
  require Logger

  @history_size 30
  @ultrastable_history_size 100
  @action_history_size 10

  defmodule TrackParams do
    @moduledoc false
    defstruct volume: 75
  end

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
    # Get initial config from RuntimeConfig
    config = HendrixHomeostat.RuntimeConfig.get()

    state = %{
      current_metrics: nil,
      metrics_history: [],
      last_action_timestamp: nil,
      # Second-order ultrastability state
      track1_params: %TrackParams{},
      track2_params: %TrackParams{},
      ultrastable_history: [],
      last_param_change_timestamp: nil,
      stability_attempts: 0,
      # Action history for detecting stuck tracks
      action_history: [],
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
      |> broadcast_state()

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:config_update, new_config}, state) do
    Logger.info("ControlLoop received config update: #{inspect(new_config)}")
    {:noreply, %{state | config: new_config}}
  end

  defp broadcast_state(state) do
    # Broadcast state for LiveView updates if PubSub is available
    # This is defensive - if PubSub isn't started (e.g., in tests), we just skip it
    try do
      Phoenix.PubSub.broadcast(
        HendrixHomeostat.PubSub,
        "control_loop",
        {:control_state, state}
      )
    rescue
      # PubSub not available
      ArgumentError -> :ok
    end

    state
  end

  defp update_metrics(state, metrics) do
    new_history = [metrics.rms | state.metrics_history] |> Enum.take(@history_size)

    new_ultrastable_history =
      [metrics | state.ultrastable_history] |> Enum.take(@ultrastable_history_size)

    %{
      state
      | current_metrics: metrics,
        metrics_history: new_history,
        ultrastable_history: new_ultrastable_history
    }
  end

  defp evaluate_and_act(state) do
    # Check for second-order failure first (ultrastability)
    if system_failing_to_stabilize?(state) do
      handle_ultrastable_reconfiguration(state)
    else
      # Normal first-order homeostatic control
      rms = state.current_metrics.rms

      cond do
        # Critical high: too loud, dampen immediately (bypass debounce for emergencies)
        rms >= state.config.critical_high ->
          handle_critical_high(state)

        # For non-critical actions, respect minimum action interval
        time_since_last_action(state) < state.config.min_action_interval ->
          state

        # Below comfort zone: too quiet (including silence), excite
        # This actively seeks the comfort zone rather than waiting for critical_low
        rms < state.config.comfort_zone_min ->
          handle_below_comfort_zone(state)

        # Above comfort zone but not critical: gentle management
        rms > state.config.comfort_zone_max ->
          handle_above_comfort_zone(state)

        # In comfort zone: maintain with anti-stasis
        in_comfort_zone?(rms, state.config) ->
          handle_comfort_zone(state)

        true ->
          state
      end
    end
  end

  defp time_since_last_action(%{last_action_timestamp: nil}), do: :infinity

  defp time_since_last_action(state) do
    System.monotonic_time(:millisecond) - state.last_action_timestamp
  end

  # Second-order ultrastable control
  defp system_failing_to_stabilize?(state) do
    with true <- length(state.ultrastable_history) >= @ultrastable_history_size,
         true <- time_since_param_change(state) >= state.config.ultrastable_min_duration,
         true <- excessive_oscillation?(state.ultrastable_history, state.config) do
      true
    else
      _ -> false
    end
  end

  defp time_since_param_change(%{last_param_change_timestamp: nil}), do: :infinity

  defp time_since_param_change(state) do
    System.monotonic_time(:millisecond) - state.last_param_change_timestamp
  end

  defp excessive_oscillation?(history, config) do
    # Count transitions between below comfort zone and critical_high
    # This detects when the system can't stabilize in the comfort zone
    critical_crossings =
      history
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.count(fn [a, b] ->
        (a.rms < config.comfort_zone_min and b.rms >= config.critical_high) or
          (a.rms >= config.critical_high and b.rms < config.comfort_zone_min)
      end)

    critical_crossings >= config.ultrastable_oscillation_threshold
  end

  defp handle_ultrastable_reconfiguration(state) do
    Logger.info(
      "Ultrastable reconfiguration triggered (attempt #{state.stability_attempts + 1}) - " <>
        "system oscillating, changing track parameters"
    )

    # Randomly mutate parameters - track 1 gets speed, track 2 doesn't
    new_track1_params = randomize_track_params(1)
    new_track2_params = randomize_track_params(2)

    # Apply via MIDI
    apply_track_params(1, new_track1_params)
    apply_track_params(2, new_track2_params)

    Logger.debug(
      "New params - Track1: vol=#{new_track1_params.volume}, Track2: vol=#{new_track2_params.volume}"
    )

    %{
      state
      | track1_params: new_track1_params,
        track2_params: new_track2_params,
        stability_attempts: state.stability_attempts + 1,
        last_param_change_timestamp: System.monotonic_time(:millisecond),
        ultrastable_history: [],
        metrics_history: [],
        action_history: []
    }
  end

  defp randomize_track_params(_track_num) do
    %TrackParams{
      volume: Enum.random([25, 50, 75, 100, 127])
    }
  end

  defp apply_track_params(track_num, params) do
    HendrixHomeostat.MidiController.set_track_volume(track_num, params.volume)
  end

  # First-order homeostatic control
  defp handle_critical_high(state) do
    track = Enum.random(1..2)

    # Check if this track is repeatedly causing problems
    if track_is_stuck?(state, track, :stop) do
      Logger.debug(
        "Track #{track} repeatedly causing critical_high, clearing it instead of stopping"
      )

      HendrixHomeostat.MidiController.clear_track(track)

      new_action_history = record_action(state.action_history, {:clear, track})

      %{
        state
        | last_action_timestamp: System.monotonic_time(:millisecond),
          metrics_history: [],
          action_history: new_action_history
      }
    else
      Logger.debug("Critical high detected, stopping track #{track}")
      HendrixHomeostat.MidiController.stop_track(track)

      new_action_history = record_action(state.action_history, {:stop, track})

      %{
        state
        | last_action_timestamp: System.monotonic_time(:millisecond),
          metrics_history: [],
          action_history: new_action_history
      }
    end
  end

  defp handle_below_comfort_zone(state) do
    track = Enum.random(1..2)

    Logger.debug(
      "Below comfort zone (RMS: #{Float.round(state.current_metrics.rms, 3)}), " <>
        "starting recording on track #{track} and boosting volume to build up sound"
    )

    # Start recording to capture material (even if just ambient noise)
    HendrixHomeostat.MidiController.start_recording(track)

    # Boost volume to make even quiet material audible
    # Ultrastability will find the right level if this causes oscillation
    HendrixHomeostat.MidiController.set_track_volume(track, 127)

    new_action_history = record_action(state.action_history, {:start, track})

    %{
      state
      | last_action_timestamp: System.monotonic_time(:millisecond),
        metrics_history: [],
        action_history: new_action_history
    }
  end

  defp handle_above_comfort_zone(state) do
    # Above comfort zone but below critical - use gentler control
    track = Enum.random(1..2)

    Logger.debug(
      "Above comfort zone (RMS: #{Float.round(state.current_metrics.rms, 3)}), " <>
        "stopping track #{track} to reduce level"
    )

    HendrixHomeostat.MidiController.stop_track(track)

    new_action_history = record_action(state.action_history, {:stop, track})

    %{
      state
      | last_action_timestamp: System.monotonic_time(:millisecond),
        metrics_history: [],
        action_history: new_action_history
    }
  end

  defp handle_comfort_zone(state) do
    if stable_too_long?(state) do
      track = Enum.random(1..2)
      Logger.debug("System stable too long, clearing track #{track}")
      HendrixHomeostat.MidiController.clear_track(track)

      new_action_history = record_action(state.action_history, {:clear, track})

      %{
        state
        | last_action_timestamp: System.monotonic_time(:millisecond),
          metrics_history: [],
          action_history: new_action_history
      }
    else
      state
    end
  end

  # Action history management
  defp record_action(history, action) do
    [action | history] |> Enum.take(@action_history_size)
  end

  defp track_is_stuck?(state, track, action) do
    # Check if the last N actions were all the same action on the same track
    recent_actions = Enum.take(state.action_history, state.config.stuck_track_threshold)

    if length(recent_actions) < state.config.stuck_track_threshold do
      false
    else
      Enum.all?(recent_actions, fn {act, trk} -> act == action and trk == track end)
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
