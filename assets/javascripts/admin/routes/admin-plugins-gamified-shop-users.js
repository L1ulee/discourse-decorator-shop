import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class AdminPluginsGamifiedShopUsersRoute extends Route {
  async model() {
    // Needed for the "grant decoration" asset select.
    const result = await ajax("/admin/plugins/gamified-shop/assets.json");
    return { assets: result.assets };
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.assets = model.assets;
  }
}
