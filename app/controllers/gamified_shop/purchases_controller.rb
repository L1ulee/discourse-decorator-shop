# frozen_string_literal: true

module GamifiedShop
  class PurchasesController < ApplicationController
    def create
      order = Purchases.purchase!(user: current_user, item_id: params.require(:item_id))

      render_json_dump(
        order: serialize_data(order, ShopOrderSerializer, root: false),
        balance: PointAccount.balance_for(current_user.id),
      )
    end
  end
end
