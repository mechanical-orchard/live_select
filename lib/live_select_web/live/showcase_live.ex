defmodule LiveSelectWeb.ShowcaseLive do
  use LiveSelectWeb, :live_view

  @max_events 3

  # valid params with default values
  @params [
    form_name: "my_form",
    field_name: "live_select",
    msg_prefix: "live_select",
    search_term_min_length: 3,
    id: "my_form_live_select_component",
    style: :daisyui,
    container_class: nil,
    container_extra_class: "w-full",
    text_input_class: nil,
    text_input_extra_class: "w-full",
    text_input_selected_class: nil,
    dropdown_class: nil,
    dropdown_extra_class: "w-full",
    active_option_class: nil
  ]

  defmodule Render do
    @moduledoc false

    use Phoenix.Component

    def event(assigns) do
      cond do
        assigns[:event] ->
          ~H"""
            <p>
            def handle_event(
              <span class="text-success"><%= inspect(@event) %></span>, 
              <span class="text-primary"><%= inspect(@params) %></span>, 
              socket
            )
            </p>
          """

        assigns[:msg] ->
          ~H"""
            <p>
            def handle_info(
              <span class="text-success"><%= inspect(@msg) %></span>, 
              socket
            )
            </p>
          """
      end
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        events: [],
        new_event: false,
        params: @params
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    params = Map.reject(params, fn {_param, value} -> value == "" end)

    socket =
      socket
      |> assign(:form_name, (params["form_name"] || @params[:form_name]) |> String.to_atom())
      |> assign(:field_name, params["field_name"] || @params[:field_name])
      |> assign(:live_select_opts, live_select_opts(params))

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "update-settings",
        %{"settings" => settings},
        socket
      ) do
    socket =
      socket
      |> push_patch(to: Routes.live_path(socket, __MODULE__, settings))

    {:noreply, socket}
  end

  @impl true
  def handle_event(event, params, socket) do
    Process.send_after(self(), :clear_new_event, 1_000)

    {:noreply,
     assign(socket,
       events:
         [%{params: params, event: event} | socket.assigns.events] |> Enum.take(@max_events),
       new_event: true
     )}
  end

  @impl true
  def handle_info(:clear_new_event, socket) do
    {:noreply, assign(socket, :new_event, false)}
  end

  @impl true
  def handle_info(message, socket) do
    msg_prefix = socket.assigns.live_select_opts[:msg_prefix] || "live_select"
    change_msg = "#{msg_prefix}_change"

    case message do
      {^change_msg, %{text: text} = change_msg_body} ->
        LiveSelect.update(
          change_msg_body,
          change_handler().handle_change(text)
        )

        Process.send_after(self(), :clear_new_event, 1_000)

        {:noreply,
         assign(socket,
           events: [%{msg: message} | socket.assigns.events] |> Enum.take(@max_events),
           new_event: true
         )}

      _ ->
        {:noreply, socket}
    end
  end

  defp live_select_opts(params) do
    keys = Keyword.keys(@params) |> Enum.map(&to_string/1)

    params =
      params
      |> Map.take(keys)
      |> Keyword.new(fn {param, value} ->
        value =
          cond do
            param == "search_term_min_length" -> String.to_integer(value)
            param == "style" -> String.to_atom(value)
            true -> value
          end

        {String.to_atom(param), value}
      end)

    Enum.reduce(@params, params, fn {param, default}, params ->
      Keyword.put_new(params, param, default)
    end)
  end

  defp change_handler() do
    Application.get_env(:live_select, :change_handler) ||
      raise "you need to specify a :change_handler in your :live_select config"
  end
end
