## Testing ControlLoop Implementation

### Manual Testing (without libmnl-dev)

If you don't have `libmnl-dev` installed, you can still verify the implementation:

```bash
elixir test/manual_control_loop_test.exs
```

This will verify that the module compiles and has the correct structure.

### Full Test Suite (requires libmnl-dev)

1. Install the required system library:
   ```bash
   sudo apt-get install libmnl-dev
   ```

2. Run the complete test suite:
   ```bash
   MIX_TARGET=host mix test test/hendrix_homeostat/control_loop_test.exs
   ```

### Interactive Testing

You can test the ControlLoop interactively using IEx. First install libmnl-dev, then:

```bash
MIX_TARGET=host iex -S mix
```

Then in the IEx session:

```elixir
# Send a critical high metric
send(HendrixHomeostat.ControlLoop, {:metrics, %{rms: 0.9, zcr: 0.5, peak: 0.95}})

# Check the state
:sys.get_state(HendrixHomeostat.ControlLoop)

# Verify MIDI command was sent
HendrixHomeostat.MidiBackend.InMemory.get_history()

# Send comfort zone metrics
for _i <- 1..5 do
  send(HendrixHomeostat.ControlLoop, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.4}})
end

# Check history accumulation
state = :sys.get_state(HendrixHomeostat.ControlLoop)
length(state.metrics_history)

# Send a critical low metric
send(HendrixHomeostat.ControlLoop, {:metrics, %{rms: 0.02, zcr: 0.5, peak: 0.05}})

# Verify history was reset
state = :sys.get_state(HendrixHomeostat.ControlLoop)
state.metrics_history
```

### Testing Anti-Stasis Mechanism

To test the anti-stasis mechanism, you need to build up history and manipulate timestamps:

```elixir
# Build up 30 stable samples
for _i <- 1..30 do
  send(HendrixHomeostat.ControlLoop, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.4}})
  Process.sleep(10)
end

# Manually set last_action_timestamp to 31 seconds ago
:sys.replace_state(HendrixHomeostat.ControlLoop, fn state ->
  %{state | last_action_timestamp: System.monotonic_time(:millisecond) - 31_000}
end)

# Send one more stable metric to trigger anti-stasis
send(HendrixHomeostat.ControlLoop, {:metrics, %{rms: 0.3, zcr: 0.5, peak: 0.4}})

# Check that a random patch was selected
HendrixHomeostat.MidiBackend.InMemory.get_history()
# Should show a patch from random_bank [20-29]

# Verify state changed to :stable and history was cleared
state = :sys.get_state(HendrixHomeostat.ControlLoop)
state.current_state  # Should be :stable
state.metrics_history  # Should be empty []
```

### Expected Behaviors

**Critical High (RMS >= 0.8)**:
- Selects random patch from [10, 11, 12, 13, 14]
- Sets state to `:loud`
- Clears metrics history
- Updates last_action_timestamp

**Critical Low (RMS <= 0.05)**:
- Selects random patch from [1, 2, 3, 4, 5]
- Sets state to `:quiet`
- Clears metrics history
- Updates last_action_timestamp

**Comfort Zone (0.2 <= RMS <= 0.5)**:
- No immediate action
- Accumulates history
- If stable for 30 seconds with low variance, triggers random patch

**Anti-Stasis**:
- Requires 30 samples in history
- Variance must be < 0.02
- Time since last action must be >= 30,000ms
- Selects random patch from [20, 21, 22, 23, 24, 25, 26, 27, 28, 29]
- Clears history after triggering

### Troubleshooting

**Issue**: Can't run mix test
**Solution**: Install libmnl-dev or use the manual test script

**Issue**: State doesn't update
**Solution**: Make sure to add `Process.sleep(10)` after sending metrics to allow GenServer to process

**Issue**: Anti-stasis doesn't trigger
**Solution**: Check that you have 30 samples, variance is low, and enough time has passed
