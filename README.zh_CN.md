# Discourse 装饰商城（Decorator Shop）

<p align="right"><a href="./README.md">English</a></p>

一款 Discourse 插件，提供**可审计的自持点数经济系统**和一个**商城**，让成员用点数购买视觉装饰——头像框、用户名样式、用户卡背景。成员通过社区行为（发布话题、回复、被点赞）或管理员发放获得点数，再到可配置的商城中消费。

> 状态：**v0.1.0（MVP）**。面向 `stable` 通道的自托管 Discourse。邀请码与群组等级商品为第二阶段计划。

## 功能特性

- **点数经济** —— 仅追加、完全可审计的账本。余额只是缓存，始终等于用户全部流水之和；流水永不删除。允许负余额（奖励可被回收），余额低于价格时禁止购买。
- **行为获点** —— 可配置发布话题、发布回复、收到点赞的得点，并受每日上限约束。删除内容（或取消点赞）会回收点数，恢复内容会补回。私信、whisper、机器人、给自己点赞、编辑帖子均不得点。
- **商城与购买** —— 用点数在单一原子事务中购买装饰：余额、上架状态、库存（留空为不限量）和每人限购全部在服务端校验。购买失败绝不扣点。
- **装饰系统** —— 三个槽位（头像框、用户名样式、用户卡背景）；每槽位同时只能启用一个，启用新装饰会替换旧的。图片走 Discourse 原生上传；用户名样式使用内置预设库，另外仅管理员可编写受控的自定义 CSS。
- **公开余额** —— 在商城、用户卡、资料页统一以 `<货币名>: <数量>` 展示（货币名可配置）。
- **管理工具** —— 管理商品、装饰资源、按用户调整点数/装饰、订单退款、查阅点数流水。所有管理操作记入 Discourse 的管理操作日志。
- **双语** —— 内置英文与简体中文。
- **无障碍** —— 动画装饰尊重 `prefers-reduced-motion`；装饰不会在话题列表中渲染。

## 环境要求

- **自托管** 的 Discourse 实例（标准托管套餐不允许安装第三方插件）。
- `stable` 版本通道（插件按 stable 通道的 API 编写）。

## 安装

按官方 [Discourse 插件安装指南](https://meta.discourse.org/t/install-plugins-in-discourse/19157)：

1. 在 `app.yml` 中添加仓库：

   ```yaml
   hooks:
     after_code:
       - exec:
           cd: $home/plugins
           cmd:
             - git clone https://github.com/L1ulee/discourse-decorator-shop.git
   ```

2. 重建容器：

   ```bash
   cd /var/discourse
   ./launcher rebuild app
   ```

3. 在管理后台进入 **设置 → 插件**，开启 **`gamified_shop_enabled`**。

## 配置项

全部设置位于 **管理后台 → 设置 → 插件**（搜索 "gamified shop"）：

| 设置项 | 默认值 | 说明 |
| --- | --- | --- |
| `gamified_shop_enabled` | `false` | 插件总开关。 |
| `gamified_shop_currency_name` | `Points` | 货币显示名（如 `Credits`）。余额展示为 `<货币名>: <数量>`。 |
| `gamified_shop_topic_created_points` | `5` | 发布话题得点，`0` 表示关闭。 |
| `gamified_shop_reply_created_points` | `2` | 发布回复得点，`0` 表示关闭。 |
| `gamified_shop_like_received_points` | `1` | 帖子被点赞时得点，`0` 表示关闭。 |
| `gamified_shop_daily_earn_cap` | `100` | 每日行为获点上限（按毛入账计，回收不退还额度）。`0` 表示不限。 |
| `gamified_shop_allow_moderator_grants` | `false` | 允许版主**发放**点数/装饰。扣减点数与撤销装饰仍仅限管理员。 |

## 使用

- **普通成员** 访问 `/gamified-shop` 浏览商城并购买装饰，在 `/gamified-shop` → *我的装饰* 中启用或停用已拥有的装饰。
- **管理员** 在 **管理后台 → 插件 → 装饰商城** 中管理一切：商品、装饰资源、按用户调整点数与装饰、订单退款、点数流水。

### 装饰资源

- **头像框** 与 **用户卡背景** 是通过 Discourse 原生上传系统上传的图片（GIF/WebP/PNG/JPEG），是否为动图由文件本身决定。
- **用户名样式** 使用预设库（纯色 / 渐变 / 发光 / 彩虹）并配置颜色参数。管理员还可编写**自定义 CSS**——仅限声明块，由插件包裹进自有命名空间选择器，并经严格校验（不允许选择器、at 规则、外部 URL、可加载资源的函数；4 KB 上限）。版主可创建预设/图片类资源，但不能创建自定义 CSS 资源。

## 开发

这是一个 Discourse 插件，需在 Discourse 代码库中运行——没有独立构建流程。

```bash
# 将插件软链接进 Discourse 开发代码库
ln -s /path/to/discourse-decorator-shop plugins/discourse-decorator-shop

# 执行迁移
bin/rake db:migrate

# 运行本插件的测试
LOAD_PLUGINS=1 bundle exec rspec plugins/discourse-decorator-shop/spec

# 单个文件或单个用例
LOAD_PLUGINS=1 bundle exec rspec plugins/discourse-decorator-shop/spec/lib/gamified_shop/purchases_spec.rb
```

每次推送和 Pull Request 都会运行官方 Discourse 插件工作流（测试 + 代码检查）进行持续集成，详见 [`.github/workflows/`](./.github/workflows/)。

## 许可证

[MIT](./LICENSE)
