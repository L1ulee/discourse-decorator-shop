import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class AdminPluginsGamifiedShopOrdersRoute extends Route {
  async model() {
    const result = await ajax("/admin/plugins/gamified-shop/orders.json");
    return { orders: result.orders };
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.orders = model.orders;
    controller.page = 0;
  }
}
