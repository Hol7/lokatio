defmodule LokalioWeb.PageController do
  use LokalioWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
