import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class AdminPluginsGamifiedShopLedgerRoute extends Route {
  async model() {
    const result = await ajax("/admin/plugins/gamified-shop/ledger.json");
    return { entries: result.entries };
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.entries = model.entries;
    controller.page = 0;
  }
}
