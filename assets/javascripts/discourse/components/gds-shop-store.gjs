import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import GdsShopItemCard from "./gds-shop-item-card";

const SLOTS = ["avatar_frame", "username_style", "user_card_background"];

function slotLabel(slot) {
  return i18n(`gamified_shop.slots.${slot}`);
}

export default class GdsShopStore extends Component {
  @service dialog;
  @service siteSettings;
  @service toasts;

  @tracked balance = this.args.store.balance;
  @tracked items = [...(this.args.store.items ?? [])];
  @tracked purchasedCounts = { ...(this.args.store.purchased_counts ?? {}) };
  @tracked ownedAssetIds = [...(this.args.store.owned_asset_ids ?? [])];
  @tracked slotFilter = null;
  @tracked purchasingItemId = null;

  slots = SLOTS;

  get currencyName() {
    return this.siteSettings.gamified_shop_currency_name;
  }

  get balanceLabel() {
    return i18n("gamified_shop.balance_label", {
      currency: this.currencyName,
      amount: this.balance,
    });
  }

  get filteredItems() {
    if (!this.slotFilter) {
      return this.items;
    }

    return this.items.filter(
      (item) => item.decoration_asset?.slot === this.slotFilter
    );
  }

  @action
  setSlotFilter(slot) {
    this.slotFilter = slot;
  }

  @action
  buy(item) {
    this.dialog.yesNoConfirm({
      message: i18n("gamified_shop.store.confirm_purchase", {
        price: item.price,
        currency: this.currencyName,
        name: item.name,
      }),
      didConfirm: () => this.purchase(item),
    });
  }

  @action
  async purchase(item) {
    this.purchasingItemId = item.id;

    try {
      const result = await ajax("/gamified-shop/purchase", {
        type: "POST",
        data: { item_id: item.id },
      });

      this.balance = result.balance;
      this.purchasedCounts = {
        ...this.purchasedCounts,
        [item.id]: (this.purchasedCounts[item.id] ?? 0) + 1,
      };

      const assetId = item.decoration_asset?.id;
      if (assetId && !this.ownedAssetIds.includes(assetId)) {
        this.ownedAssetIds = [...this.ownedAssetIds, assetId];
      }

      if (item.stock !== null && item.stock !== undefined) {
        this.items = this.items.map((it) =>
          it.id === item.id ? { ...it, stock: Math.max(0, it.stock - 1) } : it
        );
      }

      this.toasts.success({
        data: { message: i18n("gamified_shop.store.purchase_success") },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.purchasingItemId = null;
    }
  }

  <template>
    <div class="gds-shop-store">
      <div class="gds-shop-store__header">
        <span class="gds-shop-balance">{{this.balanceLabel}}</span>
      </div>

      <div class="gds-shop-filters" role="group">
        <button
          type="button"
          class={{concatClass
            "btn gds-shop-filters__btn"
            (if
              this.slotFilter
              "btn-default"
              "btn-primary gds-shop-filters__btn--active"
            )
          }}
          {{on "click" (fn this.setSlotFilter null)}}
        >
          {{i18n "gamified_shop.store.all_slots"}}
        </button>

        {{#each this.slots as |slot|}}
          <button
            type="button"
            class={{concatClass
              "btn gds-shop-filters__btn"
              (if
                (eq this.slotFilter slot)
                "btn-primary gds-shop-filters__btn--active"
                "btn-default"
              )
            }}
            {{on "click" (fn this.setSlotFilter slot)}}
          >
            {{slotLabel slot}}
          </button>
        {{/each}}
      </div>

      {{#if this.filteredItems.length}}
        <div class="gds-shop-items">
          {{#each this.filteredItems as |item|}}
            <GdsShopItemCard
              @item={{item}}
              @balance={{this.balance}}
              @ownedAssetIds={{this.ownedAssetIds}}
              @purchasedCounts={{this.purchasedCounts}}
              @purchasing={{eq this.purchasingItemId item.id}}
              @onBuy={{this.buy}}
            />
          {{/each}}
        </div>
      {{else}}
        <p class="gds-shop-store__empty">
          {{i18n "gamified_shop.store.empty"}}
        </p>
      {{/if}}
    </div>
  </template>
}
