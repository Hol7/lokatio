defmodule Lokalio.Businesses do
  @moduledoc """
  Contexte Businesses — gestion des commerces, QR codes, promos, scans.
  """

  import Ecto.Query
  alias Lokalio.Repo
  alias Lokalio.Businesses.{Business, BusinessImage, Promotion, QrScan}
  alias Lokalio.Notifications

  #  Businesses

  def list_businesses(opts \\ []) do
    query =
      from b in Business,
        where: b.is_active == true,
        preload: [:images, :promotions],
        order_by: [asc: b.name]

    query =
      case Keyword.get(opts, :category) do
        nil -> query
        cat -> from b in query, where: b.category == ^cat
      end

    # Filtre géographique (rayon en km)
    query =
      case {Keyword.get(opts, :lat), Keyword.get(opts, :lng), Keyword.get(opts, :radius_km)} do
        {lat, lng, radius} when not is_nil(lat) and not is_nil(lng) and not is_nil(radius) ->
          # Calcul distance en degrés (approximation rapide pour MVP)
          deg = radius / 111.0
          from b in query,
            where: b.latitude >= ^(lat - deg) and b.latitude <= ^(lat + deg),
            where: b.longitude >= ^(lng - deg) and b.longitude <= ^(lng + deg)
        _ ->
          query
      end

    Repo.all(query)
  end

  def get_business!(id) do
    Repo.get!(Business, id)
    |> Repo.preload([:images, :promotions, :user])
  end

  def get_business(id) do
    Repo.get(Business, id)
    |> case do
      nil -> nil
      b -> Repo.preload(b, [:images, :promotions])
    end
  end

  def get_business_by_user(user_id) do
    Repo.get_by(Business, user_id: user_id)
    |> case do
      nil -> nil
      b -> Repo.preload(b, [:images, :promotions])
    end
  end

  def get_business_by_qr_token(token) do
    Repo.get_by(Business, qr_code_token: token)
    |> case do
      nil -> nil
      b -> Repo.preload(b, [:images, :promotions, :user])
    end
  end

  def create_business(attrs) do
    %Business{}
    |> Business.changeset(attrs)
    |> Repo.insert()
  end

  def update_business(%Business{} = business, attrs) do
    business
    |> Business.update_changeset(attrs)
    |> Repo.update()
  end

  def verify_business(%Business{} = business) do
    business
    |> Ecto.Changeset.change(%{is_verified: true})
    |> Repo.update()
  end

  # Images

  def add_business_image(business_id, url, position \\ 0) do
    %BusinessImage{}
    |> BusinessImage.changeset(%{business_id: business_id, url: url, position: position})
    |> Repo.insert()
  end

  def delete_business_image(id) do
    case Repo.get(BusinessImage, id) do
      nil -> {:error, :not_found}
      img -> Repo.delete(img)
    end
  end

  # Promotions

  def list_active_promotions do
    now = DateTime.utc_now()

    from(p in Promotion,
      where: p.is_active == true,
      where: p.starts_at <= ^now,
      where: p.ends_at >= ^now,
      preload: [:business]
    )
    |> Repo.all()
  end

  def create_promotion(attrs) do
    result =
      %Promotion{}
      |> Promotion.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, promo} ->
        # Notifier tous les clients de la nouvelle promo
        notify_promo_created(promo)
        {:ok, promo}
      err -> err
    end
  end

  def update_promotion(%Promotion{} = promo, attrs) do
    promo |> Promotion.changeset(attrs) |> Repo.update()
  end

  def delete_promotion(%Promotion{} = promo), do: Repo.delete(promo)

  # QR Scans

  def scan_qr(user_id, qr_token, did_purchase \\ false) do
    case get_business_by_qr_token(qr_token) do
      nil ->
        {:error, :business_not_found}

      business ->
        result =
          %QrScan{}
          |> QrScan.changeset(%{
            user_id: user_id,
            business_id: business.id,
            did_purchase: did_purchase
          })
          |> Repo.insert()

        case result do
          {:ok, scan} ->
            # Notifier le business en temps réel
            Phoenix.PubSub.broadcast(
              Lokalio.PubSub,
              "business:#{business.id}",
              {:new_scan, scan}
            )
            {:ok, scan}
          err -> err
        end
    end
  end

  def business_scan_count(business_id) do
    Repo.aggregate(from(s in QrScan, where: s.business_id == ^business_id), :count)
  end

  def business_purchase_count(business_id) do
    Repo.aggregate(
      from(s in QrScan, where: s.business_id == ^business_id and s.did_purchase == true),
      :count
    )
  end

  #  Nearby Businesses (géofencing)

  def nearby_businesses(lat, lng, radius_km \\ 0.5) do
    # Approximation en degrés : 1° ≈ 111 km
    deg = radius_km / 111.0

    from(b in Business,
      where: b.is_active == true,
      where: b.latitude >= ^(lat - deg) and b.latitude <= ^(lat + deg),
      where: b.longitude >= ^(lng - deg) and b.longitude <= ^(lng + deg),
      preload: [:promotions]
    )
    |> Repo.all()
    |> Enum.map(fn b ->
      distance = haversine(lat, lng, b.latitude || 0.0, b.longitude || 0.0)
      Map.put(b, :distance_m, distance)
    end)
    |> Enum.sort_by(& &1.distance_m)
  end

  # Stats business

  def business_stats(business_id) do
    %{
      total_scans: business_scan_count(business_id),
      total_purchases: business_purchase_count(business_id),
      active_promos: count_active_promos(business_id)
    }
  end

  # Privé

  defp count_active_promos(business_id) do
    now = DateTime.utc_now()
    Repo.aggregate(
      from(p in Promotion,
        where: p.business_id == ^business_id,
        where: p.is_active == true,
        where: p.starts_at <= ^now,
        where: p.ends_at >= ^now
      ),
      :count
    )
  end

  defp notify_promo_created(promo) do
    Task.start(fn ->
      Notifications.broadcast_promo_notification(promo)
    end)
  end

  # Formule Haversine — distance en mètres entre deux coordonnées GPS
  defp haversine(lat1, lng1, lat2, lng2) do
    r = 6_371_000  # rayon Terre en mètres
    phi1 = :math.pi() * lat1 / 180
    phi2 = :math.pi() * lat2 / 180
    dphi = :math.pi() * (lat2 - lat1) / 180
    dlambda = :math.pi() * (lng2 - lng1) / 180

    a =
      :math.sin(dphi / 2) * :math.sin(dphi / 2) +
      :math.cos(phi1) * :math.cos(phi2) *
      :math.sin(dlambda / 2) * :math.sin(dlambda / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    round(r * c)
  end
end
