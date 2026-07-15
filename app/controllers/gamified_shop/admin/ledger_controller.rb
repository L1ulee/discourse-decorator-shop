# frozen_string_literal: true

module GamifiedShop
  module Admin
    class LedgerController < AdminController
      PAGE_SIZE = 50

      def index
        entries = PointLedgerEntry.order(id: :desc)

        if params[:username].present?
          user = User.find_by_username(params[:username])
          entries = entries.where(user_id: user&.id || -1)
        end
        if params[:entry_type].present?
          entries = entries.where(entry_type: params[:entry_type])
        end
        if params[:item_id].present?
          entries =
            entries.where(
              reference_type: "GamifiedShop::ShopOrder",
              reference_id: ShopOrder.where(shop_item_id: params[:item_id]).select(:id),
            )
        end
        entries = entries.where("created_at >= ?", params[:from]) if params[:from].present?
        entries = entries.where("created_at <= ?", params[:to]) if params[:to].present?

        page = params[:page].to_i.clamp(0, 10_000)
        entries = entries.offset(page * PAGE_SIZE).limit(PAGE_SIZE)

        render_json_dump(entries: serialize_data(entries, PointLedgerEntrySerializer))
      end
    end
  end
end
