defmodule Lokalio.Repo.Migrations.CreateBusinesses do
  use Ecto.Migration

  def change do
    create table(:businesses) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :address, :string
      add :phone, :string
      add :logo_url, :string
      # resto, bar, boutique, quincaillerie...
      add :category, :string
      # réduction par défaut en %
      add :discount_rate, :decimal
      # token unique
      add :qr_code_token, :string, null: false
      add :is_active, :boolean, default: true
      add :is_verified, :boolean, default: false
      # PostGIS pour géolocalisation
      add :location, :geometry, null: true
      add :latitude, :float
      add :longitude, :float
      timestamps()
    end

    create unique_index(:businesses, [:qr_code_token])
    create index(:businesses, [:user_id])
  end
end
