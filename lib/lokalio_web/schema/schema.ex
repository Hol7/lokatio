defmodule LokalioWeb.Schema do
  use Absinthe.Schema

  import_types(Absinthe.Type.Custom)
  import_types(LokalioWeb.Schema.Types.AccountTypes)
  import_types(LokalioWeb.Schema.Types.BusinessTypes)
  import_types(LokalioWeb.Schema.Types.MessageTypes)
  import_types(LokalioWeb.Schema.Types.NotificationTypes)

  query do
    import_fields(:account_queries)
    import_fields(:business_queries)
    import_fields(:message_queries)
  end

  mutation do
    import_fields(:account_mutations)
    import_fields(:business_mutations)
    import_fields(:message_mutations)
    import_fields(:scan_mutations)
  end

  subscription do
    import_fields(:message_subscriptions)
    import_fields(:notification_subscriptions)
  end
end
