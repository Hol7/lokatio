defmodule Lokalio.Repo.Migrations.AddProfileToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :full_name, :string
      add :phone, :string
      add :avatar_url, :string
      # client | business | admin
      add :role, :string, default: "client"
      add :is_active, :boolean, default: true
      timestamps()
    end
  end
end
