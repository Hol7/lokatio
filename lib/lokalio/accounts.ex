defmodule Lokalio.Accounts do
  @moduledoc """
  Contexte Accounts — gestion des utilisateurs, inscription, connexion, profil.
  """

  import Ecto.Query
  alias Lokalio.Repo
  alias Lokalio.Accounts.{User, UserToken}

  # Récupération

  def get_user!(id), do: Repo.get!(User, id)

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  def list_users(opts \\ []) do
    role = Keyword.get(opts, :role)
    query = from u in User, order_by: [desc: u.inserted_at]
    query = if role, do: from(u in query, where: u.role == ^role), else: query
    Repo.all(query)
  end

  #  Inscription

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  # Mise à jour profil

  def update_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  def update_fcm_token(%User{} = user, fcm_token) do
    user
    |> Ecto.Changeset.change(%{fcm_token: fcm_token})
    |> Repo.update()
  end

  #  Sessions (JWT via Guardian)

  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  # Admin

  def activate_user(%User{} = user), do: update_active(user, true)
  def deactivate_user(%User{} = user), do: update_active(user, false)

  defp update_active(user, value) do
    user |> Ecto.Changeset.change(%{is_active: value}) |> Repo.update()
  end

  def stats do
    %{
      total: Repo.aggregate(User, :count),
      clients: Repo.aggregate(from(u in User, where: u.role == "client"), :count),
      businesses: Repo.aggregate(from(u in User, where: u.role == "business"), :count),
      admins: Repo.aggregate(from(u in User, where: u.role == "admin"), :count)
    }
  end
end
