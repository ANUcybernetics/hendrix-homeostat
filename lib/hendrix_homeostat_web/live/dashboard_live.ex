defmodule HendrixHomeostatWeb.DashboardLive do
  use HendrixHomeostatWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(HendrixHomeostat.PubSub, "control_loop")
    end

    {:ok,
     assign(socket,
       rms: 0.0,
       zcr: 0.0,
       peak: 0.0,
       last_state: :idle,
       transition_count: 0,
       track1_volume: 75,
       track2_volume: 75
     )}
  end

  @impl true
  def handle_info({:control_state, state}, socket) do
    metrics = Map.get(state, :current_metrics, %{})
    transitions = Map.get(state, :transition_history, [])

    {:noreply,
     assign(socket,
       rms: Map.get(metrics, :rms, 0.0),
       zcr: Map.get(metrics, :zcr, 0.0),
       peak: Map.get(metrics, :peak, 0.0),
       last_state: Map.get(state, :last_state, :idle),
       transition_count: transitions |> List.wrap() |> length(),
       track1_volume: Map.get(state, :track1_volume, 0),
       track2_volume: Map.get(state, :track2_volume, 0)
     )}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <h1 class="text-3xl font-bold mb-8">Hendrix Homeostat Dashboard</h1>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
        <.card>
          <h2 class="text-xl font-semibold mb-4">Audio Metrics</h2>
          <dl class="space-y-2">
            <div>
              <dt class="text-sm text-gray-600">RMS Level</dt>
              <dd class="text-2xl font-mono"><%= Float.round(@rms, 3) %></dd>
            </div>
            <div>
              <dt class="text-sm text-gray-600">Zero Crossing Rate</dt>
              <dd class="text-lg font-mono"><%= Float.round(@zcr, 2) %></dd>
            </div>
            <div>
              <dt class="text-sm text-gray-600">Peak</dt>
              <dd class="text-lg font-mono"><%= Float.round(@peak, 3) %></dd>
            </div>
          </dl>
        </.card>

        <.card>
          <h2 class="text-xl font-semibold mb-4">Control State</h2>
          <dl class="space-y-2">
            <div>
              <dt class="text-sm text-gray-600">Last Classification</dt>
              <dd class="text-xl font-mono">
                <%= Phoenix.Naming.humanize(@last_state) %>
              </dd>
            </div>
            <div>
              <dt class="text-sm text-gray-600">Transitions Tracked</dt>
              <dd class="text-lg font-mono"><%= @transition_count %></dd>
            </div>
          </dl>
        </.card>
      </div>

      <.card>
        <h2 class="text-xl font-semibold mb-4">Track Volumes</h2>
        <div class="grid grid-cols-2 gap-4">
          <dl class="space-y-1">
            <div>
              <dt class="text-sm text-gray-600">Track 1</dt>
              <dd class="font-mono"><%= @track1_volume %></dd>
            </div>
          </dl>
          <dl class="space-y-1">
            <div>
              <dt class="text-sm text-gray-600">Track 2</dt>
              <dd class="font-mono"><%= @track2_volume %></dd>
            </div>
          </dl>
        </div>
      </.card>

      <div class="mt-6 text-sm text-gray-600">
        <p>This dashboard displays the internal state of the Ashby-style ultrastable homeostat.</p>
        <p class="mt-2">The system maintains audio equilibrium through adaptive parameter changes.</p>
      </div>
    </div>
    """
  end
end
