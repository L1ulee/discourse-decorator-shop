export default function () {
  this.route("gamified-shop", { path: "/gamified-shop" }, function () {
    this.route("decorations");
  });
}
