defmodule KantaWeb.Translations.MessagesTable do
  use KantaWeb, :live_component

  alias Kanta.Translations.{Message, SingularTranslation}

  def update(socket, assigns) do
    {:ok, assign(assigns, socket)}
  end

  def handle_event("edit_message", %{"id" => id}, socket) do
    {:noreply,
     push_navigate(socket,
       to: path(socket, ~p"/kanta/locales/#{socket.assigns.locale.id}/translations/#{id}")
     )}
  end

  def is_translated(%Message{message_type: :singular} = message, locale, source) do
    case Enum.find(message.singular_translations, &(&1.locale_id == locale.id)) do
      nil ->
        false

      %SingularTranslation{} = translation ->
        case get_in(translation, [Access.key!(source)]) do
          nil -> false
          "" -> false
          _text -> true
        end
    end
  end

  def is_translated(%Message{message_type: :plural} = message, locale, source) do
    case Enum.filter(message.plural_translations, &(&1.locale_id == locale.id)) do
      [] ->
        false

      translations ->
        translations
        |> Enum.map(fn translation ->
          case get_in(translation, [Access.key!(source)]) do
            nil ->
              false

            "" ->
              false

            _text ->
              true
          end
        end)
    end
  end

  def translated_text(assigns, %Message{message_type: :singular} = message),
    do: translated_singular_text(assigns, message, :translated_text)

  def translated_text(assigns, %Message{message_type: :plural} = message),
    do: translated_plural_text(assigns, message, :translated_text)

  def original_text(assigns, %Message{message_type: :singular} = message),
    do: translated_singular_text(assigns, message, :original_text)

  def original_text(assigns, %Message{message_type: :plural} = message),
    do: translated_plural_text(assigns, message, :original_text)

  def translated_singular_text(assigns, message, source) do
    case Enum.find(message.singular_translations, &(&1.locale_id == assigns.locale.id)) do
      nil ->
        "Missing"

      %SingularTranslation{} = translation ->
        case get_in(translation, [Access.key!(source)]) do
          nil -> "Missing"
          "" -> "Missing"
          text -> if String.length(text) > 45, do: String.slice(text, 0..45) <> "... ", else: text
        end
    end
  end

  def translated_plural_text(assigns, message, source) do
    translations =
      case Enum.filter(message.plural_translations, &(&1.locale_id == assigns.locale.id)) do
        [] ->
          []

        translations ->
          translations
          |> Enum.map(fn translation ->
            text =
              case get_in(translation, [Access.key!(source)]) do
                nil ->
                  "Missing"

                "" ->
                  "Missing"

                text ->
                  if String.length(text) > 45, do: String.slice(text, 0..45) <> "... ", else: text
              end

            %{index: translation.nplural_index, text: text}
          end)
      end

    assigns = assign(assigns, :translations, translations)

    if length(translations) > 0 do
      ~H"""
        <div>
          <%= for plural_translation <- @translations do %>
            <div>
              Plural form <%= plural_translation[:index] %>: <%= plural_translation[:text] %>
            </div>
          <% end %>
        </div>
      """
    else
      "Missing"
    end
  end
end