defmodule Kanta.Backend do
  @moduledoc """
  Kanta.Backend is a module that provides an enhanced Gettext backend with database support.

  It extends the standard Gettext functionality by:
  1. First checking for translations in the database
  2. Falling back to PO file translations if not found in the database

  ## Usage

  ```elixir
  defmodule MyApp.Gettext do
    use Kanta.Backend, otp_app: :my_app
  end
  ```

  ## Options

  * `:otp_app` - The OTP application that contains the backend
  * `:priv` - The directory where the translations are stored (defaults to "priv/YOUR_MODULE")
  * `:kanta_adapter` - The adapter module to use for database lookups (defaults to `Kanta.Backend.Adapter.CachedDB`)

  it also accepts all the Gettext.Backend options. See the official Gettext documentation for more details.


  """
  alias Kanta.Utils.ModuleFolder
  require Logger

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      require Logger
      @flag_file Path.join([Mix.Project.build_path(), "kanta_recompile", ".gettext_recompiled"])
      @adapter Keyword.get(opts, :kanta_adapter, Kanta.Backend.Adapter.CachedDB)
      opts_with_priv =
        opts
        |> Keyword.drop([:kanta_adapter])
        |> Keyword.put_new(:priv, "priv/#{ModuleFolder.safe_folder_name(__MODULE__)}")

      # Main backend uses an empty priv so every lookup goes to handle_missing_translation,
      # giving order: Kanta -> PO (via fallback) -> for non-en: en Kanta -> en PO -> msgid.
      opts_main_backend = Keyword.put(opts_with_priv, :priv, opts_with_priv[:priv] <> "_kanta_lookup")

      # Generate fallback Gettext backend from PO files (real priv)
      use Kanta.Backend.GettextFallback, opts_with_priv

      # When `mix gettext extract` create POT/PO files based on this backend usage (ex. getext(...) call) across the application codebase.
      if Gettext.Extractor.extracting?() do
        use Gettext.Backend, opts_main_backend

        Kanta.Utils.GettextRecompiler.setup_recompile_flag(@flag_file)
      else
        use Gettext.Backend, opts_main_backend
      end

      def __mix_recompile__?() do
        Kanta.Utils.GettextRecompiler.needs_recompile?(@flag_file)
      end

      def __gettext__(:known_locales) do
        backend = fallback_backend()
        Gettext.known_locales(backend)
      end

      def handle_missing_translation(locale, domain, msgctxt, msgid, bindings) do
        # 1. Kanta for requested locale
        case @adapter.lgettext(locale, domain, msgctxt, msgid, bindings) do
          {:ok, translation} ->
            {:ok, translation}

          {:error, :not_found} ->
            # 2. PO for requested locale
            backend = fallback_backend()

            case backend.lgettext(locale, domain, msgctxt, msgid, bindings) do
              {:ok, translation} ->
                {:ok, translation}

              {:default, _} when locale != "en" ->
                # 3. For non-en: en Kanta, then en PO, then msgid
                try_en_fallback_singular(domain, msgctxt, msgid, bindings, backend)

              result ->
                result
            end
        end
      end

      def handle_missing_plural_translation(
            locale,
            domain,
            msgctxt,
            msgid,
            msgid_plural,
            n,
            bindings
          ) do
        # 1. Kanta for requested locale
        case @adapter.lngettext(
               locale,
               domain,
               msgctxt,
               msgid,
               msgid_plural,
               n,
               bindings
             ) do
          {:ok, translation} ->
            {:ok, translation}

          {:error, :not_found} ->
            # 2. PO for requested locale
            backend = fallback_backend()

            case backend.lngettext(
                   locale,
                   domain,
                   msgctxt,
                   msgid,
                   msgid_plural,
                   n,
                   bindings
                 ) do
              {:ok, translation} ->
                {:ok, translation}

              {:default, _} when locale != "en" ->
                # 3. For non-en: en Kanta, then en PO, then msgid
                try_en_fallback_plural(
                  domain,
                  msgctxt,
                  msgid,
                  msgid_plural,
                  n,
                  bindings,
                  backend
                )

              result ->
                result
            end
        end
      end

      defp try_en_fallback_singular(domain, msgctxt, msgid, bindings, backend) do
        case @adapter.lgettext("en", domain, msgctxt, msgid, bindings) do
          {:ok, translation} ->
            {:ok, translation}

          {:error, :not_found} ->
            case backend.lgettext("en", domain, msgctxt, msgid, bindings) do
              {:ok, translation} -> {:ok, translation}
              _ -> {:default, msgid}
            end
        end
      end

      defp try_en_fallback_plural(
             domain,
             msgctxt,
             msgid,
             msgid_plural,
             n,
             bindings,
             backend
           ) do
        case @adapter.lngettext(
               "en",
               domain,
               msgctxt,
               msgid,
               msgid_plural,
               n,
               bindings
             ) do
          {:ok, translation} ->
            {:ok, translation}

          {:error, :not_found} ->
            case backend.lngettext(
                   "en",
                   domain,
                   msgctxt,
                   msgid,
                   msgid_plural,
                   n,
                   bindings
                 ) do
              {:ok, translation} -> {:ok, translation}
              _ ->
                selected_msgid = if n == 1, do: msgid, else: msgid_plural
                {:default, selected_msgid}
            end
        end
      end

      defoverridable handle_missing_translation: 5, handle_missing_plural_translation: 7

      defp fallback_backend() do
        Module.concat(__MODULE__, GettextFallbackBackend)
      end
    end
  end
end
