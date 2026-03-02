defmodule Lokalio.Repo.Migrations.CreateQrScans do
  use Ecto.Migration

  def change do
    create table(:qr_scans) do
      add :user_id, references(:users, on_delete: :nilify_all)
      add :business_id, references(:businesses, on_delete: :delete_all), null: false
      add :did_purchase, :boolean, default: false
      add :scanned_at, :utc_datetime
      timestamps()
    end

    create index(:qr_scans, [:business_id])
    create index(:qr_scans, [:user_id])
  end
end
