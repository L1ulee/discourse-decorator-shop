# frozen_string_literal: true

GamifiedShop::Engine.routes.draw do
  # Ember app shell for full page loads / deep links.
  get "/" => "pages#index"
  get "/decorations" => "pages#index"

  get "/store" => "store#index"
  post "/purchase" => "purchases#create"

  get "/me/balance" => "me#balance"
  get "/me/decorations" => "me#decorations"
  post "/me/decorations/:id/equip" => "me#equip"
  post "/me/decorations/:id/unequip" => "me#unequip"

  get "/stylesheet/:digest" => "stylesheets#show",
      :defaults => {
        format: "css",
      },
      :constraints => {
        digest: /\h+(\.css)?/,
      }
end
