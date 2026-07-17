import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class AdminPluginsGamifiedShopItemsRoute extends Route {
  async model() {
    const [itemsResult, assetsResult] = await Promise.all([
      ajax("/admin/plugins/gamified-shop/items.json"),
      ajax("/admin/plugins/gamified-shop/assets.json"),
    ]);

    return { items: itemsResult.items, assets: assetsResult.assets };
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.items = model.items;
    controller.assets = model.assets;
    controller.editingId = null;
  }
}
