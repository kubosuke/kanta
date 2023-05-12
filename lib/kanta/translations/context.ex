defmodule Kanta.Translations.Context do
  use Ecto.Schema
  import Ecto.Changeset

  alias Kanta.Translations.Message

  schema "kanta_contexts" do
    field :name, :string
    field :description, :string
    field :color, :string

    has_many :messages, Message
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :description, :color])
    |> validate_required([:name])
  end
end