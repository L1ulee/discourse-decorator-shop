import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import formatDate from "discourse/helpers/format-date";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";

export default RouteTemplate(
  <template>
    <div class="gamified-shop-admin-users">
      <div class="gamified-shop-admin-users__finder">
        <label>{{i18n "gamified_shop.admin.users.find"}}</label>
        <EmailGroupUserChooser
          @value={{@controller.username}}
          @onChange={{@controller.updateUsername}}
          @options={{hash maximum=1}}
        />
        <DButton
          class="btn-primary"
          @icon="magnifying-glass"
          @label="gamified_shop.admin.users.find"
          @action={{@controller.findUser}}
          @disabled={{@controller.loading}}
        />
      </div>

      <ConditionalLoadingSpinner @condition={{@controller.loading}}>
        {{#if @controller.shopUser}}
          <div class="gamified-shop-admin-users__details">
            <h3>{{@controller.shopUser.username}}</h3>

            <p class="gamified-shop-admin-users__balance">
              <strong>{{i18n "gamified_shop.admin.users.balance"}}:</strong>
              {{@controller.balanceLabel}}
            </p>

            {{#if @controller.canGrant}}
              <div
                class="gamified-shop-admin-form gamified-shop-admin-users__adjust"
              >
                <h4>{{i18n "gamified_shop.admin.users.adjust_points"}}</h4>
                <div class="gamified-shop-admin-form__row">
                  <label>{{i18n "gamified_shop.admin.users.amount"}}</label>
                  <Input @type="number" @value={{@controller.adjustAmount}} />
                </div>
                <div class="gamified-shop-admin-form__row">
                  <label>{{i18n "gamified_shop.admin.users.description"}}</label>
                  <TextField @value={{@controller.adjustDescription}} />
                </div>
                <div class="gamified-shop-admin-form__actions">
                  <DButton
                    class="btn-primary"
                    @label="gamified_shop.admin.users.apply"
                    @action={{@controller.adjustPoints}}
                    @disabled={{@controller.adjusting}}
                  />
                </div>
              </div>

              <div
                class="gamified-shop-admin-form gamified-shop-admin-users__grant"
              >
                <h4>{{i18n "gamified_shop.admin.users.grant_decoration"}}</h4>
                <div class="gamified-shop-admin-form__row">
                  <ComboBox
                    @content={{@controller.assetOptions}}
                    @value={{@controller.grantAssetId}}
                    @onChange={{@controller.updateGrantAssetId}}
                  />
                </div>
                <div class="gamified-shop-admin-form__row">
                  <label>
                    {{i18n "gamified_shop.admin.users.grant_duration"}}
                  </label>
                  <ComboBox
                    @content={{@controller.grantDurationOptions}}
                    @value={{@controller.grantDurationOption}}
                    @onChange={{@controller.updateGrantDuration}}
                  />
                  {{#if @controller.grantIsCustom}}
                    <label>
                      {{i18n "gamified_shop.admin.users.grant_expires_at"}}
                    </label>
                    <Input
                      @type="date"
                      @value={{@controller.grantExpiresAt}}
                    />
                  {{/if}}
                </div>
                <div class="gamified-shop-admin-form__actions">
                  <DButton
                    class="btn-primary"
                    @label="gamified_shop.admin.users.grant_decoration"
                    @action={{@controller.grantDecoration}}
                    @disabled={{@controller.granting}}
                  />
                </div>
              </div>
            {{/if}}

            <h4>{{i18n "gamified_shop.admin.users.decorations"}}</h4>
            <table
              class="gamified-shop-admin-table gamified-shop-admin-users__decorations"
            >
              <thead>
                <tr>
                  <th>{{i18n "gamified_shop.admin.assets.name"}}</th>
                  <th>{{i18n "gamified_shop.admin.assets.slot"}}</th>
                  <th>{{i18n "gamified_shop.admin.users.source"}}</th>
                  <th>{{i18n "gamified_shop.decorations.equipped"}}</th>
                  <th>{{i18n "gamified_shop.admin.users.expires"}}</th>
                  <th>{{i18n "gamified_shop.admin.actions"}}</th>
                </tr>
              </thead>
              <tbody>
                {{#each
                  @controller.decorationRows key="decoration.id" as |row|
                }}
                  <tr>
                    <td>{{row.assetName}}</td>
                    <td>{{row.slotLabel}}</td>
                    <td>{{row.sourceLabel}}</td>
                    <td>{{row.equippedLabel}}</td>
                    <td>
                      {{#if row.neverExpires}}
                        {{i18n "gamified_shop.decorations.never_expires"}}
                      {{else}}
                        {{formatDate row.decoration.expires_at format="medium"}}
                      {{/if}}
                    </td>
                    <td>
                      {{#if @controller.canRevoke}}
                        <DButton
                          class="btn-danger"
                          @label="gamified_shop.admin.users.revoke"
                          @action={{fn @controller.revokeDecoration row.decoration}}
                        />
                      {{/if}}
                    </td>
                  </tr>
                {{/each}}
              </tbody>
            </table>

            <h4>{{i18n "gamified_shop.admin.users.recent_ledger"}}</h4>
            <table
              class="gamified-shop-admin-table gamified-shop-admin-users__ledger"
            >
              <thead>
                <tr>
                  <th>{{i18n "gamified_shop.admin.ledger.created_at"}}</th>
                  <th>{{i18n "gamified_shop.admin.ledger.entry_type"}}</th>
                  <th>{{i18n "gamified_shop.admin.ledger.amount"}}</th>
                  <th>{{i18n "gamified_shop.admin.ledger.balance_after"}}</th>
                  <th>{{i18n "gamified_shop.admin.ledger.description"}}</th>
                </tr>
              </thead>
              <tbody>
                {{#each @controller.ledger key="id" as |entry|}}
                  <tr>
                    <td>{{formatDate entry.created_at format="medium"}}</td>
                    <td>{{entry.entry_type}}</td>
                    <td>{{entry.amount}}</td>
                    <td>{{entry.balance_after}}</td>
                    <td>{{entry.description}}</td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
          </div>
        {{/if}}
      </ConditionalLoadingSpinner>
    </div>
  </template>
);
