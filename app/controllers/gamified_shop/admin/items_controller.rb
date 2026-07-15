# frozen_string_literal: true

module GamifiedShop
  module Admin
    class ItemsController < AdminController
      def index
        items = ShopItem.includes(decoration_asset: :upload).order(:id)
        render_json_dump(items: serialize_data(items, ShopItemSerializer))
      end

      def create
        item = ShopItem.new(item_params)
        item.item_type = ShopItem::DECORATION
        if item.save
          log_action("gamified_shop_create_item", item)
          render_json_dump(item: serialize_data(item, ShopItemSerializer, root: false))
        else
          render_json_error(item)
        end
      end

      def update
        item = ShopItem.find_by(id: params[:id])
        raise ShopError.new(:item_not_found) if item.blank?

        if item.update(item_params)
          log_action("gamified_shop_update_item", item)
          render_json_dump(item: serialize_data(item, ShopItemSerializer, root: false))
        else
          render_json_error(item)
        end
      end

      private

      def item_params
        permitted =
          params.permit(
            :name,
            :description,
            :price,
            :stock,
            :purchase_limit_per_user,
            :listed,
            :decoration_asset_id,
          )
        permitted
      end

      def log_action(name, item)
        StaffActionLogger.new(current_user).log_custom(name, item_id: item.id, item_name: item.name)
      end
    end
  end
end
