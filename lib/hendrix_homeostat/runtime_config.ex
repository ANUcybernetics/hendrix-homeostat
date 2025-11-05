defmodule HendrixHomeostat.RuntimeConfig do
  @moduledoc """
  Runtime configuration server that allows dynamic updates to control parameters.

  This module provides a GenServer that holds the runtime configuration and allows
  it to be updated on-the-fly from an IEx session without requiring a reboot.

  ## Usage in IEx

      # Get current configuration
      RuntimeConfig.get()

      # Update too_loud threshold (make it louder before dampening)
      RuntimeConfig.set(:too_loud, 0.9)

      # Update too_quiet threshold (make it quieter before exciting)
      RuntimeConfig.set(:too_quiet, 0.05)

      # Update oscillation threshold (how many crossings before parameter change)
      RuntimeConfig.set(:oscillation_threshold, 8)

      # Update multiple values at once
      RuntimeConfig.update(%{too_loud: 0.85, too_quiet: 0.08})

      # Reset to defaults from config
      RuntimeConfig.reset()
  """

  use GenServer
  require Logger

  @config_keys [
    :too_loud,
    :too_quiet,
    :oscillation_threshold
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
      too_loud: Keyword.fetch!(control_config, :too_loud),
      too_quiet: Keyword.fetch!(control_config, :too_quiet),
      oscillation_threshold: Keyword.fetch!(control_config, :oscillation_threshold),
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
      too_loud: Keyword.fetch!(control_config, :too_loud),
      too_quiet: Keyword.fetch!(control_config, :too_quiet),
      oscillation_threshold: Keyword.fetch!(control_config, :oscillation_threshold),
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
