import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import GdsUserBalance from "discourse/plugins/discourse-decorator-shop/discourse/components/gds-user-balance";
import { sizeAvatarFrame } from "discourse/plugins/discourse-decorator-shop/discourse/lib/gds-avatar-frame";

// User profile decoration integration (PRD 12): balance line + equipped
// avatar frame overlay + username style class.
//
// `user-profile-primary` is a long-stable outlet inside the profile's
// primary textual section (outletArgs: model). The balance line renders
// declaratively; frame and username style require walking to elements this
// plugin does not own, so both are applied best-effort by a self-cleaning
// modifier:
//   - avatar frame: `span.gds-avatar-frame.gds-asset-<id>` appended to the
//     immediate parent of the profile's huge avatar image (position:relative
//     forced when needed, per gamified-shop.scss)
//   - username style: `gds-asset-<id>` added to the profile username
//     heading — the compiled stylesheet emits declarations for
//     `.gds-asset-<id>` on direct mounts
// If a lookup fails on a future core markup change, the decoration silently
// does not show; the balance line is unaffected.
export default class GamifiedShopProfile extends Component {
  static shouldRender(args, context) {
    return !!context.siteSettings.gamified_shop_enabled && !!args.model?.gamified_shop;
  }

  decorateProfile = modifier((element) => {
    const shop = this.args.outletArgs.model?.gamified_shop;

    if (!shop) {
      return;
    }

    const root = element.closest(".user-main") || element.closest(".about");

    if (!root) {
      return;
    }

    const cleanups = [];

    if (shop.avatar_frame) {
      const avatarImage = root.querySelector(".user-profile-avatar img.avatar");
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

    if (shop.username_style) {
      const nameElement =
        root.querySelector(".user-profile-names .username") ||
        root.querySelector(".primary-textual .username");

      if (nameElement) {
        const styleClass = `gds-asset-${shop.username_style}`;
        nameElement.classList.add(styleClass);
        cleanups.push(() => nameElement.classList.remove(styleClass));
      }
    }

    return () => cleanups.forEach((cleanup) => cleanup());
  });

  get shop() {
    return this.args.outletArgs.model?.gamified_shop;
  }

  <template>
    <div class="gds-user-profile-balance" {{this.decorateProfile}}>
      <GdsUserBalance @balance={{this.shop.balance}} />
    </div>
  </template>
}
