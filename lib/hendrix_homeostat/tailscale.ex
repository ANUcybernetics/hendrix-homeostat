defmodule HendrixHomeostat.Tailscale do
  @moduledoc """
  Manages the Tailscale daemon and connection.
  Starts tailscaled and connects to the tailnet using the configured auth key.
  """
  use GenServer
  require Logger

  @compile {:no_warn_undefined, MuonTrap.Daemon}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Only start on target hardware
    if Application.get_env(:hendrix_homeostat, :target) == :rpi5 do
      Logger.info("Starting Tailscale daemon...")
      start_tailscale()
      {:ok, %{}}
    else
      Logger.info("Skipping Tailscale on host target")
      {:ok, %{}}
    end
  end

  defp start_tailscale do
    # Use writable directories (/root is mounted rw on Nerves)
    state_dir = "/root/tailscale"
    socket_dir = "/tmp/tailscale"

    # Ensure directories exist
    File.mkdir_p!(state_dir)
    File.mkdir_p!(socket_dir)

    # Start tailscaled daemon using MuonTrap (non-blocking)
    Logger.info("Starting tailscaled daemon...")

    {:ok, _pid} =
      MuonTrap.Daemon.start_link(
        "/usr/sbin/tailscaled",
        [
          "--state=#{state_dir}/tailscaled.state",
          "--socket=#{socket_dir}/tailscaled.sock",
          "--port=41641"
        ],
        []
      )

    # Give tailscaled a moment to start
    Process.sleep(2000)

    # Get auth key from file and hostname from config
    auth_key = read_auth_key_from_file()
    hostname = Application.get_env(:hendrix_homeostat, :tailscale_hostname, "jimi")

    if auth_key && auth_key != "" do
      Logger.info("Connecting to Tailscale network as #{hostname}...")

      case System.cmd(
             "/usr/bin/tailscale",
             [
               "--socket=#{socket_dir}/tailscaled.sock",
               "up",
               "--authkey=#{auth_key}",
               "--hostname=#{hostname}",
               "--accept-routes"
             ],
             stderr_to_stdout: true
           ) do
        {output, 0} ->
          Logger.info("Tailscale connected successfully: #{output}")

        {output, code} ->
          Logger.error("Failed to connect to Tailscale (exit #{code}): #{output}")
      end
    else
      Logger.warning("No Tailscale auth key configured, skipping connection")
    end
  end

  defp read_auth_key_from_file do
    auth_file = "/etc/default/tailscale-up"

    if File.exists?(auth_file) do
      case File.read(auth_file) do
        {:ok, content} ->
          # Parse the file to extract TAILSCALE_AUTH_KEY value
          content
          |> String.split("\n")
          |> Enum.find_value(fn line ->
            case Regex.run(~r/^TAILSCALE_AUTH_KEY="(.+)"$/, String.trim(line)) do
              [_, key] -> key
              _ -> nil
            end
          end)

        {:error, reason} ->
          Logger.error("Failed to read Tailscale auth key file: #{inspect(reason)}")
          nil
      end
    else
      Logger.warning("Tailscale auth key file not found at #{auth_file}")
      nil
    end
  end
end
