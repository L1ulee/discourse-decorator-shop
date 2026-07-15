import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class GamifiedShopRoute extends DiscourseRoute {
  @service currentUser;
  @service router;
  @service siteSettings;

  beforeModel() {
    if (!this.siteSettings.gamified_shop_enabled || !this.currentUser) {
      this.router.replaceWith("discovery.latest");
    }
  }

  titleToken() {
    return i18n("gamified_shop.title");
  }
}
