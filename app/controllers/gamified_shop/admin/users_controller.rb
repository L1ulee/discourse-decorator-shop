# frozen_string_literal: true

module GamifiedShop
  module Admin
    class UsersController < StaffController
      # Backs the admin "Users" tab URL so browser reloads / deep links boot
      # the app shell (HTML is handled by serve_app_shell_for_html).
      def index
        render json: success_json
      end

      def show
        user = fetch_user

        decorations =
          UserDecoration
            .where(user_id: user.id)
            .includes(decoration_asset: :upload)
            .order(created_at: :desc)
        ledger = PointLedgerEntry.where(user_id: user.id).order(id: :desc).limit(50)
        orders =
          ShopOrder.where(user_id: user.id).includes(:user, :shop_item).order(id: :desc).limit(50)

        render_json_dump(
          user: BasicUserSerializer.new(user, root: false).as_json,
          balance: PointAccount.balance_for(user.id),
          decorations: serialize_data(decorations, UserDecorationSerializer),
          ledger: serialize_data(ledger, PointLedgerEntrySerializer),
          orders: serialize_data(orders, ShopOrderSerializer),
        )
      end

      def adjust_points
        user = fetch_user
        entry =
          Grants.adjust_points!(
            user: user,
            amount: params.require(:amount),
            acting_user: current_user,
            description: params[:description].presence,
          )
        render_json_dump(
          entry: serialize_data(entry, PointLedgerEntrySerializer, root: false),
          balance: PointAccount.balance_for(user.id),
        )
      end

      def grant_decoration
        user = fetch_user
        decoration =
          Grants.grant_decoration!(
            user: user,
            decoration_asset_id: params.require(:decoration_asset_id),
            acting_user: current_user,
          )
        render_json_dump(
          decoration: serialize_data(decoration, UserDecorationSerializer, root: false),
        )
      end

      def revoke_decoration
        user = fetch_user
        target = UserDecoration.find_by(id: params[:id], user_id: user.id)
        raise ShopError.new(:decoration_not_found) if target.blank?

        decoration =
          Grants.revoke_decoration!(user_decoration_id: target.id, acting_user: current_user)
        render_json_dump(
          decoration: serialize_data(decoration, UserDecorationSerializer, root: false),
        )
      end

      private

      def fetch_user
        user = User.find_by(id: params[:user_id])
        raise Discourse::NotFound if user.blank?
        user
      end
    end
  end
end
