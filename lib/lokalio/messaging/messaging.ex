defmodule Lokalio.Messaging do
  @moduledoc """
  Contexte Messaging — chat temps réel client ↔ business via Absinthe Subscriptions.
  """

  import Ecto.Query
  alias Lokalio.Repo
  alias Lokalio.Messaging.{Conversation, Message}

  # Conversations

  def get_or_create_conversation(user_id, business_id) do
    case Repo.get_by(Conversation, user_id: user_id, business_id: business_id) do
      nil ->
        %Conversation{}
        |> Conversation.changeset(%{user_id: user_id, business_id: business_id})
        |> Repo.insert()
      conv ->
        {:ok, conv}
    end
  end

  def get_conversation!(id) do
    Repo.get!(Conversation, id)
    |> Repo.preload([:user, :business, messages: [:sender]])
  end

  def list_user_conversations(user_id) do
    from(c in Conversation,
      where: c.user_id == ^user_id,
      preload: [:business, messages: [:sender]],
      order_by: [desc: c.updated_at]
    )
    |> Repo.all()
  end

  def list_business_conversations(business_id) do
    from(c in Conversation,
      where: c.business_id == ^business_id,
      preload: [:user, messages: [:sender]],
      order_by: [desc: c.updated_at]
    )
    |> Repo.all()
  end

  #  Messages

  def send_message(conversation_id, sender_id, body) do
    result =
      %Message{}
      |> Message.changeset(%{
        conversation_id: conversation_id,
        sender_id: sender_id,
        body: body
      })
      |> Repo.insert()

    case result do
      {:ok, message} ->
        message = Repo.preload(message, :sender)

        # Broadcast via Absinthe PubSub → subscription :message_sent
        Absinthe.Subscription.publish(
          LokalioWeb.Endpoint,
          message,
          message_sent: "conversation:#{conversation_id}"
        )

        # Aussi via Phoenix PubSub pour les channels natifs
        Phoenix.PubSub.broadcast(
          Lokalio.PubSub,
          "conversation:#{conversation_id}",
          {:new_message, message}
        )

        {:ok, message}

      err ->
        err
    end
  end

  def list_messages(conversation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    before_id = Keyword.get(opts, :before_id)

    query =
      from m in Message,
        where: m.conversation_id == ^conversation_id,
        preload: [:sender],
        order_by: [desc: m.inserted_at],
        limit: ^limit

    query =
      if before_id do
        from m in query, where: m.id < ^before_id
      else
        query
      end

    Repo.all(query)
  end

  def mark_as_read(message_id) do
    case Repo.get(Message, message_id) do
      nil -> {:error, :not_found}
      msg ->
        msg
        |> Ecto.Changeset.change(%{read_at: DateTime.utc_now() |> DateTime.truncate(:second)})
        |> Repo.update()
    end
  end

  def unread_count(conversation_id, user_id) do
    Repo.aggregate(
      from(m in Message,
        where: m.conversation_id == ^conversation_id,
        where: m.sender_id != ^user_id,
        where: is_nil(m.read_at)
      ),
      :count
    )
  end
end
