defmodule LokalioWeb.Schema.Types.MessageTypes do
  use Absinthe.Schema.Notation

  object :message do
    field :id, :id
    field :body, :string
    field :read_at, :string
    field :inserted_at, :string
    field :sender, :user
    field :conversation_id, :id
  end

  object :conversation do
    field :id, :id
    field :user, :user
    field :business, :business
    field :messages, list_of(:message)
    field :unread_count, :integer
    field :inserted_at, :string
    field :updated_at, :string
  end

  object :message_queries do
    field :my_conversations, list_of(:conversation) do
      resolve &LokalioWeb.Schema.Resolvers.MessageResolver.my_conversations/3
    end

    field :conversation_messages, list_of(:message) do
      arg :conversation_id, non_null(:id)
      arg :limit, :integer
      arg :before_id, :id
      resolve &LokalioWeb.Schema.Resolvers.MessageResolver.conversation_messages/3
    end
  end

  object :message_mutations do
    field :send_message, :message do
      arg :business_id, non_null(:id)
      arg :body, non_null(:string)
      resolve &LokalioWeb.Schema.Resolvers.MessageResolver.send_message/3
    end

    field :send_message_in_conversation, :message do
      arg :conversation_id, non_null(:id)
      arg :body, non_null(:string)
      resolve &LokalioWeb.Schema.Resolvers.MessageResolver.send_in_conversation/3
    end

    field :mark_message_read, :message do
      arg :id, non_null(:id)
      resolve &LokalioWeb.Schema.Resolvers.MessageResolver.mark_read/3
    end
  end

  object :message_subscriptions do
    field :message_sent, :message do
      arg :conversation_id, non_null(:id)

      config fn args, _info ->
        {:ok, topic: "conversation:#{args.conversation_id}"}
      end
    end
  end
end
