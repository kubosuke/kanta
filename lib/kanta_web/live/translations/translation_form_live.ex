defmodule KantaWeb.Translations.TranslationFormLive do
  use KantaWeb, :live_view

  alias Kanta.Translations
  alias KantaWeb.Translations.{DomainsTabBar, MessagesTable}

  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-4">
        <%= header(assigns) %>
      </div>
      <div class="mb-4">
        <div class="mt-4">
          <label for="original_text" class="block text-sm font-medium text-gray-700">Original text</label>
          <div class="mt-1">
            <input value={@translation.original_text} disabled type="text" name="original_text" id="original_text" class="bg-gray-50 shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md" placeholder="">
          </div>
        </div>
        <div class="mt-4">
          <label for="translated_text" class="block text-sm font-medium text-gray-700">Translated text</label>
          <div class="mt-1">
            <input phx-keyup="keyup" value={@translation.translated_text} type="text" name="translated_text" id="translated_text" class="shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md" placeholder="">
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, %{"locale_id" => locale_id, "message_id" => message_id}, socket) do
    locale = Translations.get_locale(locale_id)
    message = Translations.get_message(message_id)

    translation =
      Translations.get_singular_translation_by(%{
        "filter" => %{
          "message_id" => message_id,
          "locale_id" => locale_id
        }
      })

    socket =
      socket
      |> assign(:locale, locale)
      |> assign(:message, message)
      |> assign(:translation, translation)

    {:ok, socket}
  end

  def handle_event("keyup", %{"value" => translated}, socket) do
    {:noreply,
     socket
     |> assign(:translated, translated)
     |> assign(:saved?, false)}
  end

  def handle_event("save", _event, socket) do
    %{
      assigns: %{
        locale: locale,
        translation: translation,
        translated: translated
      }
    } = socket

    translated = String.trim(translated)

    Translations.update_singular_translation(translation.id, %{"translated_text" => translated})

    {:noreply,
     push_redirect(socket, to: "/kanta" <> Routes.translation_path(socket, :index, locale.id))}
  end

  def handle_event("navigate", %{"to" => to}, socket) do
    {:noreply, push_redirect(socket, to: "/kanta" <> to)}
  end

  def header(assigns) do
    ~H"""
    <div>
      <div>
        <nav class="sm:hidden" aria-label="Back">
          <a href="#" class="flex items-center text-sm font-medium text-gray-400 hover:text-gray-200">
            <svg class="flex-shrink-0 -ml-1 mr-1 h-5 w-5 text-gray-500" x-description="Heroicon name: solid/chevron-left" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path fill-rule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd"></path>
            </svg>
            Back
          </a>
        </nav>
        <nav class="hidden sm:flex" aria-label="Breadcrumb">
          <ol class="flex items-center space-x-4">
            <li>
              <div>
                <a phx-click="navigate" phx-value-to={Routes.locale_path(@socket, :index)} class="cursor-pointer text-sm font-medium text-gray-400 hover:text-gray-200">Locales</a>
              </div>
            </li>
            <li>
              <div class="flex items-center">
                <svg class="flex-shrink-0 h-5 w-5 text-gray-500" x-description="Heroicon name: solid/chevron-right" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"></path>
                </svg>
                <a phx-click="navigate" phx-value-to={Routes.translation_path(@socket, :index, @locale.id)} class="cursor-pointer ml-4 text-sm font-medium text-gray-400 hover:text-gray-200"><%= @locale.name %></a>
              </div>
            </li>
            <li>
              <div class="flex items-center">
                <svg class="flex-shrink-0 h-5 w-5 text-gray-500" x-description="Heroicon name: solid/chevron-right" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"></path>
                </svg>
                <a href="#" aria-current="page" class="cursor-pointer ml-4 text-sm font-medium text-gray-400 hover:text-gray-200"><%= @message.msgid %></a>
              </div>
            </li>
          </ol>
        </nav>
      </div>
      <div class="mt-2 md:flex md:items-center md:justify-between">
        <div class="flex-1 min-w-0">
          <h2 class="text-2xl font-bold leading-7 text-primary-dark sm:text-3xl sm:truncate">
            Translating '<%= @message.msgid %>' to '<%= @locale.name %>'
          </h2>
        </div>
        <div class="mt-4 flex-shrink-0 flex md:mt-0 md:ml-4">
          <button phx-click="save" type="button" class="ml-3 inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-500 hover:bg-indigo-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-800 focus:ring-indigo-500">
            Save
          </button>
        </div>
      </div>
    </div>
    """
  end
end