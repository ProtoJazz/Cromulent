defmodule CromulentWeb.UserSettingsLive do
  use CromulentWeb, :live_view

  alias Cromulent.Accounts

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Settings
      <:subtitle>Manage your account email address and password settings</:subtitle>
    </.header>

    <div class="space-y-12 divide-y">
      <div>
        <.simple_form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input field={@email_form[:email]} type="email" label="Email" required />
          <.input
            field={@email_form[:current_password]}
            name="current_password"
            id="current_password_for_email"
            type="password"
            label="Current password"
            value={@email_form_current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Email</.button>
          </:actions>
        </.simple_form>
      </div>
      <div>
        <.simple_form
          for={@password_form}
          id="password_form"
          action={~p"/users/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <input
            name={@password_form[:email].name}
            type="hidden"
            id="hidden_user_email"
            value={@current_email}
          />
          <.input field={@password_form[:password]} type="password" label="New password" required />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Confirm new password"
          />
          <.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current_password_for_password"
            value={@current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Password</.button>
          </:actions>
        </.simple_form>
      </div>
      <%!-- Voice Settings --%>
      <div id="voice-settings-hook" phx-hook="VoiceSettings">
        <h3 class="text-lg font-medium text-gray-900 dark:text-white mt-4">Voice Settings</h3>

        <form phx-submit="save_voice_prefs" class="mt-4 space-y-6">
          <%!-- Input Mode --%>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Input Mode</label>
            <div class="flex gap-4">
              <label class="flex items-center gap-2 cursor-pointer">
                <input type="radio" name="voice_mode" value="ptt"
                  checked={@voice_prefs.voice_mode == "ptt"}
                  class="text-indigo-600 focus:ring-indigo-500" />
                <span class="text-sm text-gray-700 dark:text-gray-300">Push to Talk</span>
              </label>
              <label class="flex items-center gap-2 cursor-pointer">
                <input type="radio" name="voice_mode" value="vad"
                  checked={@voice_prefs.voice_mode == "vad"}
                  class="text-indigo-600 focus:ring-indigo-500" />
                <span class="text-sm text-gray-700 dark:text-gray-300">Voice Activity</span>
              </label>
            </div>
          </div>

          <%!-- VAD Sensitivity (shown always; user can configure even before switching mode) --%>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Voice Activity Sensitivity
              <span class="text-xs text-gray-500 ml-1">(only used in Voice Activity mode)</span>
            </label>
            <div class="flex items-center gap-3">
              <span class="text-xs text-gray-500">Most sensitive</span>
              <input type="range" name="vad_threshold"
                min="-60" max="-20" step="1"
                value={@voice_prefs.vad_threshold}
                class="flex-1 h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer dark:bg-gray-700" />
              <span class="text-xs text-gray-500">Least sensitive</span>
            </div>
            <p class="text-xs text-gray-500 mt-1">Current: {@voice_prefs.vad_threshold} dBFS</p>
          </div>

          <%!-- Microphone device picker --%>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Microphone</label>
            <select name="mic_device_id"
              class="block w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white text-sm">
              <option value="">Default microphone</option>
              <%= for device <- @audio_inputs do %>
                <option value={device["id"]} selected={@voice_prefs.mic_device_id == device["id"]}>
                  {device["label"]}
                </option>
              <% end %>
            </select>
            <p :if={@audio_inputs == []} class="text-xs text-gray-500 mt-1">
              Click "Test Mic" to load available devices.
            </p>
          </div>

          <%!-- Speaker device picker --%>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Speaker</label>
            <select name="speaker_device_id"
              class="block w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-white text-sm">
              <option value="">Default speaker</option>
              <%= for device <- @audio_outputs do %>
                <option value={device["id"]} selected={@voice_prefs.speaker_device_id == device["id"]}>
                  {device["label"]}
                </option>
              <% end %>
            </select>
          </div>

          <%!-- Mic test --%>
          <div>
            <button type="button" id="test-mic-btn"
              class="px-4 py-2 bg-gray-700 text-white rounded-md text-sm font-medium hover:bg-gray-600">
              Test Mic
            </button>
            <div id="mic-level-bar" class="mt-2 h-3 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden hidden">
              <div id="mic-level-fill" class="h-full bg-green-500 transition-none" style="width: 0%"></div>
            </div>
            <p id="mic-level-label" class="text-xs text-gray-500 mt-1 hidden">Speak to test your microphone</p>
          </div>

          <div>
            <button type="submit"
              class="px-4 py-2 bg-indigo-600 text-white rounded-md text-sm font-medium hover:bg-indigo-500">
              Save Voice Settings
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)
    voice_prefs = Accounts.get_voice_prefs(user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:voice_prefs, voice_prefs)
      |> assign(:audio_inputs, [])
      |> assign(:audio_outputs, [])

    {:ok, socket}
  end

  # JS hook reports available devices
  def handle_event("devices_loaded", %{"inputs" => inputs, "outputs" => outputs}, socket) do
    {:noreply, socket |> assign(:audio_inputs, inputs) |> assign(:audio_outputs, outputs)}
  end

  # User saves voice preferences
  def handle_event("save_voice_prefs", params, socket) do
    attrs = %{
      "voice_mode"        => params["voice_mode"],
      "vad_threshold"     => String.to_integer(params["vad_threshold"] || "-40"),
      "mic_device_id"     => if(params["mic_device_id"] == "", do: nil, else: params["mic_device_id"]),
      "speaker_device_id" => if(params["speaker_device_id"] == "", do: nil, else: params["speaker_device_id"])
    }

    case Accounts.update_user_voice_prefs(socket.assigns.current_user, attrs) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Voice preferences saved.")
         |> assign(:voice_prefs, Accounts.get_voice_prefs(updated_user))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save voice preferences.")}
    end
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end
end
