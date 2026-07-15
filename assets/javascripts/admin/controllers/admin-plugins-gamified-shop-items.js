import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const BASE_URL = "/admin/plugins/gamified-shop";

export default class AdminPluginsGamifiedShopItemsController extends Controller {
  @tracked items = [];
  @tracked assets = [];

  // null = form closed, "new" = creating, number = editing that item id
  @tracked editingId = null;
  @tracked saving = false;

  @tracked formName = "";
  @tracked formDescription = "";
  @tracked formPrice = 0;
  @tracked formStock = null;
  @tracked formLimit = null;
  @tracked formListed = false;
  @tracked formAssetId = null;

  get showForm() {
    return this.editingId !== null;
  }

  get isNew() {
    return this.editingId === "new";
  }

  get assetOptions() {
    return this.assets.map((asset) => ({
      id: asset.id,
      name: `${asset.name} (${i18n(`gamified_shop.slots.${asset.slot}`)})`,
    }));
  }

  get rows() {
    return this.items.map((item) => ({
      item,
      stockLabel:
        item.stock === null || item.stock === undefined
          ? i18n("gamified_shop.store.unlimited")
          : item.stock,
      limitLabel:
        item.purchase_limit_per_user === null ||
        item.purchase_limit_per_user === undefined
          ? i18n("gamified_shop.store.unlimited")
          : item.purchase_limit_per_user,
      listedLabel: item.listed
        ? i18n("gamified_shop.admin.items.listed")
        : i18n("gamified_shop.admin.items.unlisted"),
      assetLabel: item.decoration_asset
        ? `${item.decoration_asset.name} (${i18n(
            `gamified_shop.slots.${item.decoration_asset.slot}`
          )})`
        : "",
    }));
  }

  @action
  newItem() {
    this.editingId = "new";
    this.formName = "";
    this.formDescription = "";
    this.formPrice = 0;
    this.formStock = null;
    this.formLimit = null;
    this.formListed = false;
    this.formAssetId = null;
  }

  @action
  editItem(item) {
    this.editingId = item.id;
    this.formName = item.name;
    this.formDescription = item.description;
    this.formPrice = item.price;
    this.formStock = item.stock;
    this.formLimit = item.purchase_limit_per_user;
    this.formListed = item.listed;
    this.formAssetId = item.decoration_asset?.id;
  }

  @action
  cancel() {
    this.editingId = null;
  }

  @action
  updateFormAssetId(assetId) {
    this.formAssetId = assetId;
  }

  @action
  async save() {
    const data = {
      name: this.formName,
      description: this.formDescription,
      price: this.formPrice,
      stock: this.formStock,
      purchase_limit_per_user: this.formLimit,
      listed: !!this.formListed,
      decoration_asset_id: this.formAssetId,
    };

    this.saving = true;
    try {
      if (this.isNew) {
        const result = await ajax(`${BASE_URL}/items.json`, {
          type: "POST",
          data,
        });
        this.items = [...this.items, result.item];
      } else {
        const result = await ajax(`${BASE_URL}/items/${this.editingId}.json`, {
          type: "PUT",
          data,
        });
        this.items = this.items.map((item) =>
          item.id === result.item.id ? result.item : item
        );
      }
      this.editingId = null;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }
}
