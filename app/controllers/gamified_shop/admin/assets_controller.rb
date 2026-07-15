# frozen_string_literal: true

module GamifiedShop
  module Admin
    class AssetsController < StaffController
      def index
        assets = DecorationAsset.includes(:upload).order(:id)
        render_json_dump(assets: serialize_data(assets, AdminDecorationAssetSerializer))
      end

      def create
        # Custom CSS is admin-only (ADR-0002): moderators cannot author
        # styles Discourse would never let them ship through themes.
        if params[:custom_css].present? && !current_user.admin?
          raise Discourse::InvalidAccess.new
        end

        asset = DecorationAsset.new(asset_params)
        if asset.save
          StaffActionLogger.new(current_user).log_custom(
            "gamified_shop_create_asset",
            asset_id: asset.id,
            asset_name: asset.name,
            slot: asset.slot,
          )
          render_json_dump(asset: serialize_data(asset, AdminDecorationAssetSerializer))
        else
          render_json_error(asset)
        end
      end

      def destroy
        asset = DecorationAsset.find_by(id: params[:id])
        raise ShopError.new(:asset_not_found) if asset.blank?
        raise ShopError.new(:asset_in_use) unless asset.destroyable?

        begin
          asset.destroy!
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed
          # Raced with a purchase/grant that started referencing the asset
          # between the destroyable? check and the delete: FK RESTRICT wins.
          raise ShopError.new(:asset_in_use)
        end
        StaffActionLogger.new(current_user).log_custom(
          "gamified_shop_destroy_asset",
          asset_id: asset.id,
          asset_name: asset.name,
        )
        render json: success_json
      end

      private

      def asset_params
        permitted = params.permit(:name, :slot, :upload_id, :style_preset, :custom_css)
        style_params = params[:style_params]
        if style_params.present?
          permitted[:style_params] = style_params.permit!.to_h
        end
        permitted
      end
    end
  end
end
