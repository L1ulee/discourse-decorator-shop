import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class GamifiedShopDecorationsRoute extends DiscourseRoute {
  model() {
    return ajax("/gamified-shop/me/decorations.json");
  }

  titleToken() {
    return i18n("gamified_shop.nav.my_decorations");
  }
}
