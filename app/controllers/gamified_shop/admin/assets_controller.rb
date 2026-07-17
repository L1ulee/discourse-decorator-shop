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
        raise Discourse::InvalidAccess.new if params[:custom_css].present? && !current_user.admin?

        asset = DecorationAsset.new(asset_params)
        if asset.save
          StaffActionLogger.new(current_user).log_custom(
            "gamified_shop_create_asset",
            asset_id: asset.id,
            asset_name: asset.name,
            slot: asset.slot,
          )
          render_json_dump(
            asset: serialize_data(asset, AdminDecorationAssetSerializer, root: false),
          )
        else
          render_json_error(asset)
        end
      end

      def update
        asset = DecorationAsset.find_by(id: params[:id])
        raise ShopError.new(:asset_not_found) if asset.blank?
        # Custom CSS is admin-only (ADR-0002), same as create.
        raise Discourse::InvalidAccess.new if params[:custom_css].present? && !current_user.admin?

        permitted = asset_params
        asset.assign_attributes(permitted)
        # Keep the row internally consistent when the slot/preset changes: an
        # image slot never carries style fields and a style slot never an
        # upload, so stale values from the previous slot are dropped before
        # validation. style_params is *replaced* (not merged) so params left
        # over from a previous preset — which the strict StylePresets.validate
        # would reject as unknown — do not survive a preset switch.
        if asset.image_slot?
          asset.style_preset = nil
          asset.style_params = nil
          asset.custom_css = nil
        else
          asset.upload_id = nil
          asset.style_params = permitted[:style_params] || {}
        end

        if asset.save
          StaffActionLogger.new(current_user).log_custom(
            "gamified_shop_update_asset",
            asset_id: asset.id,
            asset_name: asset.name,
            slot: asset.slot,
          )
          render_json_dump(
            asset: serialize_data(asset, AdminDecorationAssetSerializer, root: false),
          )
        else
          render_json_error(asset)
        end
      end

      def destroy
        asset = DecorationAsset.find_by(id: params[:id])
        raise ShopError.new(:asset_not_found) if asset.blank?

        # Deleting an in-use asset is allowed (admin choice): cascade the
        # cleanup in one transaction so it is safely removed from users and
        # unlinked from shop items (order history is preserved).
        begin
          ActiveRecord::Base.transaction do
            # Per-row destroy so each owner's EquippedCache is invalidated
            # (UserDecoration after_commit); delete_all would skip that.
            asset.user_decorations.find_each(&:destroy!)
            # Unlink without deleting the item (keeps its orders intact); an
            # unlisted, asset-less item can no longer sell the gone decoration.
            asset.shop_items.find_each do |item|
              item.update!(decoration_asset_id: nil, listed: false)
            end
            asset.destroy!
          end
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed
          # A purchase/grant raced in after our cleanup; report it cleanly.
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
        permitted[:style_params] = style_params.permit!.to_h if style_params.present?
        permitted
      end
    end
  end
end
