# Discourse Decorator Shop

<p align="right"><a href="./README.zh_CN.md">中文</a></p>

A Discourse plugin that adds an **auditable, self-owned point economy** and a **shop** where members spend points on visual decorations — avatar frames, username styles, and user card backgrounds. Members earn points through community activity (creating topics, replying, receiving likes) or admin grants, then spend them in a configurable store.

> Status: **v0.1.0 (MVP)**. Targets self-hosted Discourse on the `stable` channel. Invite-code and group-level products are planned for phase 2.

## Features

- **Point economy** — an append-only, fully auditable ledger. Balances are a cache that always equals the sum of a user's entries; entries are never deleted. Negative balances are allowed (rewards can be clawed back), and purchases are blocked while the balance is below the price.
- **Behavior earning** — configurable points for creating a topic, posting a reply, and receiving a like, bounded by a daily cap. Deleting content (or unliking) claws points back; recovering content restores them. PMs, whispers, bots, self-likes and edits never earn.
- **Shop & purchases** — buy decorations with points in a single atomic transaction: balance, listing, stock (unlimited when blank) and per-user purchase limits are all enforced server-side. A failed purchase never spends points.
- **Decorations** — three slots (avatar frame, username style, user card background); one equipped per slot, equipping replaces the incumbent. Images use Discourse's native uploads; username styles use a built-in preset library plus, for admins only, safe custom CSS.
- **Public balances** — shown everywhere as `<currency>: <amount>` (currency name is configurable) on the store, user card and profile.
- **Admin tools** — manage items, decoration assets, per-user points/decorations, order refunds, and browse the point ledger. All staff actions are recorded in Discourse's staff action log.
- **Bilingual** — ships with English and Simplified Chinese locales.
- **Accessible** — animated decorations respect `prefers-reduced-motion`; decorations are never rendered in topic lists.

## Requirements

- A **self-hosted** Discourse instance (standard hosting does not allow third-party plugins).
- The `stable` channel (the plugin is written against stable-channel APIs).

## Installation

Follow the standard [Discourse plugin installation guide](https://meta.discourse.org/t/install-plugins-in-discourse/19157):

1. Add the repository to your `app.yml`:

   ```yaml
   hooks:
     after_code:
       - exec:
           cd: $home/plugins
           cmd:
             - git clone https://github.com/L1ulee/discourse-decorator-shop.git
   ```

2. Rebuild the container:

   ```bash
   cd /var/discourse
   ./launcher rebuild app
   ```

3. In the admin panel, go to **Settings → Plugins** and enable **`gamified_shop_enabled`**.

## Configuration

All settings live under **Admin → Settings → Plugins** (search "gamified shop"):

| Setting | Default | Description |
| --- | --- | --- |
| `gamified_shop_enabled` | `false` | Master switch for the plugin. |
| `gamified_shop_currency_name` | `Points` | Display name of the currency (e.g. `Credits`). Balances render as `<name>: <amount>`. |
| `gamified_shop_topic_created_points` | `5` | Points earned for creating a topic. `0` disables. |
| `gamified_shop_reply_created_points` | `2` | Points earned for posting a reply. `0` disables. |
| `gamified_shop_like_received_points` | `1` | Points earned when your post is liked. `0` disables. |
| `gamified_shop_daily_earn_cap` | `100` | Max points earned per day from behavior (gross; reversals don't refund headroom). `0` means no cap. |
| `gamified_shop_allow_moderator_grants` | `false` | Let moderators **grant** points/decorations. Deducting points and revoking decorations stay admin-only. |

## Usage

- **Members** visit `/gamified-shop` to browse the store and buy decorations, and `/gamified-shop` → *My decorations* to equip or unequip what they own.
- **Admins** manage everything under **Admin → Plugins → Decoration Shop**: items, decoration assets, per-user points and decorations, order refunds, and the point ledger.

### Decoration assets

- **Avatar frames** and **user card backgrounds** are images uploaded through Discourse's native upload system (GIF/WebP/PNG/JPEG). Animation is inferred from the file.
- **Username styles** use a preset library (solid / gradient / glow / rainbow) with color parameters. Admins may additionally write **custom CSS** — restricted to a declaration block that the plugin wraps in its own namespaced selector, with strict validation (no selectors, at-rules, external URLs, or resource-loading functions; 4 KB cap). Moderators can create preset/image assets but not custom-CSS assets.

## Development

This is a Discourse plugin and runs inside a Discourse checkout — there is no standalone build.

```bash
# Symlink the plugin into a Discourse dev checkout
ln -s /path/to/discourse-decorator-shop plugins/discourse-decorator-shop

# Run migrations
bin/rake db:migrate

# Run this plugin's specs
LOAD_PLUGINS=1 bundle exec rspec plugins/discourse-decorator-shop/spec

# A single file or example
LOAD_PLUGINS=1 bundle exec rspec plugins/discourse-decorator-shop/spec/lib/gamified_shop/purchases_spec.rb
```

Continuous integration runs the official Discourse plugin workflow (specs + linting) on every push and pull request; see [`.github/workflows/`](./.github/workflows/).

## License

[MIT](./LICENSE)
