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

### Remote access to target device

Use the ht-mcp server for interactive SSH sessions to the target device:

```elixir
# Create an SSH session (opens live terminal preview in browser)
mcp__ht-mcp__ht_create_session(command: ["ssh", "nerves.local"], enableWebServer: true)

# Take a snapshot to see current terminal state
mcp__ht-mcp__ht_take_snapshot(sessionId: "session-id")

# Send commands to the terminal
mcp__ht-mcp__ht_send_keys(sessionId: "session-id", keys: ["cmd(\"arecord -l\")", "Enter"])

# Execute commands directly and get output
mcp__ht-mcp__ht_execute_command(sessionId: "session-id", command: "ls /dev/snd")
```

The live terminal preview URL is provided when creating the session.

## Testing

This project uses a backend abstraction pattern to enable testing on host
without hardware.

### Running tests

```bash
# Run all tests on host (default)
mix test

# Run specific test file
mix test test/path/to/test.exs

# Run integration tests only
mix test test/integration/

# On target hardware with real devices (when needed)
MIX_TARGET=rpi5 mix test --include target_only
```

### Test types

- **Pure functions**: AudioAnalysis tests run on both host and target
- **GenServer unit tests**: Use backend abstractions (InMemory MIDI, File audio)
- **Integration tests**: Deterministic tests that send messages directly to
  ControlLoop
- **Target-only tests**: Tagged with `@tag :target_only`, require real hardware

The test suite automatically excludes `:target_only` tests when running on host.
See `test/test_helper.exs` for configuration details.

## Task management

- use the backlog CLI tool via the project-manager-backlog agent for task
  tracking
- use the elixir-ash-phoenix-developer agent for Elixir-specific implementation
  work (note: this project doesn't use Ash or Phoenix, but the agent has strong
  Elixir expertise)

<!-- usage-rules-start -->
<!-- usage-rules-header -->
# Usage Rules

**IMPORTANT**: Consult these usage rules early and often when working with the packages listed below.
Before attempting to use any of these packages or to discover if you should use them, review their
usage rules to understand the correct patterns, conventions, and best practices.
<!-- usage-rules-header-end -->

<!-- igniter-start -->
## igniter usage
_A code generation and project patching framework_

@deps/igniter/usage-rules.md
<!-- igniter-end -->
<!-- usage_rules-start -->
## usage_rules usage
_A dev tool for Elixir projects to gather LLM usage rules from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```


<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
# Elixir Core Usage Rules

## Pattern Matching
- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps

## Error Handling
- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid
- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design
- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark.
- Names like `is_thing` should be reserved for guards

## Data Structures
- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing
- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
# OTP Usage Rules

## GenServer Best Practices
- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication
- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance
- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async
- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->
