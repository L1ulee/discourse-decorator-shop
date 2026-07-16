import { Input, Textarea } from "@ember/component";
import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
    <div class="gamified-shop-admin-items">
      <div class="gamified-shop-admin__controls">
        <DButton
          class="btn-primary gamified-shop-admin-items__new"
          @icon="plus"
          @label="gamified_shop.admin.items.new"
          @action={{@controller.newItem}}
        />
      </div>

      {{#if @controller.showForm}}
        <div class="gamified-shop-admin-form gamified-shop-admin-items__form">
          <div class="gamified-shop-admin-form__row">
            <label>{{i18n "gamified_shop.admin.items.name"}}</label>
            <TextField @value={{@controller.formName}} />
          </div>

          <div class="gamified-shop-admin-form__row">
            <label>{{i18n "gamified_shop.admin.items.description"}}</label>
            <Textarea @value={{@controller.formDescription}} />
          </div>

          <div class="gamified-shop-admin-form__row">
            <label>{{i18n "gamified_shop.admin.items.price"}}</label>
            <Input @type="number" min="0" @value={{@controller.formPrice}} />
          </div>

          <div class="gamified-shop-admin-form__row">
            <label>{{i18n "gamified_shop.admin.items.stock"}}</label>
            <Input @type="number" min="0" @value={{@controller.formStock}} />
          </div>

          <div class="gamified-shop-admin-form__row">
            <label>{{i18n "gamified_shop.admin.items.purchase_limit"}}</label>
            <Input @type="number" min="0" @value={{@controller.formLimit}} />
          </div>

          <div class="gamified-shop-admin-form__row">
            <label>
              <Input @type="checkbox" @checked={{@controller.formListed}} />
              {{i18n "gamified_shop.admin.items.listed"}}
            </label>
          </div>

          <div class="gamified-shop-admin-form__row">
            <label>{{i18n "gamified_shop.admin.items.asset"}}</label>
            <ComboBox
              @content={{@controller.assetOptions}}
              @value={{@controller.formAssetId}}
              @onChange={{@controller.updateFormAssetId}}
            />
          </div>

          <div class="gamified-shop-admin-form__actions">
            <DButton
              class="btn-primary"
              @label="gamified_shop.admin.items.save"
              @action={{@controller.save}}
              @disabled={{@controller.saving}}
            />
            <DButton
              @label="gamified_shop.admin.items.cancel"
              @action={{@controller.cancel}}
            />
          </div>
        </div>
      {{/if}}

      <table class="gamified-shop-admin-table gamified-shop-admin-items__table">
        <thead>
          <tr>
            <th>{{i18n "gamified_shop.admin.items.name"}}</th>
            <th>{{i18n "gamified_shop.admin.items.price"}}</th>
            <th>{{i18n "gamified_shop.admin.items.stock"}}</th>
            <th>{{i18n "gamified_shop.admin.items.purchase_limit"}}</th>
            <th>{{i18n "gamified_shop.admin.items.listed"}}</th>
            <th>{{i18n "gamified_shop.admin.items.asset"}}</th>
            <th>{{i18n "gamified_shop.admin.actions"}}</th>
          </tr>
        </thead>
        <tbody>
          {{#each @controller.rows key="item.id" as |row|}}
            <tr
              class="gamified-shop-admin-items__row
                {{unless row.item.listed 'gamified-shop-admin-items__row--unlisted'}}"
            >
              <td>{{row.item.name}}</td>
              <td>{{row.item.price}}</td>
              <td>{{row.stockLabel}}</td>
              <td>{{row.limitLabel}}</td>
              <td>{{row.listedLabel}}</td>
              <td>{{row.assetLabel}}</td>
              <td>
                <DButton
                  @icon="pencil"
                  @label="gamified_shop.admin.items.edit"
                  @action={{fn @controller.editItem row.item}}
                />
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    </div>
  </template>
);
