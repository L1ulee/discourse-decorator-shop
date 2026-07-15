# frozen_string_literal: true

class CreateGamifiedShopTables < ActiveRecord::Migration[7.0]
  def change
    create_table :gamified_shop_point_accounts do |t|
      t.integer :user_id, null: false
      t.bigint :balance, null: false, default: 0
      t.timestamps
    end
    add_index :gamified_shop_point_accounts, :user_id, unique: true

    create_table :gamified_shop_point_ledger_entries do |t|
      t.integer :user_id, null: false
      t.integer :amount, null: false
      t.bigint :balance_after, null: false
      t.string :entry_type, null: false, limit: 40
      t.string :reference_type, limit: 100
      t.bigint :reference_id
      t.text :description
      t.integer :created_by_id
      t.datetime :created_at, null: false
    end
    add_index :gamified_shop_point_ledger_entries,
              %i[user_id entry_type created_at],
              name: "idx_gamified_shop_ledger_user_type_date"
    add_index :gamified_shop_point_ledger_entries,
              %i[reference_type reference_id],
              name: "idx_gamified_shop_ledger_reference"
    # At most one reversal per original ledger entry (PRD 6.2, ADR-0003).
    add_index :gamified_shop_point_ledger_entries,
              :reference_id,
              unique: true,
              where: "entry_type = 'event_reversal'",
              name: "idx_gamified_shop_ledger_unique_reversal"
    # At most one restore per reversal entry (post undelete).
    add_index :gamified_shop_point_ledger_entries,
              :reference_id,
              unique: true,
              where:
                "entry_type = 'event_reward' AND reference_type = 'GamifiedShop::PointLedgerEntry'",
              name: "idx_gamified_shop_ledger_unique_restore"

    create_table :gamified_shop_decoration_assets do |t|
      t.string :name, null: false, limit: 200
      t.string :slot, null: false, limit: 40
      t.bigint :upload_id
      t.string :style_preset, limit: 60
      t.jsonb :style_params, null: false, default: {}
      t.text :custom_css
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :gamified_shop_decoration_assets, :slot

    create_table :gamified_shop_items do |t|
      t.string :name, null: false, limit: 200
      t.text :description
      t.string :item_type, null: false, default: "decoration", limit: 40
      t.integer :price, null: false, default: 0
      t.integer :stock
      t.integer :purchase_limit_per_user
      t.boolean :listed, null: false, default: false
      t.bigint :decoration_asset_id
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :gamified_shop_items, :listed
    add_index :gamified_shop_items, :decoration_asset_id

    create_table :gamified_shop_orders do |t|
      t.integer :user_id, null: false
      t.bigint :shop_item_id, null: false
      t.integer :price_paid, null: false
      t.string :status, null: false, default: "fulfilled", limit: 40
      t.datetime :refunded_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :gamified_shop_orders,
              %i[user_id shop_item_id status],
              name: "idx_gamified_shop_orders_user_item_status"
    add_index :gamified_shop_orders, :created_at

    create_table :gamified_shop_user_decorations do |t|
      t.integer :user_id, null: false
      t.bigint :decoration_asset_id, null: false
      t.string :source, null: false, limit: 40
      t.bigint :source_id
      t.boolean :equipped, null: false, default: false
      t.datetime :expires_at
      t.timestamps
    end
    add_index :gamified_shop_user_decorations, %i[user_id equipped]
    add_index :gamified_shop_user_decorations, :decoration_asset_id

    # FK RESTRICT: an asset that is bound to an item or owned by a user can
    # never be deleted (PRD 6.4). Postgres default ON DELETE is NO ACTION.
    add_foreign_key :gamified_shop_items,
                    :gamified_shop_decoration_assets,
                    column: :decoration_asset_id
    add_foreign_key :gamified_shop_user_decorations,
                    :gamified_shop_decoration_assets,
                    column: :decoration_asset_id
    add_foreign_key :gamified_shop_orders, :gamified_shop_items, column: :shop_item_id
  end
end
