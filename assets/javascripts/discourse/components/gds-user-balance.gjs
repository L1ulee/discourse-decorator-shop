import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

// Public balance line, rendered identically everywhere (PRD 12):
// "<currency>: <amount>", e.g. "Credits: 128".
export default class GdsUserBalance extends Component {
  @service siteSettings;

  get label() {
    return i18n("gamified_shop.balance_label", {
      currency: this.siteSettings.gamified_shop_currency_name,
      amount: this.args.balance ?? 0,
    });
  }

  <template>
    <span class="gds-balance" ...attributes>{{this.label}}</span>
  </template>
}
