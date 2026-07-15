# frozen_string_literal: true

module GamifiedShop
  module Admin
    class OrdersController < AdminController
      PAGE_SIZE = 50

      def index
        orders = ShopOrder.includes(:user, :shop_item).order(id: :desc)

        if params[:username].present?
          user = User.find_by_username(params[:username])
          orders = orders.where(user_id: user&.id || -1)
        end
        orders = orders.where(shop_item_id: params[:item_id]) if params[:item_id].present?
        orders = orders.where(status: params[:status]) if params[:status].present?

        page = params[:page].to_i.clamp(0, 10_000)
        orders = orders.offset(page * PAGE_SIZE).limit(PAGE_SIZE)

        render_json_dump(orders: serialize_data(orders, ShopOrderSerializer))
      end

      def refund
        order = Refunds.refund!(order_id: params[:id], refunded_by: current_user)
        render_json_dump(order: serialize_data(order, ShopOrderSerializer, root: false))
      end
    end
  end
end
