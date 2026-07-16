import RouteTemplate from "ember-route-template";
import GdsShopDecorations from "discourse/plugins/discourse-decorator-shop/discourse/components/gds-shop-decorations";

export default RouteTemplate(
  <template><GdsShopDecorations @model={{@model}} /></template>
);
