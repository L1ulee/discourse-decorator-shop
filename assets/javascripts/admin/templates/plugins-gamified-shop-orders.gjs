import { fn, hash } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import formatDate from "discourse/helpers/format-date";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
    <div class="gamified-shop-admin-orders">
      <div class="gamified-shop-admin__filters">
        <TextField
          @value={{@controller.filterUsername}}
          @placeholderKey="gamified_shop.admin.ledger.username"
        />
        <ComboBox
          @content={{@controller.statusOptions}}
          @value={{@controller.filterStatus}}
          @onChange={{@controller.updateFilterStatus}}
          @options={{hash none="gamified_shop.admin.filters.all"}}
        />
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
          class="gamified-shop-admin-table gamified-shop-admin-orders__table"
        >
          <thead>
            <tr>
              <th>{{i18n "gamified_shop.admin.ledger.username"}}</th>
              <th>{{i18n "gamified_shop.admin.orders.item"}}</th>
              <th>{{i18n "gamified_shop.admin.orders.price_paid"}}</th>
              <th>{{i18n "gamified_shop.admin.orders.status_label"}}</th>
              <th>{{i18n "gamified_shop.admin.orders.created_at"}}</th>
              <th>{{i18n "gamified_shop.admin.orders.refunded_at"}}</th>
              <th>{{i18n "gamified_shop.admin.actions"}}</th>
            </tr>
          </thead>
          <tbody>
            {{#each @controller.rows key="order.id" as |row|}}
              <tr class="gamified-shop-admin-orders__row">
                <td>{{row.order.username}}</td>
                <td>{{row.order.item_name}}</td>
                <td>{{row.order.price_paid}}</td>
                <td>{{row.statusLabel}}</td>
                <td>{{formatDate row.order.created_at format="medium"}}</td>
                <td>
                  {{#if row.order.refunded_at}}
                    {{formatDate row.order.refunded_at format="medium"}}
                  {{/if}}
                </td>
                <td>
                  {{#if row.refundable}}
                    <DButton
                      class="btn-danger"
                      @label="gamified_shop.admin.orders.refund"
                      @action={{fn @controller.refundOrder row.order}}
                    />
                  {{/if}}
                </td>
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
