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
       state: :idle,
       track1_volume: 75,
       track1_speed: 112,
       track2_volume: 75,
       last_action: nil,
       stability_attempts: 0
     )}
  end

  @impl true
  def handle_info({:control_state, state}, socket) do
    {:noreply,
     assign(socket,
       rms: get_in(state, [:current_metrics, :rms]) || 0.0,
       zcr: get_in(state, [:current_metrics, :zcr]) || 0.0,
       peak: get_in(state, [:current_metrics, :peak]) || 0.0,
       track1_volume: get_in(state, [:track1_params, :volume]) || 75,
       track1_speed: get_in(state, [:track1_params, :speed]) || 112,
       track2_volume: get_in(state, [:track2_params, :volume]) || 75,
       stability_attempts: state[:stability_attempts] || 0
     )}
  end

  def handle_info({:action_taken, action}, socket) do
    {:noreply, assign(socket, last_action: inspect(action))}
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
              <dt class="text-sm text-gray-600">Stability Attempts</dt>
              <dd class="text-2xl font-mono"><%= @stability_attempts %></dd>
            </div>
            <div>
              <dt class="text-sm text-gray-600">Last Action</dt>
              <dd class="text-sm font-mono break-all"><%= @last_action || "None" %></dd>
            </div>
          </dl>
        </.card>
      </div>

      <.card>
        <h2 class="text-xl font-semibold mb-4">Track Parameters (Ultrastability)</h2>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <h3 class="font-medium mb-2">Track 1 (Experimental)</h3>
            <dl class="space-y-1">
              <div>
                <dt class="text-sm text-gray-600">Volume</dt>
                <dd class="font-mono"><%= @track1_volume %></dd>
              </div>
              <div>
                <dt class="text-sm text-gray-600">Speed</dt>
                <dd class="font-mono"><%= @track1_speed %></dd>
              </div>
            </dl>
          </div>
          <div>
            <h3 class="font-medium mb-2">Track 2 (Anchor)</h3>
            <dl class="space-y-1">
              <div>
                <dt class="text-sm text-gray-600">Volume</dt>
                <dd class="font-mono"><%= @track2_volume %></dd>
              </div>
            </dl>
          </div>
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
