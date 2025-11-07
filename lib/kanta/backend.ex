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
  * `:fallback_locale` - The locale to fallback to when a translation is not found (defaults to "en")

  it also accepts all the Gettext.Backend options. See the official Gettext documentation for more details.


  """
  alias Kanta.Utils.ModuleFolder
  require Logger

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      require Logger
      @flag_file Path.join([Mix.Project.build_path(), "kanta_recompile", ".gettext_recompiled"])
      @adapter Keyword.get(opts, :kanta_adapter, Kanta.Backend.Adapter.CachedDB)
      @fallback_locale Keyword.get(opts, :fallback_locale, "en")
      opts = Keyword.drop(opts, [:kanta_adapter, :fallback_locale])
      # Generate fallback Gettext backend form PO files
      use Kanta.Backend.GettextFallback, opts

      # When `mix gettext extract` create POT/PO files based on this backend usage (ex. getext(...) call) across the application codebase.
      if Gettext.Extractor.extracting?() do
        use Gettext.Backend, opts

        Kanta.Utils.GettextRecompiler.setup_recompile_flag(@flag_file)
      else
        opts = Keyword.merge(opts, priv: "priv/#{ModuleFolder.safe_folder_name(__MODULE__)}")
        use Gettext.Backend, opts
      end

      def __mix_recompile__?() do
        Kanta.Utils.GettextRecompiler.needs_recompile?(@flag_file)
      end

      def __gettext__(:known_locales) do
        backend = fallback_backend()
        Gettext.known_locales(backend)
      end

      def handle_missing_translation(locale, domain, msgctxt, msgid, bindings) do
        case @adapter.lgettext(
               locale,
               domain,
               msgctxt,
               msgid,
               bindings
             ) do
          {:ok, translation} ->
            {:ok, translation}

          {:error, :not_found} ->
            backend = fallback_backend()
            po_result = backend.lgettext(locale, domain, msgctxt, msgid, bindings)

            # If translation not found in PO files and locale is not the fallback locale,
            # try to get translation from fallback locale
            if locale != @fallback_locale do
              handle_missing_translation(@fallback_locale, domain, msgctxt, msgid, bindings)
            else
              po_result
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
            backend = fallback_backend()

            po_result =
              backend.lngettext(
                locale,
                domain,
                msgctxt,
                msgid,
                msgid_plural,
                n,
                bindings
              )

            # If translation not found in PO files and locale is not the fallback locale,
            # try to get translation from fallback locale
            if locale != @fallback_locale do
              handle_missing_plural_translation(
                @fallback_locale,
                domain,
                msgctxt,
                msgid,
                msgid_plural,
                n,
                bindings
              )
            else
              po_result
            end
        end
      end

      defp fallback_backend() do
        Module.concat(__MODULE__, GettextFallbackBackend)
      end
    end
  end
end
