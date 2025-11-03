defmodule HendrixHomeostat.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use HendrixHomeostatWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import HendrixHomeostat.ConnCase

      # The default endpoint for testing
      @endpoint HendrixHomeostatWeb.Endpoint
    end
  end

  setup _tags do
    # Start the endpoint for testing (PubSub is already started in test_helper.exs)
    start_supervised!(HendrixHomeostatWeb.Endpoint)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
