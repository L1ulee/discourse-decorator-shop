import { Input, Textarea } from "@ember/component";
import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
    <div class="gamified-shop-admin-assets">
      <div class="gamified-shop-admin__controls">
        <DButton
          class="btn-primary gamified-shop-admin-assets__new"
          @icon="plus"
          @label="gamified_shop.admin.assets.new"
          @action={{@controller.newAsset}}
        />
      </div>

      {{#if @controller.showForm}}
        <div class="gamified-shop-admin-form gamified-shop-admin-assets__form">
          <div class="gamified-shop-admin-form__row">
            <label>{{i18n "gamified_shop.admin.assets.name"}}</label>
            <TextField @value={{@controller.formName}} />
          </div>

          <div class="gamified-shop-admin-form__row">
            <label>{{i18n "gamified_shop.admin.assets.slot"}}</label>
            <ComboBox
              @content={{@controller.slotOptions}}
              @value={{@controller.formSlot}}
              @onChange={{@controller.updateFormSlot}}
            />
          </div>

          {{#if @controller.formIsImageSlot}}
            <div class="gamified-shop-admin-form__row">
              <label>{{i18n "gamified_shop.admin.assets.image"}}</label>
              <UppyImageUploader
                @id="gamified-shop-asset-uploader"
                @type="gamified_shop_decoration"
                @imageUrl={{@controller.formImageUrl}}
                @onUploadDone={{@controller.uploadDone}}
                @onUploadDeleted={{@controller.uploadDeleted}}
              />
            </div>
          {{/if}}

          {{#if @controller.formIsUsernameStyle}}
            <div class="gamified-shop-admin-form__row">
              <label>{{i18n "gamified_shop.admin.assets.style_preset"}}</label>
              <ComboBox
                @content={{@controller.presetOptions}}
                @value={{@controller.formPreset}}
                @onChange={{@controller.updateFormPreset}}
              />
            </div>

            {{#if @controller.showColorParam}}
              <div class="gamified-shop-admin-form__row">
                <label>{{i18n "gamified_shop.admin.assets.style_params"}}</label>
                <Input @type="color" @value={{@controller.formParamColor}} />
              </div>
            {{/if}}

            {{#if @controller.showGradientParams}}
              <div class="gamified-shop-admin-form__row">
                <label>{{i18n "gamified_shop.admin.assets.style_params"}}</label>
                <Input @type="color" @value={{@controller.formParamFrom}} />
                <Input @type="color" @value={{@controller.formParamTo}} />
              </div>
            {{/if}}

            {{#if @controller.currentUser.admin}}
              <div class="gamified-shop-admin-form__row">
                <label>{{i18n "gamified_shop.admin.assets.custom_css"}}</label>
                <Textarea
                  class="gamified-shop-admin-assets__custom-css"
                  @value={{@controller.formCustomCss}}
                />
              </div>
            {{/if}}
          {{/if}}

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

      <table class="gamified-shop-admin-table gamified-shop-admin-assets__table">
        <thead>
          <tr>
            <th>{{i18n "gamified_shop.admin.assets.name"}}</th>
            <th>{{i18n "gamified_shop.admin.assets.slot"}}</th>
            <th>{{i18n "gamified_shop.admin.assets.image"}}</th>
            <th>{{i18n "gamified_shop.admin.assets.style_preset"}}</th>
            <th>{{i18n "gamified_shop.admin.assets.in_use"}}</th>
            <th>{{i18n "gamified_shop.admin.actions"}}</th>
          </tr>
        </thead>
        <tbody>
          {{#each @controller.rows key="asset.id" as |row|}}
            <tr class="gamified-shop-admin-assets__row">
              <td>{{row.asset.name}}</td>
              <td>{{row.slotLabel}}</td>
              <td>
                {{#if row.asset.image_url}}
                  <img
                    class="gamified-shop-admin-assets__preview"
                    src={{row.asset.image_url}}
                    alt={{i18n "gamified_shop.admin.assets.preview"}}
                    width="40"
                    height="40"
                  />
                {{/if}}
              </td>
              <td>{{row.asset.style_preset}}</td>
              <td>{{row.inUseLabel}}</td>
              <td>
                <DButton
                  class="btn-danger"
                  @icon="trash-can"
                  @label="gamified_shop.admin.assets.delete"
                  @action={{fn @controller.deleteAsset row.asset}}
                  @disabled={{row.deleteDisabled}}
                />
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    </div>
  </template>
);
