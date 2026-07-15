import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class AdminPluginsGamifiedShopAssetsRoute extends Route {
  async model() {
    const result = await ajax("/admin/plugins/gamified-shop/assets.json");
    return { assets: result.assets };
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.assets = model.assets;
    controller.showForm = false;
  }
}
