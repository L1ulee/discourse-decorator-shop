import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import GdsShopDecorationRow from "./gds-shop-decoration-row";

const SLOTS = ["avatar_frame", "username_style", "user_card_background"];

export default class GdsShopDecorations extends Component {
  @service siteSettings;

  @tracked balance = this.args.model.balance;
  @tracked decorations = [...(this.args.model.decorations ?? [])];
  @tracked busyId = null;

  get balanceLabel() {
    return i18n("gamified_shop.balance_label", {
      currency: this.siteSettings.gamified_shop_currency_name,
      amount: this.balance,
    });
  }

  get groups() {
    return SLOTS.map((slot) => ({
      slot,
      label: i18n(`gamified_shop.slots.${slot}`),
      decorations: this.decorations.filter(
        (decoration) => decoration.decoration_asset?.slot === slot
      ),
    })).filter((group) => group.decorations.length > 0);
  }

  @action
  equip(decoration) {
    return this.toggle(decoration, "equip");
  }

  @action
  unequip(decoration) {
    return this.toggle(decoration, "unequip");
  }

  async toggle(decoration, verb) {
    this.busyId = decoration.id;

    try {
      const result = await ajax(
        `/gamified-shop/me/decorations/${decoration.id}/${verb}`,
        { type: "POST" }
      );
      const updated = result.decoration;

      this.decorations = this.decorations.map((existing) => {
        if (existing.id === updated.id) {
          return updated;
        }

        // Equipping fills the slot exclusively: the backend unequips any
        // incumbent in the same slot, so mirror that locally.
        if (
          verb === "equip" &&
          existing.equipped &&
          existing.decoration_asset?.slot === updated.decoration_asset?.slot
        ) {
          return { ...existing, equipped: false, displayable: false };
        }

        return existing;
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busyId = null;
    }
  }

  <template>
    <div class="gds-decorations">
      <div class="gds-decorations__header">
        <span class="gds-shop-balance">{{this.balanceLabel}}</span>
      </div>

      {{#if this.groups.length}}
        {{#each this.groups as |group|}}
          <section
            class="gds-decorations-group"
            data-slot={{group.slot}}
          >
            <h2 class="gds-decorations-group__title">{{group.label}}</h2>

            <div class="gds-decorations-group__rows">
              {{#each group.decorations as |decoration|}}
                <GdsShopDecorationRow
                  @decoration={{decoration}}
                  @busy={{eq this.busyId decoration.id}}
                  @onEquip={{this.equip}}
                  @onUnequip={{this.unequip}}
                />
              {{/each}}
            </div>
          </section>
        {{/each}}
      {{else}}
        <p class="gds-decorations__empty">
          {{i18n "gamified_shop.decorations.empty"}}
        </p>
      {{/if}}
    </div>
  </template>
}
