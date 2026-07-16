import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const BASE_URL = "/admin/plugins/gamified-shop";
const PAGE_SIZE = 50;

// Mirrors GamifiedShop::PointLedgerEntry::TYPES.
const ENTRY_TYPES = [
  "admin_grant",
  "admin_deduct",
  "event_reward",
  "event_reversal",
  "purchase_spend",
  "purchase_refund",
  "system_adjustment",
];

export default class AdminPluginsGamifiedShopLedgerController extends Controller {
  @tracked entries = [];
  @tracked loading = false;

  @tracked filterUsername = "";
  @tracked filterEntryType = null;
  @tracked filterFrom = "";
  @tracked filterTo = "";
  @tracked page = 0;

  get entryTypeOptions() {
    // Raw entry type keys are shown until dedicated i18n keys exist.
    return ENTRY_TYPES.map((type) => ({ id: type, name: type }));
  }

  get hasPrev() {
    return this.page > 0;
  }

  get hasNext() {
    return this.entries.length === PAGE_SIZE;
  }

  get prevDisabled() {
    return !this.hasPrev;
  }

  get nextDisabled() {
    return !this.hasNext;
  }

  @action
  updateFilterEntryType(entryType) {
    this.filterEntryType = entryType;
  }

  @action
  filter() {
    this.page = 0;
    this.loadEntries();
  }

  @action
  prevPage() {
    if (this.hasPrev) {
      this.page = this.page - 1;
      this.loadEntries();
    }
  }

  @action
  nextPage() {
    if (this.hasNext) {
      this.page = this.page + 1;
      this.loadEntries();
    }
  }

  @action
  async loadEntries() {
    const data = { page: this.page };
    if (this.filterUsername) {
      data.username = this.filterUsername;
    }
    if (this.filterEntryType) {
      data.entry_type = this.filterEntryType;
    }
    if (this.filterFrom) {
      data.from = this.filterFrom;
    }
    if (this.filterTo) {
      data.to = this.filterTo;
    }

    this.loading = true;
    try {
      const result = await ajax(`${BASE_URL}/ledger.json`, { data });
      this.entries = result.entries;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }
}
