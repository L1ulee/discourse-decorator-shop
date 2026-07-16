import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class AdminPluginsGamifiedShopIndexRoute extends Route {
  @service currentUser;
  @service router;

  beforeModel() {
    // Items is the default tab, but it is admin-only; moderators land on
    // the staff-accessible assets tab instead.
    if (this.currentUser?.admin) {
      this.router.replaceWith("adminPlugins.gamified-shop.items");
    } else {
      this.router.replaceWith("adminPlugins.gamified-shop.assets");
    }
  }
}
