defmodule LokalioWeb.Schema do
  use Absinthe.Schema

  import_types Absinthe.Type.Custom
  import_types LokalioWeb.Schema.Types.AccountTypes
  import_types LokalioWeb.Schema.Types.BusinessTypes
  import_types LokalioWeb.Schema.Types.MessageTypes
  import_types LokalioWeb.Schema.Types.NotificationTypes

  query do
    import_fields :account_queries
    import_fields :business_queries
    import_fields :message_queries
    import_fields :notification_queries
  end

  mutation do
    import_fields :account_mutations
    import_fields :business_mutations
    import_fields :message_mutations
    import_fields :notification_mutations
  end

  subscription do
    import_fields :message_subscriptions
    import_fields :notification_subscriptions
  end

  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(Lokalio.Repo, Dataloader.Ecto.new(Lokalio.Repo))

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end
end
