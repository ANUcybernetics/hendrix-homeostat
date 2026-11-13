# Hendrix homeostat project

A Nerves-based cybernetic audio system inspired by W. Ross Ashby's homeostat,
running on Raspberry Pi 5 to control a guitar feedback loop system.

## Project architecture

- **Target platform**: Raspberry Pi 5 (Nerves embedded system)
- **Audio interface**: Presonus Revelator io24 (USB audio/MIDI)
- **Control output**: MIDI commands to Boss RC-600 loop station
- **Audio flow**: guitar pickup → audio analysis → MIDI track control → effects
  loop

## Key implementation points

### Elixir/Nerves patterns

- target is `:rpi5`, development target is `:host`; always specify one, e.g.
  `MIX_TARGET=host mise exec -- mix test`. Run mix through `mise exec --` so the
  Elixir/Erlang versions are right

### Audio processing

- monitor RMS level (root mean square - primary metric for control)
- also calculate zero-crossing rate and peak (not currently used in control)
- implement threshold-based decision making (critical high >0.8, comfort zone
  0.2-0.5, critical low <0.05)

### Control philosophy: Ashby-style ultrastability

The system implements a **double feedback loop** inspired by W. Ross Ashby's
homeostat:

**First-order loop (homeostasis):**

- RMS too high (≥0.8) → stop random track (damping)
- RMS too low (≤0.05) → start recording (excitation)
- Stable too long → clear track (anti-stasis)
- Controls only tracks 1-2 for simplicity

**Second-order loop (ultrastability):**

- When first-order control fails (e.g., oscillating >10 times between extremes
  in 100 samples over 60 seconds)
- System randomly changes track parameters:
  - Track 1: volume (5 levels) + speed (5 levels) - the "experimental" track
  - Track 2: volume (5 levels) only - the "anchor" track
- This creates 125 possible configurations to explore
- Like Ashby's uniselector, system searches for parameter combinations that
  achieve equilibrium
- Asymmetry aids stability (functional differentiation)

## Development workflow

- use `mise exec -- mix firmware` and `mise exec -- mix burn` (with
  `MIX_TARGET=rpi5`) for deployment to hardware

## Testing

This project uses a backend abstraction pattern to enable testing on host
without hardware.

### Running tests on host

Most tests run on host without requiring hardware:

```bash
# Run all tests on host (default, works in standard shell)
MIX_TARGET=host mise exec -- mix test

# Run specific test file
MIX_TARGET=host mise exec -- mix test test/path/to/test.exs

# Run integration tests only
MIX_TARGET=host mise exec -- mix test test/integration/
```

### Running tests on target device

Target-only tests require real hardware and must be run on the Raspberry Pi. Use
the ht-mcp server for interactive SSH sessions:

```bash
# On target hardware with real devices
MIX_TARGET=rpi5 mise exec -- mix test --include target_only
```

To run commands (tests, IEx sessions, etc.) on the target, use ht-mcp to open an
SSH session to `jimi.local` and run them there under `mise exec --`.

### Test types

- **Pure functions**: AudioAnalysis tests run on both host and target
- **GenServer unit tests**: Use backend abstractions (InMemory MIDI, File audio)
- **Integration tests**: Deterministic tests that send messages directly to
  ControlLoop
- **Target-only tests**: Tagged with `@tag :target_only`, require real hardware

The test suite automatically excludes `:target_only` tests when running on host.
See `test/test_helper.exs` for configuration details.

## Task management

- use the `backlog` CLI for task tracking
