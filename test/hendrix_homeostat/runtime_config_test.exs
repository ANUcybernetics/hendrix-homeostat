defmodule HendrixHomeostat.RuntimeConfigTest do
  use ExUnit.Case, async: false

  alias HendrixHomeostat.RuntimeConfig

  setup do
    # Save original config and reset after each test
    original_config = RuntimeConfig.get()
    on_exit(fn -> RuntimeConfig.update(original_config) end)
    :ok
  end

  test "initializes with defaults from application config" do
    config = RuntimeConfig.get()

    assert config.critical_high == 0.8
    assert config.comfort_zone_min == 0.2
    assert config.comfort_zone_max == 0.5
    assert config.min_action_interval == 2000
  end

  test "get/1 returns specific configuration value" do
    assert RuntimeConfig.get(:comfort_zone_max) == 0.5
    assert RuntimeConfig.get(:min_action_interval) == 2000
  end

  test "set/2 updates a single value" do
    RuntimeConfig.set(:comfort_zone_max, 0.7)
    assert RuntimeConfig.get(:comfort_zone_max) == 0.7
    # Other values unchanged
    assert RuntimeConfig.get(:comfort_zone_min) == 0.2
  end

  test "update/1 updates multiple values at once" do
    RuntimeConfig.update(%{comfort_zone_max: 0.6, min_action_interval: 3000})

    config = RuntimeConfig.get()
    assert config.comfort_zone_max == 0.6
    assert config.min_action_interval == 3000
  end

  test "reset/0 restores defaults" do
    RuntimeConfig.set(:comfort_zone_max, 0.9)
    RuntimeConfig.reset()

    assert RuntimeConfig.get(:comfort_zone_max) == 0.5
  end
end
