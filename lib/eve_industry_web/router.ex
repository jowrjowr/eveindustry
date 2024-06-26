defmodule EveIndustryWeb.Router do
  use EveIndustryWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {EveIndustryWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", EveIndustryWeb do
    pipe_through :browser

    live "/", PageLive, :index
    live "/ore", OreLive
    live "/reactions", ReactionsLive
    live "/structures", StructuresLive
    live "/components", ComponentsLive
    live "/equipment", EquipmentLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", EveIndustryWeb do
  #   pipe_through :api
  # end
end
