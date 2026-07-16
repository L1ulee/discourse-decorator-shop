import { apiInitializer } from "discourse/lib/api";

// Post stream decoration integration (PRD 12).
//
// The post serializer ships `gamified_shop` as a plain map of equipped slots
// ({ avatar_frame: assetId?, username_style: assetId? }); all rendering is
// driven by CSS classes. addPostClassesCallback applies them to the post
// wrapper `div.topic-post` (NOT the inner <article>), so the CSS anchors on
// the class:
//   - gds-af-<assetId>  avatar frame (compiled stylesheet + gamified-shop.scss)
//   - gds-un-<assetId>  username style (compiled stylesheet targets
//                       `.gds-un-<id> .names .first a`)
//
// Deliberately no widget decorators here — `addPostClassesCallback` is the
// long-stable API that survives the Glimmer post stream.
export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (!siteSettings.gamified_shop_enabled) {
    return;
  }

  // On the Glimmer post stream this makes the serializer field tracked, so an
  // equip/unequip that updates the post model re-renders classes. Guarded
  // because older cores predate this API; the attribute itself still arrives
  // with the post JSON either way.
  api.addTrackedPostProperties?.("gamified_shop");

  api.addPostClassesCallback((attrs) => {
    const equipped = attrs?.gamified_shop;

    if (!equipped) {
      return;
    }

    const classes = [];

    if (equipped.avatar_frame) {
      classes.push(`gds-af-${equipped.avatar_frame}`);
    }

    if (equipped.username_style) {
      classes.push(`gds-un-${equipped.username_style}`);
    }

    if (classes.length > 0) {
      return classes;
    }
  });
});
