import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import GdsUserBalance from "discourse/plugins/discourse-decorator-shop/discourse/components/gds-user-balance";
import { sizeAvatarFrame } from "discourse/plugins/discourse-decorator-shop/discourse/lib/gds-avatar-frame";

// User card decoration integration (PRD 12).
//
// Renders the public balance line inside the card's metadata section and, as
// a side effect, decorates the surrounding card DOM:
//   - card background: adds `gds-asset-<id>` to the `.user-card` root
//     (contract convention; the compiled stylesheet supplies
//     --gds-card-bg-image for that class)
//   - avatar frame: mounts `span.gds-avatar-frame.gds-asset-<id>` inside the
//     immediate parent of the card's huge avatar image, forcing
//     position:relative on it when needed (gamified-shop.scss requires a
//     positioned parent)
//
// The DOM walking (closest(".user-card") / avatar img lookup) is the only
// non-outlet surgery in this plugin; the modifier cleans up after itself and
// re-runs when the card is reused for another user, so a missing element
// degrades to "no decoration" rather than an error.
export default class GamifiedShopUserCard extends Component {
  static shouldRender(args, context) {
    return !!context.siteSettings.gamified_shop_enabled && !!args.user?.gamified_shop;
  }

  decorateCard = modifier((element) => {
    const shop = this.args.outletArgs.user?.gamified_shop;

    if (!shop) {
      return;
    }

    const card = element.closest(".user-card");

    if (!card) {
      return;
    }

    const cleanups = [];

    if (shop.user_card_background) {
      const backgroundClass = `gds-asset-${shop.user_card_background}`;
      card.classList.add(backgroundClass);
      cleanups.push(() => card.classList.remove(backgroundClass));
    }

    if (shop.username_style) {
      // Target the innermost username link/text, not the container: a
      // comma-list querySelector returns the first match in document order
      // (the ancestor .names__primary div), so the style would land on the
      // wrapper while the inner <a> keeps its own link colour (issue #2).
      const nameElement =
        card.querySelector(".name-username-wrapper") ||
        card.querySelector(".names__primary a") ||
        card.querySelector(".names .username a") ||
        card.querySelector(".names__primary") ||
        card.querySelector(".names .username");

      if (nameElement) {
        const usernameClass = `gds-asset-${shop.username_style}`;
        nameElement.classList.add(usernameClass);
        cleanups.push(() => nameElement.classList.remove(usernameClass));
      }
    }

    if (shop.avatar_frame) {
      const avatarImage = card.querySelector(".user-card-avatar img.avatar");
      const mount = avatarImage?.parentElement;

      if (mount) {
        if (getComputedStyle(mount).position === "static") {
          mount.style.setProperty("position", "relative");
          cleanups.push(() => mount.style.removeProperty("position"));
        }

        const frame = document.createElement("span");
        frame.classList.add("gds-avatar-frame", `gds-asset-${shop.avatar_frame}`);
        frame.setAttribute("aria-hidden", "true");
        mount.appendChild(frame);
        cleanups.push(sizeAvatarFrame(frame, avatarImage));
        cleanups.push(() => frame.remove());
      }
    }

    return () => cleanups.forEach((cleanup) => cleanup());
  });

  get shop() {
    return this.args.outletArgs.user?.gamified_shop;
  }

  <template>
    <div class="gds-user-card-balance" {{this.decorateCard}}>
      <GdsUserBalance @balance={{this.shop.balance}} />
    </div>
  </template>
}
