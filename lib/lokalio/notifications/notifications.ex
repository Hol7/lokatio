defmodule Lokalio.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @types ~w(promo proximity scan message system)

  schema "notifications" do
    field :type, :string
    field :title, :string
    field :body, :string
    field :data, :map, default: %{}
    field :read_at, :utc_datetime

    belongs_to :user, Lokalio.Accounts.User
    belongs_to :business, Lokalio.Businesses.Business

    timestamps(type: :utc_datetime)
  end

  def changeset(notif, attrs) do
    notif
    |> cast(attrs, [:type, :title, :body, :data, :user_id, :business_id])
    |> validate_required([:type, :title, :body, :user_id])
    |> validate_inclusion(:type, @types)
  end
end

defmodule Lokalio.Notifications do
  @moduledoc """
  Contexte Notifications — push temps réel via Phoenix PubSub + Absinthe Subscriptions.
  Phase 2 : FCM via Pigeon.
  """

  import Ecto.Query
  alias Lokalio.Repo
  alias Lokalio.Notifications.Notification
  alias Lokalio.Accounts

  #  Récupération

  def list_user_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)
    unread_only = Keyword.get(opts, :unread_only, false)

    query =
      from n in Notification,
        where: n.user_id == ^user_id,
        order_by: [desc: n.inserted_at],
        limit: ^limit,
        preload: [:business]

    query =
      if unread_only, do: from(n in query, where: is_nil(n.read_at)), else: query

    Repo.all(query)
  end

  def unread_count(user_id) do
    Repo.aggregate(
      from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at)),
      :count
    )
  end

  #  Création & envoi

  def send_notification(user_id, type, title, body, opts \\ []) do
    business_id = Keyword.get(opts, :business_id)
    data = Keyword.get(opts, :data, %{})

    result =
      %Notification{}
      |> Notification.changeset(%{
        user_id: user_id,
        business_id: business_id,
        type: type,
        title: title,
        body: body,
        data: data
      })
      |> Repo.insert()

    case result do
      {:ok, notif} ->
        # Broadcast Absinthe subscription temps réel
        Absinthe.Subscription.publish(
          LokalioWeb.Endpoint,
          notif,
          notification_received: "user:#{user_id}"
        )

        # Phoenix PubSub
        Phoenix.PubSub.broadcast(
          Lokalio.PubSub,
          "user:#{user_id}",
          {:notification, notif}
        )

        {:ok, notif}

      err -> err
    end
  end

  def mark_as_read(notification_id) do
    case Repo.get(Notification, notification_id) do
      nil -> {:error, :not_found}
      notif ->
        notif
        |> Ecto.Changeset.change(%{read_at: DateTime.utc_now() |> DateTime.truncate(:second)})
        |> Repo.update()
    end
  end

  def mark_all_read(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {count, _} =
      from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at))
      |> Repo.update_all(set: [read_at: now])

    {:ok, count}
  end

  # Notifications spécifiques

  # Notifie tous les clients actifs d'une nouvelle promo
  def broadcast_promo_notification(promo) do
    promo = Repo.preload(promo, :business)

    # Récupère tous les clients actifs
    clients = Accounts.list_users(role: "client")

    Enum.each(clients, fn client ->
      send_notification(
        client.id,
        "promo",
        "🔥 Promo — #{promo.business.name}",
        "#{promo.title} — #{promo.discount_rate}% de réduction jusqu'au #{format_date(promo.ends_at)}",
        business_id: promo.business_id,
        data: %{promo_id: promo.id, business_id: promo.business_id}
      )
    end)
  end

  # Notif de proximité — envoyée depuis React Native côté client
  def send_proximity_notification(user_id, businesses) do
    names = businesses |> Enum.take(3) |> Enum.map(& &1.name) |> Enum.join(", ")
    count = length(businesses)

    send_notification(
      user_id,
      "proximity",
      "📍 #{count} lieu(x) à proximité",
      "Vous êtes proche de : #{names}. Profitez des réductions !",
      data: %{business_ids: Enum.map(businesses, & &1.id)}
    )
  end

  # Notif de nouveau scan pour le business owner
  def notify_new_scan(business, scan) do
    business = Repo.preload(business, :user)

    send_notification(
      business.user_id,
      "scan",
      "🎯 Nouveau scan — #{business.name}",
      "Un client vient de scanner votre QR code !",
      business_id: business.id,
      data: %{scan_id: scan.id, did_purchase: scan.did_purchase}
    )
  end

  # ─── Privé ───────────────────────────────────────────────────────────────────

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y")
  end
  defp format_date(_), do: "bientôt"
end
