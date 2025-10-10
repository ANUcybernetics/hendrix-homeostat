# Hendrix homeostat project

A Nerves-based cybernetic audio system inspired by W. Ross Ashby's homeostat,
running on Raspberry Pi 5 to control a guitar feedback loop system.

## Project architecture

- **Target platform**: Raspberry Pi 5 (Nerves embedded system)
- **Audio interface**: Presonus Revelator io24 (USB audio/MIDI)
- **Control output**: MIDI commands to Boss RC-600 loop station
- **Audio flow**: guitar pickup → audio analysis → MIDI patch changes → effects
  loop

## Key implementation points

### Elixir/Nerves patterns

- use GenServers for audio monitoring and control logic
- leverage OTP supervision trees for fault tolerance
- use Nerves-specific libraries for audio/MIDI interface
- target is `:rpi5`, development target is `:host`

### Audio processing

- monitor RMS level, spectral centroid, and stability metrics
- implement threshold-based decision making (critical high >0.8, comfort zone
  0.2-0.5, critical low <0.05)
- balance between real-time responsiveness and system stability

### Control philosophy

- system should find its own equilibrium, not be micromanaged
- patch changes are discrete events triggered by threshold violations
- anti-stasis mechanism prevents system from becoming too stable
- three patch banks: boost (for quiet states), dampen (for loud states), random
  (for perturbation)

## Development workflow

- always set `MIX_TARGET=rpi5` for target builds, or use `:host` for local
  testing
- use `mix firmware` and `mix burn` for deployment to hardware
- test audio processing logic on `:host` target when possible before burning to
  device

## Task management

- use the backlog CLI tool via the project-manager-backlog agent for task
  tracking
- use the elixir-ash-phoenix-developer agent for Elixir-specific implementation
  work (note: this project doesn't use Ash or Phoenix, but the agent has strong
  Elixir expertise)
