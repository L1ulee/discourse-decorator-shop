import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { longDate } from "discourse/lib/formatter";
import { i18n } from "discourse-i18n";

export default class GdsShopDecorationRow extends Component {
  get decoration() {
    return this.args.decoration;
  }

  get slotLabel() {
    const slot = this.decoration.decoration_asset?.slot;
    return slot ? i18n(`gamified_shop.slots.${slot}`) : "";
  }

  get sourceLabel() {
    return i18n(`gamified_shop.decorations.source.${this.decoration.source}`);
  }

  get expired() {
    const expiresAt = this.decoration.expires_at;
    return !!expiresAt && new Date(expiresAt) <= new Date();
  }

  get equipDisabled() {
    return this.expired || this.args.busy;
  }

  get expiryLabel() {
    if (!this.decoration.expires_at) {
      return i18n("gamified_shop.decorations.never_expires");
    }

    if (this.expired) {
      return i18n("gamified_shop.decorations.expired");
    }

    return i18n("gamified_shop.decorations.expires_at", {
      date: longDate(new Date(this.decoration.expires_at)),
    });
  }

  <template>
    <div
      class={{concatClass
        "gds-decoration-row"
        (if this.expired "gds-decoration-row--expired")
        (if this.decoration.equipped "gds-decoration-row--equipped")
      }}
      data-decoration-id={{this.decoration.id}}
    >
      {{#if this.decoration.decoration_asset.image_url}}
        <img
          class="gds-decoration-row__image"
          src={{this.decoration.decoration_asset.image_url}}
          alt={{this.decoration.decoration_asset.name}}
          loading="lazy"
        />
      {{/if}}

      <div class="gds-decoration-row__info">
        <div class="gds-decoration-row__name-line">
          <span class="gds-decoration-row__name">
            {{this.decoration.decoration_asset.name}}
          </span>

          {{#if this.expired}}
            <span class="gds-badge gds-badge--expired">
              {{i18n "gamified_shop.decorations.expired"}}
            </span>
          {{else if this.decoration.equipped}}
            <span class="gds-badge gds-badge--equipped">
              {{i18n "gamified_shop.decorations.equipped"}}
            </span>
          {{/if}}
        </div>

        <div class="gds-decoration-row__meta">
          <span class="gds-decoration-row__slot">{{this.slotLabel}}</span>
          <span class="gds-decoration-row__source">{{this.sourceLabel}}</span>
          <span class="gds-decoration-row__expiry">{{this.expiryLabel}}</span>
        </div>
      </div>

      <div class="gds-decoration-row__actions">
        {{#if this.decoration.equipped}}
          <DButton
            class="btn-default gds-decoration-row__unequip"
            @label="gamified_shop.decorations.unequip"
            @disabled={{@busy}}
            @isLoading={{@busy}}
            @action={{fn @onUnequip this.decoration}}
          />
        {{else}}
          <DButton
            class="btn-primary gds-decoration-row__equip"
            @label="gamified_shop.decorations.equip"
            @disabled={{this.equipDisabled}}
            @isLoading={{@busy}}
            @action={{fn @onEquip this.decoration}}
          />
        {{/if}}
      </div>
    </div>
  </template>
}
