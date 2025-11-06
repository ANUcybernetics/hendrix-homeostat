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

    test "displays control state information", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "Control State"
      assert html =~ "Last Classification"
      assert html =~ "Transitions Tracked"
    end

    test "displays track volumes", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ "Track Volumes"
      assert html =~ "Track 1"
      assert html =~ "Track 2"
    end

    test "displays initial values", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      # Initial RMS should be 0.0
      assert html =~ "0.0"
      # Initial transition count should be 0
      assert html =~ ">0</dd>"
      # Initial track volumes should be 75
      assert html =~ ">75</dd>"
      # Initial classification should be Idle
      assert html =~ "Idle"
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
           transition_history: [{:too_loud, 123}],
           last_state: :too_loud,
           track1_volume: 100,
           track2_volume: 50
         }}
      )

      # The view should update with the new values
      assert render(view) =~ "0.456"
      assert render(view) =~ "123.45"
      assert render(view) =~ "0.789"
      assert render(view) =~ ">100</dd>"
      assert render(view) =~ ">50</dd>"
      assert render(view) =~ "Too loud"
      assert render(view) =~ ">1</dd>"
    end
  end
end
