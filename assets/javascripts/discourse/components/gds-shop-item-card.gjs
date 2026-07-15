import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class GdsShopItemCard extends Component {
  get item() {
    return this.args.item;
  }

  get slotLabel() {
    const slot = this.item.decoration_asset?.slot;
    return slot ? i18n(`gamified_shop.slots.${slot}`) : "";
  }

  get purchasedCount() {
    return this.args.purchasedCounts?.[this.item.id] ?? 0;
  }

  get owned() {
    const assetId = this.item.decoration_asset?.id;

    return (
      this.purchasedCount > 0 ||
      (assetId && (this.args.ownedAssetIds ?? []).includes(assetId))
    );
  }

  get unlimitedStock() {
    return this.item.stock === null || this.item.stock === undefined;
  }

  get outOfStock() {
    return this.item.stock === 0;
  }

  get stockLabel() {
    if (this.unlimitedStock) {
      return i18n("gamified_shop.store.unlimited");
    }

    return this.item.stock;
  }

  get limitReached() {
    const limit = this.item.purchase_limit_per_user;

    return (
      limit !== null && limit !== undefined && this.purchasedCount >= limit
    );
  }

  get insufficientBalance() {
    return (
      typeof this.args.balance === "number" &&
      this.args.balance < this.item.price
    );
  }

  get buyDisabled() {
    return (
      this.outOfStock ||
      this.limitReached ||
      this.insufficientBalance ||
      this.args.purchasing
    );
  }

  <template>
    <div class="gds-shop-item-card" data-item-id={{this.item.id}}>
      {{#if this.item.decoration_asset.image_url}}
        <div class="gds-shop-item-card__image-wrapper">
          <img
            class="gds-shop-item-card__image"
            src={{this.item.decoration_asset.image_url}}
            alt={{this.item.name}}
            loading="lazy"
          />
        </div>
      {{/if}}

      <div class="gds-shop-item-card__body">
        <div class="gds-shop-item-card__header">
          <span class="gds-shop-item-card__name">{{this.item.name}}</span>

          {{#if this.owned}}
            <span class="gds-badge gds-badge--owned">
              {{i18n "gamified_shop.store.owned"}}
            </span>
          {{/if}}
        </div>

        <span class="gds-shop-item-card__slot">{{this.slotLabel}}</span>

        {{#if this.item.description}}
          <p class="gds-shop-item-card__description">
            {{this.item.description}}
          </p>
        {{/if}}

        <dl class="gds-shop-item-card__meta">
          <div class="gds-shop-item-card__meta-entry">
            <dt>{{i18n "gamified_shop.store.price"}}</dt>
            <dd class="gds-shop-item-card__price">{{this.item.price}}</dd>
          </div>
          <div class="gds-shop-item-card__meta-entry">
            <dt>{{i18n "gamified_shop.store.stock"}}</dt>
            <dd>
              {{#if this.outOfStock}}
                <span class="gds-badge gds-badge--out-of-stock">
                  {{i18n "gamified_shop.store.out_of_stock"}}
                </span>
              {{else}}
                {{this.stockLabel}}
              {{/if}}
            </dd>
          </div>
        </dl>

        {{#if this.item.purchase_limit_per_user}}
          <span class="gds-shop-item-card__limit">
            {{i18n
              "gamified_shop.store.purchase_limit"
              count=this.item.purchase_limit_per_user
            }}
          </span>
        {{/if}}
      </div>

      <div class="gds-shop-item-card__actions">
        <DButton
          class="btn-primary gds-shop-item-card__buy"
          @label="gamified_shop.store.buy"
          @disabled={{this.buyDisabled}}
          @isLoading={{@purchasing}}
          @action={{fn @onBuy this.item}}
        />
      </div>
    </div>
  </template>
}
