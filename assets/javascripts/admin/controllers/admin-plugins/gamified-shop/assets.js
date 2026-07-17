import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const BASE_URL = "/admin/plugins/gamified-shop";

const IMAGE_SLOTS = ["avatar_frame", "user_card_background"];
const SLOTS = ["avatar_frame", "username_style", "user_card_background"];

// Mirrors GamifiedShop::StylePresets — preset key => color param names.
const STYLE_PRESETS = {
  username_solid: ["color"],
  username_gradient: ["from", "to"],
  username_glow: ["color"],
  username_rainbow: [],
};

export default class AdminPluginsGamifiedShopAssetsController extends Controller {
  @service currentUser;
  @service dialog;

  @tracked assets = [];

  @tracked showForm = false;
  @tracked saving = false;
  // null = the form is creating a new asset; an id = editing that asset.
  @tracked editingId = null;

  @tracked formName = "";
  @tracked formSlot = "avatar_frame";
  @tracked formUploadId = null;
  @tracked formImageUrl = null;
  @tracked formPreset = null;
  @tracked formParamColor = "#ff0000";
  @tracked formParamFrom = "#ff0000";
  @tracked formParamTo = "#0000ff";
  @tracked formCustomCss = "";

  get slotOptions() {
    return SLOTS.map((slot) => ({
      id: slot,
      name: i18n(`gamified_shop.slots.${slot}`),
    }));
  }

  get presetOptions() {
    // Raw preset keys are shown until dedicated i18n keys exist.
    return Object.keys(STYLE_PRESETS).map((key) => ({ id: key, name: key }));
  }

  get formIsImageSlot() {
    return IMAGE_SLOTS.includes(this.formSlot);
  }

  get formIsUsernameStyle() {
    return this.formSlot === "username_style";
  }

  get showColorParam() {
    return (
      this.formPreset === "username_solid" || this.formPreset === "username_glow"
    );
  }

  get showGradientParams() {
    return this.formPreset === "username_gradient";
  }

  get rows() {
    return this.assets.map((asset) => ({
      asset,
      slotLabel: i18n(`gamified_shop.slots.${asset.slot}`),
      // In-use is now informational only — deletion is always allowed and
      // cascades the cleanup server-side.
      inUseLabel: asset.in_use ? i18n("gamified_shop.admin.assets.in_use") : "",
    }));
  }

  @action
  newAsset() {
    this.editingId = null;
    this.showForm = true;
    this.formName = "";
    this.formSlot = "avatar_frame";
    this.formUploadId = null;
    this.formImageUrl = null;
    this.formPreset = null;
    this.formParamColor = "#ff0000";
    this.formParamFrom = "#ff0000";
    this.formParamTo = "#0000ff";
    this.formCustomCss = "";
  }

  @action
  editAsset(asset) {
    this.editingId = asset.id;
    this.showForm = true;
    this.formName = asset.name;
    this.formSlot = asset.slot;
    this.formUploadId = asset.upload_id ?? null;
    this.formImageUrl = asset.image_url ?? null;
    this.formPreset = asset.style_preset ?? null;
    this.formCustomCss = asset.custom_css ?? "";

    const params = asset.style_params || {};
    this.formParamColor = params.color ?? "#ff0000";
    this.formParamFrom = params.from ?? "#ff0000";
    this.formParamTo = params.to ?? "#0000ff";
  }

  @action
  cancel() {
    this.showForm = false;
    this.editingId = null;
  }

  @action
  updateFormSlot(slot) {
    this.formSlot = slot;
    this.formUploadId = null;
    this.formImageUrl = null;
    this.formPreset = null;
    this.formCustomCss = "";
  }

  @action
  updateFormPreset(preset) {
    this.formPreset = preset;
  }

  @action
  uploadDone(upload) {
    this.formUploadId = upload.id;
    this.formImageUrl = upload.url;
  }

  @action
  uploadDeleted() {
    this.formUploadId = null;
    this.formImageUrl = null;
  }

  @action
  async save() {
    const editing = this.editingId != null;
    const data = { name: this.formName, slot: this.formSlot };

    if (this.formIsImageSlot) {
      data.upload_id = this.formUploadId;
    } else {
      // Send style fields explicitly (empty when cleared) so an edit can
      // actually clear a preset/CSS rather than only add to it.
      data.style_preset = this.formPreset || "";

      const params = {};
      const paramNames = STYLE_PRESETS[this.formPreset] || [];
      if (paramNames.includes("color")) {
        params.color = this.formParamColor;
      }
      if (paramNames.includes("from")) {
        params.from = this.formParamFrom;
      }
      if (paramNames.includes("to")) {
        params.to = this.formParamTo;
      }
      if (Object.keys(params).length > 0) {
        data.style_params = params;
      }

      // Custom CSS is admin-only (ADR-0002); the backend also enforces this.
      // Admins always send it (possibly empty, to clear); non-admins never
      // send it, so a stored value set by an admin is preserved.
      if (this.currentUser?.admin) {
        data.custom_css = this.formCustomCss || "";
      }
    }

    this.saving = true;
    try {
      const result = await ajax(
        editing
          ? `${BASE_URL}/assets/${this.editingId}.json`
          : `${BASE_URL}/assets.json`,
        { type: editing ? "PUT" : "POST", data }
      );
      if (editing) {
        this.assets = this.assets.map((a) =>
          a.id === result.asset.id ? result.asset : a
        );
      } else {
        this.assets = [...this.assets, result.asset];
      }
      this.showForm = false;
      this.editingId = null;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  deleteAsset(asset) {
    this.dialog.yesNoConfirm({
      message: i18n("gamified_shop.admin.assets.delete_confirm"),
      didConfirm: async () => {
        try {
          await ajax(`${BASE_URL}/assets/${asset.id}.json`, {
            type: "DELETE",
          });
          this.assets = this.assets.filter((a) => a.id !== asset.id);
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }
}
