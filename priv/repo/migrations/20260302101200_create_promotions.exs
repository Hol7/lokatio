defmodule Lokalio.Repo.Migrations.CreatePromotions do
  use Ecto.Migration

  def change do
    create table(:promotions) do
      add :business_id, references(:businesses, on_delete: :delete_all), null: false
      add :title, :string
      add :description, :text
      add :discount_rate, :decimal
      add :starts_at, :utc_datetime
      add :ends_at, :utc_datetime
      add :is_active, :boolean, default: true
      timestamps()
    end
  end
end
