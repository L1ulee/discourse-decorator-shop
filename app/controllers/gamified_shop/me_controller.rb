# frozen_string_literal: true

module GamifiedShop
  class MeController < ApplicationController
    def balance
      render_json_dump(
        balance: PointAccount.balance_for(current_user.id),
        currency_name: SiteSetting.gamified_shop_currency_name,
      )
    end

    def decorations
      decorations =
        UserDecoration
          .where(user_id: current_user.id)
          .includes(decoration_asset: :upload)
          .order(created_at: :desc)

      render_json_dump(
        decorations: serialize_data(decorations, UserDecorationSerializer),
        balance: PointAccount.balance_for(current_user.id),
        currency_name: SiteSetting.gamified_shop_currency_name,
      )
    end

    def equip
      decoration = Equipping.equip!(user: current_user, user_decoration_id: params[:id])
      render_json_dump(
        decoration: serialize_data(decoration, UserDecorationSerializer, root: false),
      )
    end

    def unequip
      decoration = Equipping.unequip!(user: current_user, user_decoration_id: params[:id])
      render_json_dump(
        decoration: serialize_data(decoration, UserDecorationSerializer, root: false),
      )
    end
  end
end
