defmodule HendrixHomeostatWeb.DashboardLiveTest do
  use HendrixHomeostat.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "dashboard page" do
    test "displays dashboard title", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "Hendrix Homeostat Dashboard"
    end

    test "displays audio metrics section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "Audio Metrics"
      assert html =~ "RMS Level"
      assert html =~ "Zero Crossing Rate"
      assert html =~ "Peak"
    end

    test "displays control state section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "Control State"
      assert html =~ "Stability Attempts"
      assert html =~ "Last Action"
    end

    test "displays track parameters section", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "Track Parameters (Ultrastability)"
      assert html =~ "Track 1 (Experimental)"
      assert html =~ "Track 2 (Anchor)"
    end

    test "displays initial values", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      # Initial RMS should be 0.0
      assert html =~ "0.0"
      # Initial stability attempts should be 0
      assert html =~ ">0</dd>"
      # Initial track volumes should be 75
      assert html =~ ">75</dd>"
      # Initial track 1 speed should be 112
      assert html =~ ">112</dd>"
    end

    test "updates when control state is broadcast", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Simulate a control state update
      Phoenix.PubSub.broadcast(
        HendrixHomeostat.PubSub,
        "control_loop",
        {:control_state,
         %{
           current_metrics: %{rms: 0.456, zcr: 123.45, peak: 0.789},
           track1_params: %{volume: 100, speed: 96},
           track2_params: %{volume: 50},
           stability_attempts: 3
         }}
      )

      # The view should update with the new values
      assert render(view) =~ "0.456"
      assert render(view) =~ "123.45"
      assert render(view) =~ "0.789"
      assert render(view) =~ ">3</dd>"
      assert render(view) =~ ">100</dd>"
      assert render(view) =~ ">96</dd>"
      assert render(view) =~ ">50</dd>"
    end
  end
end
