defmodule HendrixHomeostat.ControlLoopHelpers do
  @moduledoc """
  Test helpers for ControlLoop testing.

  Provides utilities for:
  - Sending metrics messages
  - Subscribing to state broadcasts
  - Asserting on state updates via PubSub
  """

  import ExUnit.Assertions

  @doc """
  Send metrics to the ControlLoop GenServer.

  ## Examples

      send_metrics(0.9)
      send_metrics(0.05, zcr: 0.3, peak: 0.1)
  """
  def send_metrics(rms, opts \\ []) do
    zcr = Keyword.get(opts, :zcr, 0.5)
    peak = Keyword.get(opts, :peak, rms)

    send(HendrixHomeostat.ControlLoop, {:metrics, %{rms: rms, zcr: zcr, peak: peak}})
  end

  @doc """
  Subscribe to ControlLoop state broadcasts.

  Call this in test setup to receive {:control_state, state} messages.
  """
  def subscribe_to_control_loop do
    Phoenix.PubSub.subscribe(HendrixHomeostat.PubSub, "control_loop")
  end

  @doc """
  Assert that a state broadcast is received and return the state.

  ## Examples

      state = assert_state_broadcast()
      assert state.current_rms == 0.5

      state = assert_state_broadcast(timeout: 200)
  """
  def assert_state_broadcast(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 100)

    assert_receive {:control_state, state}, timeout
    state
  end

  @doc """
  Assert that a state broadcast is received with specific properties.

  ## Examples

      assert_state_broadcast_with(current_rms: 0.5)
      assert_state_broadcast_with([last_state: :too_loud], timeout: 200)
  """
  def assert_state_broadcast_with(expected_fields, opts \\ []) when is_list(expected_fields) do
    received_state = assert_state_broadcast(opts)

    Enum.each(expected_fields, fn {field, expected_value} ->
      actual_value = Map.get(received_state, field)

      assert actual_value == expected_value,
             "Expected state.#{field} to be #{inspect(expected_value)}, got #{inspect(actual_value)}"
    end)

    received_state
  end
end
