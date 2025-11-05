# IEx configuration for Hendrix Homeostat
# This file is automatically loaded when starting IEx

# Convenient alias for runtime configuration
alias HendrixHomeostat.RuntimeConfig, as: RC

IO.puts("""

=== Hendrix Homeostat IEx Session ===

Convenient aliases:
  RC - RuntimeConfig module

Quick configuration commands:
  RC.get()                              # Show all current settings
  RC.set(:comfort_zone_max, 0.7)        # Make it louder
  RC.set(:comfort_zone_max, 0.3)        # Make it quieter
  RC.set(:min_action_interval, 5000)    # Slower changes (5 seconds)
  RC.update(%{comfort_zone_max: 0.6, min_action_interval: 3000})
  RC.reset()                            # Reset to defaults

Current settings:
#{inspect(HendrixHomeostat.RuntimeConfig.get(), pretty: true)}
""")
