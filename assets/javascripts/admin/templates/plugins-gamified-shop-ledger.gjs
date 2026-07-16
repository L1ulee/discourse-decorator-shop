import { Input } from "@ember/component";
import { hash } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import formatDate from "discourse/helpers/format-date";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
    <div class="gamified-shop-admin-ledger">
      <div class="gamified-shop-admin__filters">
        <TextField
          @value={{@controller.filterUsername}}
          @placeholderKey="gamified_shop.admin.ledger.username"
        />
        <ComboBox
          @content={{@controller.entryTypeOptions}}
          @value={{@controller.filterEntryType}}
          @onChange={{@controller.updateFilterEntryType}}
          @options={{hash none="gamified_shop.admin.filters.all"}}
        />
        <label>
          {{i18n "gamified_shop.admin.ledger.from"}}
          <Input @type="date" @value={{@controller.filterFrom}} />
        </label>
        <label>
          {{i18n "gamified_shop.admin.ledger.to"}}
          <Input @type="date" @value={{@controller.filterTo}} />
        </label>
        <DButton
          class="btn-primary"
          @icon="filter"
          @label="gamified_shop.admin.ledger.filter"
          @action={{@controller.filter}}
          @disabled={{@controller.loading}}
        />
      </div>

      <ConditionalLoadingSpinner @condition={{@controller.loading}}>
        <table
          class="gamified-shop-admin-table gamified-shop-admin-ledger__table"
        >
          <thead>
            <tr>
              <th>{{i18n "gamified_shop.admin.ledger.created_at"}}</th>
              <th>{{i18n "gamified_shop.admin.ledger.user"}}</th>
              <th>{{i18n "gamified_shop.admin.ledger.entry_type"}}</th>
              <th>{{i18n "gamified_shop.admin.ledger.amount"}}</th>
              <th>{{i18n "gamified_shop.admin.ledger.balance_after"}}</th>
              <th>{{i18n "gamified_shop.admin.ledger.description"}}</th>
            </tr>
          </thead>
          <tbody>
            {{#each @controller.entries key="id" as |entry|}}
              <tr class="gamified-shop-admin-ledger__row">
                <td>{{formatDate entry.created_at format="medium"}}</td>
                <td>{{entry.username}}</td>
                <td>{{entry.entry_type}}</td>
                <td>{{entry.amount}}</td>
                <td>{{entry.balance_after}}</td>
                <td>{{entry.description}}</td>
              </tr>
            {{/each}}
          </tbody>
        </table>

        <div class="gamified-shop-admin__pagination">
          <DButton
            @icon="chevron-left"
            @label="gamified_shop.admin.prev_page"
            @action={{@controller.prevPage}}
            @disabled={{@controller.prevDisabled}}
          />
          <DButton
            @icon="chevron-right"
            @label="gamified_shop.admin.next_page"
            @action={{@controller.nextPage}}
            @disabled={{@controller.nextDisabled}}
          />
        </div>
      </ConditionalLoadingSpinner>
    </div>
  </template>
);
