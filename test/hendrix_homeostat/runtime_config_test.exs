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

    assert config.too_loud == 0.8
    assert config.too_quiet == 0.1
    assert config.oscillation_threshold == 6
  end

  test "get/1 returns specific configuration value" do
    assert RuntimeConfig.get(:too_loud) == 0.8
    assert RuntimeConfig.get(:too_quiet) == 0.1
    assert RuntimeConfig.get(:oscillation_threshold) == 6
  end

  test "set/2 updates a single value" do
    RuntimeConfig.set(:too_loud, 0.9)
    assert RuntimeConfig.get(:too_loud) == 0.9
    # Other values unchanged
    assert RuntimeConfig.get(:too_quiet) == 0.1
  end

  test "update/1 updates multiple values at once" do
    RuntimeConfig.update(%{too_loud: 0.85, oscillation_threshold: 8})

    config = RuntimeConfig.get()
    assert config.too_loud == 0.85
    assert config.oscillation_threshold == 8
  end

  test "reset/0 restores defaults" do
    RuntimeConfig.set(:too_loud, 0.9)
    RuntimeConfig.reset()

    assert RuntimeConfig.get(:too_loud) == 0.8
  end
end
