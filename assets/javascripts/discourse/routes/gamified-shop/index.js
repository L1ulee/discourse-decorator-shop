import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class GamifiedShopIndexRoute extends DiscourseRoute {
  model() {
    return ajax("/gamified-shop/store.json");
  }

  titleToken() {
    return i18n("gamified_shop.nav.store");
  }
}
