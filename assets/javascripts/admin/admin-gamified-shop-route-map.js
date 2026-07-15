export default {
  resource: "admin.adminPlugins",
  path: "/plugins",

  map() {
    this.route("gamified-shop", function () {
      this.route("items");
      this.route("assets");
      this.route("users");
      this.route("orders");
      this.route("ledger");
    });
  },
};
