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

    assert config.too_loud == 0.5
    assert config.too_quiet == 0.1
    assert config.oscillation_threshold == 6
  end

  test "get/1 returns specific configuration value" do
    assert RuntimeConfig.get(:too_loud) == 0.5
    assert RuntimeConfig.get(:too_quiet) == 0.1
    assert RuntimeConfig.get(:oscillation_threshold) == 6
  end

  test "set/2 updates a single value" do
    assert :ok = RuntimeConfig.set(:too_loud, 0.9)
    assert RuntimeConfig.get(:too_loud) == 0.9
    # Other values unchanged
    assert RuntimeConfig.get(:too_quiet) == 0.1
  end

  test "update/1 updates multiple values at once" do
    assert :ok = RuntimeConfig.update(%{too_loud: 0.85, oscillation_threshold: 8})

    config = RuntimeConfig.get()
    assert config.too_loud == 0.85
    assert config.oscillation_threshold == 8
  end

  test "reset/0 restores defaults" do
    assert :ok = RuntimeConfig.set(:too_loud, 0.9)
    assert :ok = RuntimeConfig.reset()

    assert RuntimeConfig.get(:too_loud) == 0.5
  end

  test "set/2 rejects out of range values" do
    assert {:error, _reason} = RuntimeConfig.set(:too_loud, 1.5)
    assert RuntimeConfig.get(:too_loud) == 0.5
  end

  test "update/1 enforces quiet below loud" do
    assert {:error, _reason} = RuntimeConfig.update(%{too_quiet: 0.6})
    assert RuntimeConfig.get(:too_quiet) == 0.1
  end

  test "update/1 returns error when no valid keys provided" do
    assert {:error, :no_valid_keys} = RuntimeConfig.update(%{unknown: 1})
  end
end
