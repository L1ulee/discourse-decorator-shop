import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const BASE_URL = "/admin/plugins/gamified-shop";
const PAGE_SIZE = 50;

export default class AdminPluginsGamifiedShopOrdersController extends Controller {
  @service dialog;

  @tracked orders = [];
  @tracked loading = false;

  @tracked filterUsername = "";
  @tracked filterStatus = null;
  @tracked page = 0;

  get statusOptions() {
    return ["fulfilled", "refunded"].map((status) => ({
      id: status,
      name: i18n(`gamified_shop.admin.orders.status.${status}`),
    }));
  }

  get rows() {
    return this.orders.map((order) => ({
      order,
      statusLabel: i18n(`gamified_shop.admin.orders.status.${order.status}`),
      refundable: order.status !== "refunded",
    }));
  }

  get hasPrev() {
    return this.page > 0;
  }

  get hasNext() {
    return this.orders.length === PAGE_SIZE;
  }

  get prevDisabled() {
    return !this.hasPrev;
  }

  get nextDisabled() {
    return !this.hasNext;
  }

  @action
  updateFilterStatus(status) {
    this.filterStatus = status;
  }

  @action
  filter() {
    this.page = 0;
    this.loadOrders();
  }

  @action
  prevPage() {
    if (this.hasPrev) {
      this.page = this.page - 1;
      this.loadOrders();
    }
  }

  @action
  nextPage() {
    if (this.hasNext) {
      this.page = this.page + 1;
      this.loadOrders();
    }
  }

  @action
  async loadOrders() {
    const data = { page: this.page };
    if (this.filterUsername) {
      data.username = this.filterUsername;
    }
    if (this.filterStatus) {
      data.status = this.filterStatus;
    }

    this.loading = true;
    try {
      const result = await ajax(`${BASE_URL}/orders.json`, { data });
      this.orders = result.orders;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  refundOrder(order) {
    this.dialog.yesNoConfirm({
      message: i18n("gamified_shop.admin.orders.refund_confirm"),
      didConfirm: async () => {
        try {
          const result = await ajax(
            `${BASE_URL}/orders/${order.id}/refund.json`,
            { type: "POST" }
          );
          this.orders = this.orders.map((o) =>
            o.id === result.order.id ? result.order : o
          );
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }
}
