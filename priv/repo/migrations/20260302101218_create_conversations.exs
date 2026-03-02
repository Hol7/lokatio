defmodule Lokalio.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :business_id, references(:businesses, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:conversations, [:user_id, :business_id])

    create table(:messages) do
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :sender_id, references(:users, on_delete: :nilify_all)
      add :body, :text, null: false
      add :read_at, :utc_datetime
      timestamps()
    end
  end
end
