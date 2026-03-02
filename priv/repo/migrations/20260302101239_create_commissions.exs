defmodule Lokalio.Repo.Migrations.CreateCommissions do
  use Ecto.Migration

  def change do
    create table(:commissions) do
      add :business_id, references(:businesses, on_delete: :delete_all), null: false
      add :qr_scan_id, references(:qr_scans, on_delete: :delete_all)
      add :amount, :decimal
      # % commission prélevé
      add :rate, :decimal
      # pending | paid
      add :status, :string, default: "pending"
      add :period_start, :date
      add :period_end, :date
      timestamps()
    end
  end
end
