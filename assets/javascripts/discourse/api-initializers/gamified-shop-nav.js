import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (!siteSettings.gamified_shop_enabled) {
    return;
  }

  // The shop endpoints require login; keep the link out of anonymous sidebars.
  if (!api.getCurrentUser()) {
    return;
  }

  api.addCommunitySectionLink({
    name: "gamified-shop",
    route: "gamified-shop.index",
    title: i18n("gamified_shop.title"),
    text: i18n("gamified_shop.title"),
    icon: "tag",
  });
});
