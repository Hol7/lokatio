defmodule LokalioWeb.Schema.Resolvers.NotificationResolver do
  alias Lokalio.Notifications

  def my_notifications(_parent, args, %{context: %{current_user: user}}) do
    opts =
      []
      |> maybe_add(:limit, args[:limit])
      |> maybe_add(:unread_only, args[:unread_only])
    {:ok, Notifications.list_user_notifications(user.id, opts)}
  end
  def my_notifications(_, _, _), do: {:error, "Not authenticated"}

  def unread_count(_parent, _args, %{context: %{current_user: user}}) do
    {:ok, Notifications.unread_count(user.id)}
  end
  def unread_count(_, _, _), do: {:error, "Not authenticated"}

  def mark_read(_parent, %{id: id}, %{context: %{current_user: _user}}) do
    case Notifications.mark_as_read(id) do
      {:ok, notif} -> {:ok, notif}
      {:error, :not_found} -> {:error, "Notification not found"}
    end
  end
  def mark_read(_, _, _), do: {:error, "Not authenticated"}

  def mark_all_read(_parent, _args, %{context: %{current_user: user}}) do
    case Notifications.mark_all_read(user.id) do
      {:ok, count} -> {:ok, count}
      _ -> {:error, "Failed"}
    end
  end
  def mark_all_read(_, _, _), do: {:error, "Not authenticated"}

  def report_location(_parent, %{lat: lat, lng: lng}, %{context: %{current_user: user}}) do
    nearby = Lokalio.Businesses.nearby_businesses(lat, lng, 0.5)
    if length(nearby) > 0 do
      Task.start(fn -> Notifications.send_proximity_notification(user.id, nearby) end)
    end
    {:ok, nearby}
  end
  def report_location(_, _, _), do: {:error, "Not authenticated"}

  defp maybe_add(opts, _key, nil), do: opts
  defp maybe_add(opts, key, value), do: Keyword.put(opts, key, value)
end
