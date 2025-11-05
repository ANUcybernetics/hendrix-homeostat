defmodule HendrixHomeostat.ControlLoop do
  @moduledoc """
  Simplified ultrastable control loop implementing W. Ross Ashby's homeostat principle.

  This module implements a double feedback loop for adaptive audio control:

  ## First-Order Loop (Basic Homeostasis)
  Simple negative feedback with just two thresholds:
  - RMS ≥ too_loud (0.5) → Stop random track (damping)
  - RMS ≤ too_quiet (0.1) → Start recording on random track (excitation)
  - Everything else → Do nothing (let the environment provide complexity)

  ## Second-Order Loop (Ultrastability)
  When the first-order loop oscillates excessively (repeatedly crossing between
  too_quiet and too_loud), the system randomly changes track volume parameters.
  This is analogous to Ashby's uniselector mechanism - random search through
  parameter space until finding a configuration that achieves equilibrium.

  ## Why It Works
  - **Negative feedback**: High → dampen, Low → excite
  - **Parameter adaptation**: When oscillating, try new random parameters
  - **Emergent stability**: System discovers equilibrium through trial-and-error
  - **Environmental complexity**: Guitar/room/system resonance provides the interest

  The system explores 25 volume configurations (5 levels × 5 levels for tracks 1-2)
  until finding parameters that prevent oscillation.
  """

  use GenServer
  require Logger

  # How many recent state transitions to track for oscillation detection
  @transition_history_size 20

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
            current_rms: float() | nil,
            last_state: :too_quiet | :too_loud | :ok | nil,
            transition_history: list({:too_quiet | :too_loud, integer()}),
            track1_volume: integer(),
            track2_volume: integer(),
            config: map()
          }

    defstruct [
      :current_rms,
      :last_state,
      transition_history: [],
      track1_volume: 75,
      track2_volume: 75,
      config: %{}
    ]
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
    config = HendrixHomeostat.RuntimeConfig.get()

    state = %State{
      config: config
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:metrics, metrics}, state) do
    new_state =
      state
      |> Map.put(:current_rms, metrics.rms)
      |> evaluate_and_act()
      |> broadcast_state()

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:config_update, new_config}, state) do
    Logger.info("ControlLoop received config update: #{inspect(new_config)}")
    {:noreply, %{state | config: new_config}}
  end

  # ============================================================================
  # Pure decision logic (easily testable)
  # ============================================================================

  @doc """
  Determine what state the system is in based on RMS level.

  ## Examples

      iex> ControlLoop.classify_state(0.9, %{too_loud: 0.8, too_quiet: 0.1})
      :too_loud

      iex> ControlLoop.classify_state(0.05, %{too_loud: 0.8, too_quiet: 0.1})
      :too_quiet

      iex> ControlLoop.classify_state(0.5, %{too_loud: 0.8, too_quiet: 0.1})
      :ok
  """
  def classify_state(rms, config) do
    cond do
      rms >= config.too_loud -> :too_loud
      rms <= config.too_quiet -> :too_quiet
      true -> :ok
    end
  end

  @doc """
  Determine if a state transition occurred (and if so, record it).

  Returns {:transition, new_state} or {:no_transition, current_state}

  ## Examples

      iex> ControlLoop.detect_transition(:too_quiet, :too_loud)
      {:transition, :too_loud}

      iex> ControlLoop.detect_transition(:too_loud, :too_quiet)
      {:transition, :too_quiet}

      iex> ControlLoop.detect_transition(:too_loud, :too_loud)
      {:no_transition, :too_loud}

      iex> ControlLoop.detect_transition(:ok, :too_loud)
      {:transition, :too_loud}

      iex> ControlLoop.detect_transition(nil, :too_loud)
      {:transition, :too_loud}
  """
  def detect_transition(last_state, new_state) do
    if last_state != new_state and new_state in [:too_quiet, :too_loud] do
      {:transition, new_state}
    else
      {:no_transition, new_state}
    end
  end

  @doc """
  Check if the system is oscillating excessively.

  Oscillation is defined as repeatedly transitioning between :too_quiet and :too_loud.
  We count how many times we've crossed from one extreme to the other.

  ## Examples

      iex> history = [
      ...>   {:too_loud, 100}, {:too_quiet, 90}, {:too_loud, 80},
      ...>   {:too_quiet, 70}, {:too_loud, 60}, {:too_quiet, 50},
      ...>   {:too_loud, 40}, {:too_quiet, 30}
      ...> ]
      iex> ControlLoop.oscillating?(history, %{oscillation_threshold: 6})
      true

      iex> history = [
      ...>   {:too_loud, 100}, {:too_quiet, 90}, {:too_loud, 80}
      ...> ]
      iex> ControlLoop.oscillating?(history, %{oscillation_threshold: 6})
      false

      iex> ControlLoop.oscillating?([], %{oscillation_threshold: 6})
      false
  """
  def oscillating?(history, _config) when length(history) < 2, do: false

  def oscillating?(history, config) do
    # Count crossings between too_quiet and too_loud
    crossings =
      history
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.count(fn [{state_a, _}, {state_b, _}] ->
        (state_a == :too_quiet and state_b == :too_loud) or
          (state_a == :too_loud and state_b == :too_quiet)
      end)

    crossings >= config.oscillation_threshold
  end

  @doc """
  Generate random volume parameters for a track.

  ## Examples

      iex> vol = ControlLoop.random_volume()
      iex> vol in [25, 50, 75, 100, 127]
      true
  """
  def random_volume do
    Enum.random([25, 50, 75, 100, 127])
  end

  # ============================================================================
  # Effectful actions (state updates + MIDI commands)
  # ============================================================================

  defp evaluate_and_act(%State{current_rms: nil} = state), do: state

  defp evaluate_and_act(state) do
    current_state = classify_state(state.current_rms, state.config)

    case detect_transition(state.last_state, current_state) do
      {:transition, new_state} ->
        state
        |> record_transition(new_state)
        |> maybe_trigger_ultrastable_reconfiguration()
        |> take_action(new_state)
        |> Map.put(:last_state, new_state)

      {:no_transition, _} ->
        # No transition, but still take action if in extreme state
        if current_state in [:too_quiet, :too_loud] do
          take_action(state, current_state)
        else
          state
        end
    end
  end

  defp record_transition(state, new_extreme_state) do
    timestamp = System.monotonic_time(:millisecond)
    new_transition = {new_extreme_state, timestamp}

    new_history =
      [new_transition | state.transition_history]
      |> Enum.take(@transition_history_size)

    %{state | transition_history: new_history}
  end

  defp maybe_trigger_ultrastable_reconfiguration(state) do
    if oscillating?(state.transition_history, state.config) do
      trigger_ultrastable_reconfiguration(state)
    else
      state
    end
  end

  defp trigger_ultrastable_reconfiguration(state) do
    Logger.info("Ultrastable reconfiguration triggered - system oscillating, changing parameters")

    new_track1_volume = random_volume()
    new_track2_volume = random_volume()

    HendrixHomeostat.MidiController.set_track_volume(1, new_track1_volume)
    HendrixHomeostat.MidiController.set_track_volume(2, new_track2_volume)

    Logger.debug("New params - Track1: vol=#{new_track1_volume}, Track2: vol=#{new_track2_volume}")

    %{
      state
      | track1_volume: new_track1_volume,
        track2_volume: new_track2_volume,
        transition_history: []
    }
  end

  defp take_action(state, :too_loud) do
    track = Enum.random(1..2)
    Logger.debug("Too loud (RMS: #{Float.round(state.current_rms, 3)}), stopping track #{track}")
    HendrixHomeostat.MidiController.stop_track(track)
    state
  end

  defp take_action(state, :too_quiet) do
    track = Enum.random(1..2)

    Logger.debug(
      "Too quiet (RMS: #{Float.round(state.current_rms, 3)}), starting recording on track #{track}"
    )

    HendrixHomeostat.MidiController.start_recording(track)
    state
  end

  defp take_action(state, :ok), do: state

  defp broadcast_state(state) do
    # Broadcast state for LiveView updates if PubSub is available
    try do
      Phoenix.PubSub.broadcast(
        HendrixHomeostat.PubSub,
        "control_loop",
        {:control_state, state}
      )
    rescue
      ArgumentError -> :ok
    end

    state
  end
end
