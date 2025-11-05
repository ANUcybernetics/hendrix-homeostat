defmodule HendrixHomeostatWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :hendrix_homeostat

  @session_options [
    store: :cookie,
    key: "_hendrix_homeostat_key",
    signing_salt: "hendrix_homeostat_signing_salt",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: false
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if Mix.env() == :dev do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.CodeReloader)
    plug(Phoenix.LiveReloader)
  end

  plug(Plug.Static,
    at: "/",
    from: :hendrix_homeostat,
    gzip: false,
    only: HendrixHomeostatWeb.static_paths()
  )

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(HendrixHomeostatWeb.Router)
end
