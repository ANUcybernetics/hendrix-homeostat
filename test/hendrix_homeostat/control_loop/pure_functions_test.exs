defmodule HendrixHomeostat.ControlLoop.PureFunctionsTest do
  use ExUnit.Case, async: true

  alias HendrixHomeostat.ControlLoop

  doctest HendrixHomeostat.ControlLoop

  describe "classify_state/2" do
    setup do
      config = %{too_loud: 0.8, too_quiet: 0.1}
      {:ok, config: config}
    end

    test "classifies as :too_loud when RMS >= threshold", %{config: config} do
      assert ControlLoop.classify_state(0.8, config) == :too_loud
      assert ControlLoop.classify_state(0.9, config) == :too_loud
      assert ControlLoop.classify_state(1.0, config) == :too_loud
    end

    test "classifies as :too_quiet when RMS <= threshold", %{config: config} do
      assert ControlLoop.classify_state(0.1, config) == :too_quiet
      assert ControlLoop.classify_state(0.05, config) == :too_quiet
      assert ControlLoop.classify_state(0.0, config) == :too_quiet
    end

    test "classifies as :ok when RMS between thresholds", %{config: config} do
      assert ControlLoop.classify_state(0.11, config) == :ok
      assert ControlLoop.classify_state(0.5, config) == :ok
      assert ControlLoop.classify_state(0.79, config) == :ok
    end

    test "boundary values are inclusive", %{config: config} do
      # Exactly at too_loud threshold
      assert ControlLoop.classify_state(0.8, config) == :too_loud

      # Exactly at too_quiet threshold
      assert ControlLoop.classify_state(0.1, config) == :too_quiet
    end

    test "works with different threshold values" do
      custom_config = %{too_loud: 0.9, too_quiet: 0.05}

      assert ControlLoop.classify_state(0.9, custom_config) == :too_loud
      assert ControlLoop.classify_state(0.05, custom_config) == :too_quiet
      assert ControlLoop.classify_state(0.5, custom_config) == :ok
    end
  end

  describe "detect_transition/2" do
    test "detects transition from too_quiet to too_loud" do
      assert ControlLoop.detect_transition(:too_quiet, :too_loud) == {:transition, :too_loud}
    end

    test "detects transition from too_loud to too_quiet" do
      assert ControlLoop.detect_transition(:too_loud, :too_quiet) == {:transition, :too_quiet}
    end

    test "detects transition from :ok to too_loud" do
      assert ControlLoop.detect_transition(:ok, :too_loud) == {:transition, :too_loud}
    end

    test "detects transition from :ok to too_quiet" do
      assert ControlLoop.detect_transition(:ok, :too_quiet) == {:transition, :too_quiet}
    end

    test "detects transition from nil (initial state) to extreme" do
      assert ControlLoop.detect_transition(nil, :too_loud) == {:transition, :too_loud}
      assert ControlLoop.detect_transition(nil, :too_quiet) == {:transition, :too_quiet}
    end

    test "no transition when state unchanged" do
      assert ControlLoop.detect_transition(:too_loud, :too_loud) == {:no_transition, :too_loud}

      assert ControlLoop.detect_transition(:too_quiet, :too_quiet) ==
               {:no_transition, :too_quiet}

      assert ControlLoop.detect_transition(:ok, :ok) == {:no_transition, :ok}
    end

    test "no transition from extreme to :ok" do
      assert ControlLoop.detect_transition(:too_loud, :ok) == {:no_transition, :ok}
      assert ControlLoop.detect_transition(:too_quiet, :ok) == {:no_transition, :ok}
    end

    test "no transition from nil to :ok" do
      assert ControlLoop.detect_transition(nil, :ok) == {:no_transition, :ok}
    end
  end

  describe "oscillating?/2" do
    setup do
      config = %{oscillation_threshold: 6}
      {:ok, config: config}
    end

    test "empty history is not oscillating", %{config: config} do
      refute ControlLoop.oscillating?([], config)
    end

    test "single transition is not oscillating", %{config: config} do
      history = [{:too_loud, 100}]
      refute ControlLoop.oscillating?(history, config)
    end

    test "two consecutive same states is not oscillating", %{config: config} do
      history = [{:too_loud, 100}, {:too_loud, 90}]
      refute ControlLoop.oscillating?(history, config)
    end

    test "few crossings below threshold is not oscillating", %{config: config} do
      history = [
        {:too_loud, 150},
        {:too_quiet, 140},
        {:too_loud, 130},
        {:too_quiet, 120},
        {:too_loud, 110}
      ]

      # Only 4 transitions between the 5 states, need 6
      refute ControlLoop.oscillating?(history, config)
    end

    test "many crossings above threshold is oscillating", %{config: config} do
      history = [
        {:too_loud, 160},
        {:too_quiet, 150},
        {:too_loud, 140},
        {:too_quiet, 130},
        {:too_loud, 120},
        {:too_quiet, 110},
        {:too_loud, 100}
      ]

      # 6 transitions between 7 states
      assert ControlLoop.oscillating?(history, config)
    end

    test "exactly at threshold is oscillating", %{config: config} do
      # Create exactly 6 crossings
      history = [
        {:too_loud, 130},
        {:too_quiet, 120},
        {:too_loud, 110},
        {:too_quiet, 100},
        {:too_loud, 90},
        {:too_quiet, 80},
        {:too_loud, 70}
      ]

      assert ControlLoop.oscillating?(history, config)
    end

    test "works with different oscillation threshold" do
      custom_config = %{oscillation_threshold: 3}

      history = [
        {:too_loud, 100},
        {:too_quiet, 90},
        {:too_loud, 80},
        {:too_quiet, 70}
      ]

      # 3 crossings
      assert ControlLoop.oscillating?(history, custom_config)
    end

    test "consecutive same states don't count as crossings", %{config: config} do
      history = [
        {:too_loud, 120},
        {:too_loud, 110},
        {:too_quiet, 100},
        {:too_quiet, 90},
        {:too_loud, 80},
        {:too_loud, 70}
      ]

      # Only 2 actual crossings (loud->quiet and quiet->loud)
      refute ControlLoop.oscillating?(history, config)
    end

    test "realistic oscillation pattern", %{config: config} do
      # Simulating a system that can't stabilize
      history = [
        {:too_loud, 200},
        {:too_quiet, 190},
        {:too_loud, 180},
        {:too_quiet, 170},
        {:too_loud, 160},
        {:too_quiet, 150},
        {:too_loud, 140},
        {:too_quiet, 130}
      ]

      # 7 crossings - definitely oscillating
      assert ControlLoop.oscillating?(history, config)
    end
  end

  describe "random_volume/0" do
    test "returns one of the valid volume levels" do
      valid_volumes = [25, 50, 75, 100, 127]

      for _ <- 1..20 do
        volume = ControlLoop.random_volume()
        assert volume in valid_volumes
      end
    end

    test "can return different values (probabilistic)" do
      volumes = for _ <- 1..50, do: ControlLoop.random_volume()
      unique_volumes = Enum.uniq(volumes)

      # With 50 samples from 5 options, we should see at least 3 different values
      assert length(unique_volumes) >= 3
    end
  end

  describe "action_for_state/1" do
    test "returns stop_track action for too_loud" do
      action = ControlLoop.action_for_state(:too_loud)
      assert match?({:stop_track, track} when track in 1..2, action)
    end

    test "returns start_recording action for too_quiet" do
      action = ControlLoop.action_for_state(:too_quiet)
      assert match?({:start_recording, track} when track in 1..2, action)
    end

    test "returns nil for ok state" do
      assert ControlLoop.action_for_state(:ok) == nil
    end
  end

  describe "plan_actions/4" do
    setup do
      config = %{too_loud: 0.8, too_quiet: 0.1, oscillation_threshold: 6}
      {:ok, config: config}
    end

    test "plans transition and action when entering too_loud from nil", %{config: config} do
      plan = ControlLoop.plan_actions(0.9, nil, [], config)

      assert plan.new_state == :too_loud
      assert match?({:stop_track, _}, plan.action)
      assert plan.record_transition == true
      assert plan.ultrastable_reconfig == false
    end

    test "plans transition and action when entering too_quiet from nil", %{config: config} do
      plan = ControlLoop.plan_actions(0.05, nil, [], config)

      assert plan.new_state == :too_quiet
      assert match?({:start_recording, _}, plan.action)
      assert plan.record_transition == true
      assert plan.ultrastable_reconfig == false
    end

    test "plans transition from too_loud to too_quiet", %{config: config} do
      plan = ControlLoop.plan_actions(0.05, :too_loud, [{:too_loud, 100}], config)

      assert plan.new_state == :too_quiet
      assert match?({:start_recording, _}, plan.action)
      assert plan.record_transition == true
      assert plan.ultrastable_reconfig == false
    end

    test "plans transition from too_quiet to too_loud", %{config: config} do
      plan = ControlLoop.plan_actions(0.9, :too_quiet, [{:too_quiet, 100}], config)

      assert plan.new_state == :too_loud
      assert match?({:stop_track, _}, plan.action)
      assert plan.record_transition == true
      assert plan.ultrastable_reconfig == false
    end

    test "plans no transition when staying in same extreme state", %{config: config} do
      plan = ControlLoop.plan_actions(0.95, :too_loud, [{:too_loud, 100}], config)

      assert plan.new_state == :too_loud
      assert match?({:stop_track, _}, plan.action)
      assert plan.record_transition == false
      assert plan.ultrastable_reconfig == false
    end

    test "plans no action when entering ok state", %{config: config} do
      plan = ControlLoop.plan_actions(0.5, :too_loud, [{:too_loud, 100}], config)

      assert plan.new_state == :ok
      assert plan.action == nil
      assert plan.record_transition == false
      assert plan.ultrastable_reconfig == false
    end

    test "plans ultrastable reconfig when oscillating", %{config: config} do
      history = [
        {:too_quiet, 130},
        {:too_loud, 120},
        {:too_quiet, 110},
        {:too_loud, 100},
        {:too_quiet, 90},
        {:too_loud, 80}
      ]

      plan = ControlLoop.plan_actions(0.9, :too_quiet, history, config)

      assert plan.new_state == :too_loud
      assert match?({:stop_track, _}, plan.action)
      assert plan.record_transition == true
      assert plan.ultrastable_reconfig == true
    end

    test "does not plan reconfig when not oscillating", %{config: config} do
      history = [
        {:too_loud, 100},
        {:too_quiet, 90}
      ]

      plan = ControlLoop.plan_actions(0.9, :too_quiet, history, config)

      assert plan.new_state == :too_loud
      assert plan.ultrastable_reconfig == false
    end

    test "works with different config thresholds" do
      custom_config = %{too_loud: 0.9, too_quiet: 0.05, oscillation_threshold: 3}

      plan = ControlLoop.plan_actions(0.95, nil, [], custom_config)

      assert plan.new_state == :too_loud
      assert match?({:stop_track, _}, plan.action)
    end

    test "plans action even when no transition in extreme state", %{config: config} do
      plan = ControlLoop.plan_actions(0.9, :too_loud, [{:too_loud, 100}], config)

      assert plan.new_state == :too_loud
      assert match?({:stop_track, _}, plan.action)
      assert plan.record_transition == false
    end
  end
end
