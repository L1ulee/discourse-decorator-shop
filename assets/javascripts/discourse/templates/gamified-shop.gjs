import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import bodyClass from "discourse/helpers/body-class";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{bodyClass "gds-shop-body"}}

    <div class="gds-shop-page container">
      <div class="gds-shop-page__masthead">
        <h1 class="gds-shop-page__title">{{i18n "gamified_shop.title"}}</h1>

        <nav class="gds-shop-page__nav">
          <LinkTo
            @route="gamified-shop.index"
            class="gds-shop-page__nav-link"
          >
            {{i18n "gamified_shop.nav.store"}}
          </LinkTo>
          <LinkTo
            @route="gamified-shop.decorations"
            class="gds-shop-page__nav-link"
          >
            {{i18n "gamified_shop.nav.my_decorations"}}
          </LinkTo>
        </nav>
      </div>

      {{outlet}}
    </div>
  </template>
);
