defmodule Kanta.Translations.Message do
  use Ecto.Schema
  import Ecto.Changeset

  alias Kanta.Translations.{Domain, PluralTranslation, SingularTranslation}

  @all_fields ~w(msgid msgctxt domain_id)a
  @required_fields ~w(msgid)a

  schema "kanta_messages" do
    field :msgid, :string
    field :msgctxt, :string

    belongs_to :domain, Domain

    has_one :singular_translation, SingularTranslation
    has_many :plural_translations, PluralTranslation
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @all_fields)
    |> validate_required(@required_fields)

    # |> foreign_key_constraint(:domain_id)
  end
end