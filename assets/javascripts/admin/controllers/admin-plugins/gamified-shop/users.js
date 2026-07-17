import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const BASE_URL = "/admin/plugins/gamified-shop";

export default class AdminPluginsGamifiedShopUsersController extends Controller {
  @service currentUser;
  @service dialog;
  @service siteSettings;

  @tracked assets = [];

  @tracked username = null;
  @tracked loading = false;

  @tracked shopUser = null;
  @tracked balance = 0;
  @tracked decorations = [];
  @tracked ledger = [];

  @tracked adjustAmount = null;
  @tracked adjustDescription = "";
  @tracked adjusting = false;

  @tracked grantAssetId = null;
  @tracked grantDurationOption = "permanent";
  @tracked grantExpiresAt = "";
  @tracked granting = false;

  get canGrant() {
    return (
      this.currentUser.admin ||
      (this.currentUser.moderator &&
        this.siteSettings.gamified_shop_allow_moderator_grants)
    );
  }

  get canRevoke() {
    return this.currentUser.admin;
  }

  get balanceLabel() {
    return i18n("gamified_shop.balance_label", {
      currency: this.siteSettings.gamified_shop_currency_name,
      amount: this.balance,
    });
  }

  get assetOptions() {
    return this.assets.map((asset) => ({
      id: asset.id,
      name: `${asset.name} (${i18n(`gamified_shop.slots.${asset.slot}`)})`,
    }));
  }

  get grantDurationOptions() {
    return [
      {
        id: "permanent",
        name: i18n("gamified_shop.admin.users.grant_duration_permanent"),
      },
      {
        id: "7",
        name: i18n("gamified_shop.admin.users.grant_duration_days", {
          count: 7,
        }),
      },
      {
        id: "30",
        name: i18n("gamified_shop.admin.users.grant_duration_days", {
          count: 30,
        }),
      },
      {
        id: "90",
        name: i18n("gamified_shop.admin.users.grant_duration_days", {
          count: 90,
        }),
      },
      {
        id: "custom",
        name: i18n("gamified_shop.admin.users.grant_duration_custom"),
      },
    ];
  }

  get grantIsCustom() {
    return this.grantDurationOption === "custom";
  }

  get decorationRows() {
    return this.decorations.map((decoration) => ({
      decoration,
      assetName: decoration.decoration_asset?.name,
      slotLabel: decoration.decoration_asset
        ? i18n(`gamified_shop.slots.${decoration.decoration_asset.slot}`)
        : "",
      sourceLabel: i18n(
        `gamified_shop.decorations.source.${decoration.source}`
      ),
      equippedLabel: decoration.equipped
        ? i18n("gamified_shop.decorations.equipped")
        : "",
      neverExpires: !decoration.expires_at,
    }));
  }

  @action
  updateUsername(selected) {
    this.username = Array.isArray(selected) ? selected[0] : selected;
  }

  @action
  async findUser() {
    if (!this.username) {
      return;
    }

    this.loading = true;
    try {
      const userResult = await ajax(
        `/u/${encodeURIComponent(this.username)}.json`
      );
      const result = await ajax(`${BASE_URL}/users/${userResult.user.id}.json`);

      this.shopUser = result.user;
      this.balance = result.balance;
      this.decorations = result.decorations;
      this.ledger = result.ledger;
      this.adjustAmount = null;
      this.adjustDescription = "";
      this.grantAssetId = null;
      this.grantDurationOption = "permanent";
      this.grantExpiresAt = "";
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  updateGrantAssetId(assetId) {
    this.grantAssetId = assetId;
  }

  @action
  updateGrantDuration(option) {
    this.grantDurationOption = option;
  }

  @action
  async adjustPoints() {
    if (!this.shopUser) {
      return;
    }

    this.adjusting = true;
    try {
      const result = await ajax(
        `${BASE_URL}/users/${this.shopUser.id}/points.json`,
        {
          type: "POST",
          data: {
            amount: this.adjustAmount,
            description: this.adjustDescription,
          },
        }
      );
      this.balance = result.balance;
      this.ledger = [result.entry, ...this.ledger];
      this.adjustAmount = null;
      this.adjustDescription = "";
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.adjusting = false;
    }
  }

  @action
  async grantDecoration() {
    if (!this.shopUser || !this.grantAssetId) {
      return;
    }

    const data = { decoration_asset_id: this.grantAssetId };
    if (this.grantDurationOption === "custom") {
      if (this.grantExpiresAt) {
        data.expires_at = this.grantExpiresAt;
      }
    } else if (this.grantDurationOption !== "permanent") {
      data.duration_days = this.grantDurationOption;
    }

    this.granting = true;
    try {
      const result = await ajax(
        `${BASE_URL}/users/${this.shopUser.id}/decorations.json`,
        {
          type: "POST",
          data,
        }
      );
      this.decorations = [result.decoration, ...this.decorations];
      this.grantAssetId = null;
      this.grantDurationOption = "permanent";
      this.grantExpiresAt = "";
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.granting = false;
    }
  }

  @action
  revokeDecoration(decoration) {
    this.dialog.yesNoConfirm({
      message: i18n("gamified_shop.admin.users.revoke_confirm"),
      didConfirm: async () => {
        try {
          await ajax(
            `${BASE_URL}/users/${this.shopUser.id}/decorations/${decoration.id}.json`,
            { type: "DELETE" }
          );
          // Revoke removes the decoration entirely; drop it from the list to
          // match a reload.
          this.decorations = this.decorations.filter(
            (d) => d.id !== decoration.id
          );
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }
}
