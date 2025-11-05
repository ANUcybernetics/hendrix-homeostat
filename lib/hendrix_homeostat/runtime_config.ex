defmodule HendrixHomeostat.RuntimeConfig do
  @moduledoc """
  Runtime configuration server that allows dynamic updates to control parameters.

  This module provides a GenServer that holds the runtime configuration and allows
  it to be updated on-the-fly from an IEx session without requiring a reboot.

  ## Usage in IEx

      # Get current configuration
      RuntimeConfig.get()

      # Update comfort zone maximum (louder)
      RuntimeConfig.set(:comfort_zone_max, 0.7)

      # Update comfort zone minimum
      RuntimeConfig.set(:comfort_zone_min, 0.3)

      # Update minimum action interval (slower changes)
      RuntimeConfig.set(:min_action_interval, 5000)

      # Update multiple values at once
      RuntimeConfig.update(%{comfort_zone_max: 0.6, min_action_interval: 3000})

      # Reset to defaults from config
      RuntimeConfig.reset()
  """

  use GenServer
  require Logger

  @config_keys [
    :critical_high,
    :comfort_zone_min,
    :comfort_zone_max,
    :critical_low,
    :stability_threshold,
    :stability_duration,
    :ultrastable_oscillation_threshold,
    :ultrastable_min_duration,
    :stuck_track_threshold,
    :min_action_interval
  ]

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

  @doc """
  Get the current runtime configuration.
  """
  def get do
    GenServer.call(__MODULE__, :get)
  end

  @doc """
  Get a specific configuration value.
  """
  def get(key) when key in @config_keys do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
  Set a specific configuration value.
  """
  def set(key, value) when key in @config_keys do
    GenServer.call(__MODULE__, {:set, key, value})
  end

  @doc """
  Update multiple configuration values at once.
  """
  def update(map) when is_map(map) do
    GenServer.call(__MODULE__, {:update, map})
  end

  @doc """
  Reset configuration to defaults from application config.
  """
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def init(_opts) do
    control_config = Application.fetch_env!(:hendrix_homeostat, :control)

    state = %{
      critical_high: Keyword.fetch!(control_config, :critical_high),
      comfort_zone_min: Keyword.fetch!(control_config, :comfort_zone_min),
      comfort_zone_max: Keyword.fetch!(control_config, :comfort_zone_max),
      critical_low: Keyword.fetch!(control_config, :critical_low),
      stability_threshold: Keyword.fetch!(control_config, :stability_threshold),
      stability_duration: Keyword.fetch!(control_config, :stability_duration),
      ultrastable_oscillation_threshold:
        Keyword.get(control_config, :ultrastable_oscillation_threshold, 10),
      ultrastable_min_duration: Keyword.get(control_config, :ultrastable_min_duration, 60_000),
      stuck_track_threshold: Keyword.get(control_config, :stuck_track_threshold, 5),
      min_action_interval: Keyword.get(control_config, :min_action_interval, 2000),
      defaults: control_config
    }

    Logger.info("RuntimeConfig initialized with: #{inspect(Map.delete(state, :defaults))}")
    {:ok, state}
  end

  @impl true
  def handle_call(:get, _from, state) do
    config = Map.delete(state, :defaults)
    {:reply, config, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  @impl true
  def handle_call({:set, key, value}, _from, state) do
    new_state = Map.put(state, key, value)
    Logger.info("RuntimeConfig updated: #{key} = #{inspect(value)}")

    # Notify ControlLoop of config change
    notify_control_loop(new_state)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:update, map}, _from, state) do
    new_state = Map.merge(state, map)
    Logger.info("RuntimeConfig updated: #{inspect(map)}")

    # Notify ControlLoop of config change
    notify_control_loop(new_state)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    control_config = state.defaults

    new_state = %{
      critical_high: Keyword.fetch!(control_config, :critical_high),
      comfort_zone_min: Keyword.fetch!(control_config, :comfort_zone_min),
      comfort_zone_max: Keyword.fetch!(control_config, :comfort_zone_max),
      critical_low: Keyword.fetch!(control_config, :critical_low),
      stability_threshold: Keyword.fetch!(control_config, :stability_threshold),
      stability_duration: Keyword.fetch!(control_config, :stability_duration),
      ultrastable_oscillation_threshold:
        Keyword.get(control_config, :ultrastable_oscillation_threshold, 10),
      ultrastable_min_duration: Keyword.get(control_config, :ultrastable_min_duration, 60_000),
      stuck_track_threshold: Keyword.get(control_config, :stuck_track_threshold, 5),
      min_action_interval: Keyword.get(control_config, :min_action_interval, 2000),
      defaults: control_config
    }

    Logger.info("RuntimeConfig reset to defaults")

    # Notify ControlLoop of config change
    notify_control_loop(new_state)

    {:reply, :ok, new_state}
  end

  defp notify_control_loop(state) do
    config = Map.delete(state, :defaults)

    # Only notify if ControlLoop is running
    case Process.whereis(HendrixHomeostat.ControlLoop) do
      nil -> :ok
      pid -> send(pid, {:config_update, config})
    end
  end
end
