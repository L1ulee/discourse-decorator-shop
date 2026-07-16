import RouteTemplate from "ember-route-template";
import GdsShopStore from "discourse/plugins/discourse-decorator-shop/discourse/components/gds-shop-store";

export default RouteTemplate(
  <template><GdsShopStore @store={{@model}} /></template>
);
