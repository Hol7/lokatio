defmodule LokalioWeb.Schema.Types.NotificationTypes do
  use Absinthe.Schema.Notation

  object :notification do
    field :id, :id
    field :type, :string
    field :title, :string
    field :body, :string
    field :read_at, :string
    field :inserted_at, :string
    field :business, :business
  end

  object :notification_queries do
    field :my_notifications, list_of(:notification) do
      arg(:limit, :integer)
      arg(:unread_only, :boolean)
      resolve(&LokalioWeb.Schema.Resolvers.NotificationResolver.my_notifications/3)
    end

    field :unread_count, :integer do
      resolve(&LokalioWeb.Schema.Resolvers.NotificationResolver.unread_count/3)
    end
  end

  object :notification_mutations do
    field :mark_notification_read, :notification do
      arg(:id, non_null(:id))
      resolve(&LokalioWeb.Schema.Resolvers.NotificationResolver.mark_read/3)
    end

    field :mark_all_notifications_read, :integer do
      resolve(&LokalioWeb.Schema.Resolvers.NotificationResolver.mark_all_read/3)
    end

    field :report_location, list_of(:business) do
      arg(:lat, non_null(:float))
      arg(:lng, non_null(:float))
      resolve(&LokalioWeb.Schema.Resolvers.NotificationResolver.report_location/3)
    end
  end

  object :notification_subscriptions do
    field :notification_received, :notification do
      config(fn _args, %{context: %{current_user: user}} ->
        {:ok, topic: "user:#{user.id}"}
      end)
    end
  end
end
