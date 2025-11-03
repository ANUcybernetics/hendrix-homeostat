defmodule HendrixHomeostatWeb.CoreComponents do
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  def flash_group(assigns) do
    ~H"""
    <div id="flash-group">
      <.flash kind={:info} title="Success!" flash={@flash} />
      <.flash kind={:error} title="Error!" flash={@flash} />
    </div>
    """
  end

  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, required: true, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      role="alert"
      class={[
        "fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 shadow-md shadow-zinc-900/5",
        @kind == :info && "bg-emerald-50 text-emerald-800",
        @kind == :error && "bg-rose-50 text-rose-900"
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <span><%= @title %></span>
      </p>
      <p class="mt-2 text-sm leading-5"><%= msg %></p>
      <button
        type="button"
        class="group absolute top-1 right-1 p-2"
        aria-label="close"
        phx-click={JS.push("lv:clear-flash") |> JS.remove_class("fade-in", to: "##{@id}") |> hide("##{@id}")}
      >
        <span aria-hidden="true">×</span>
      </button>
    </div>
    """
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:translate-x-0", "opacity-0 translate-y-4 sm:translate-x-2"}
    )
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={["bg-white shadow rounded-lg p-6", @class]}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end
end
