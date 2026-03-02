defmodule Lokalio.Repo do
  use Ecto.Repo,
    otp_app: :lokalio,
    adapter: Ecto.Adapters.Postgres
end
