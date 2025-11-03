import Config

# Configure the endpoint for testing
config :hendrix_homeostat, HendrixHomeostatWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_at_least_64_bytes_long_for_testing_purposes_only",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable lazy HTML parsing for LiveView tests
config :phoenix_live_view,
  enable_expensive_runtime_checks: true,
  lazy_html: LazyHTML
