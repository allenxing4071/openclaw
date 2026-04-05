# AI Mini App 工厂 — 完整蓝图文档

> 基于 2026-04-05 与 AI 架构师的完整讨论，涵盖愿景、架构、技术方案、经济模型、风险评估、实施路径。
> 本文档将作为 OpenClaw 的项目指导文件，指导 AI 自主实施。

---

## 一、项目愿景

### 1.1 核心理念

构建一个 **AI 全自主创业循环系统**：

```
AI 全网调研 → AI 选品决策 → AI 开发 App → AI 部署上线 → AI 运营推广
→ 用户付费（加密货币）→ AI 管理收支 → AI 决策再投资 → 回到调研
```

**人的角色 = 保险丝**：系统正常运转时零参与，仅在极端异常时介入。

### 1.2 为什么可行

三个条件同时满足，在传统互联网不可能，在 Crypto + Telegram 生态成立：

| 传统互联网卡点 | Telegram + Crypto 解法 |
|--------------|----------------------|
| 银行账户 | 钱包地址 — AI 可自主生成，无需身份 |
| App Store 审核 | Telegram Mini App — BotFather 创建，零审核 |
| 身份验证 | 匿名/假名 — 加密世界原生支持 |
| 支付集成 | 链上收款 — USDT/TON/Telegram Stars 直接到钱包 |
| 法律实体 | 智能合约 — 代码即法律 |
| 服务器费用 | 加密支付 VPS — BitLaunch/Akash 收 BTC/ETH |
| AI API 费用 | ByBig 虚拟 U 卡 — 已绑定 Cursor 订阅，用 USDT 充值 |

### 1.3 核心策略：不赌判断力，赌概率

```
传统思维：精心打磨 1 款 App → 祈祷它成功
本项目策略：批量生产 30-50 款/月 → 数据筛选赢家 → 加注赢家

成功率 3% × 50 款 = 1-2 个赢家
一个赢家的收入覆盖全部成本 → 净利润 → 再投资
```

---

## 二、技术架构

### 2.1 三层工厂模型

```
┌─────────────────────────────────────────────────┐
│  第一层：共享基座（建一次，所有 App 复用）          │
│  ┌───────┐ ┌───────┐ ┌───────┐ ┌──────────┐    │
│  │ 用户  │ │ 支付  │ │ 数据  │ │ 部署     │    │
│  │ 系统  │ │ 系统  │ │ 埋点  │ │ 管线     │    │
│  │ TG ID │ │TON/U  │ │DAU等  │ │ 一键上线 │    │
│  └───────┘ └───────┘ └───────┘ └──────────┘    │
├─────────────────────────────────────────────────┤
│  第二层：模板引擎（4大类模板，快速套皮变体）        │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐           │
│  │ 工具 │ │ 游戏 │ │ 社交 │ │  AI  │           │
│  │ 模板 │ │ 模板 │ │ 模板 │ │ 模板 │           │
│  └──────┘ └──────┘ └──────┘ └──────┘           │
├─────────────────────────────────────────────────┤
│  第三层：AI 工厂流水线（全自动循环）               │
│                                                  │
│  调研 → 选模板 → 定制 → 部署 → 观察 → 数据决策    │
│       ↗ 有量 → 加注优化                          │
│       ↘ 没量 → 关停回收 → 做下一个                │
└─────────────────────────────────────────────────┘
```

### 2.2 OpenClaw 在架构中的位置

```
OpenClaw = 工厂的操作系统
Lobster = 流水线调度器
coding-agent = 生产工人（调用 Claude Code / Codex）
自定义 Skill = 工厂各工位的操作手册
Cron = 定时开工的闹钟
Telegram = 控制台（下指令 + 收报告）
```

OpenClaw 不需要改源码，只需要：
1. workspace 挂载项目目录
2. 编写自定义 Skill 插件
3. 配置 Lobster 工作流
4. 设置 Cron 定时任务

### 2.3 系统全景图

```
┌────────────────────────────────────────────────────────┐
│                   OpenClaw（VPS 7×24 运行）              │
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │  OpenClaw 核心引擎（已有，不用开发）               │    │
│  │  ├── Telegram 网关   ← 用户通过 TG 下指令/看报告  │    │
│  │  ├── Cron 调度器     ← 每天定时触发工厂流水线      │    │
│  │  ├── Lobster 工作流  ← 编排多步骤流水线            │    │
│  │  ├── AI 模型接入     ← Claude/GPT/DeepSeek       │    │
│  │  ├── coding-agent    ← 调 Claude Code 写代码      │    │
│  │  ├── 持久记忆        ← MEMORY.md 维持上下文       │    │
│  │  └── 沙箱环境        ← 安全隔离执行               │    │
│  └─────────────────────────────────────────────────┘    │
│                           │                              │
│              ┌────────────┴────────────┐                 │
│              ↓                         ↓                 │
│  ┌──────────────────┐     ┌──────────────────────┐      │
│  │  HLTrader 项目    │     │  Mini App 工厂        │      │
│  │  workspace/       │     │  workspace/            │      │
│  │   hltrader/       │     │   miniapp-factory/     │      │
│  │                   │     │                        │      │
│  │  Skills:          │     │  Skills:               │      │
│  │  ├ hltrader-dev   │     │  ├ factory-research    │      │
│  │  ├ hltrader-deploy│     │  ├ factory-builder     │      │
│  │  └ hltrader-      │     │  ├ factory-deployer    │      │
│  │    monitor        │     │  ├ factory-analytics   │      │
│  │                   │     │  └ factory-treasury    │      │
│  │  Cron:            │     │                        │      │
│  │  └ 每小时健康检查  │     │  Cron:                 │      │
│  └──────────────────┘     │  └ 每天 06:00 生产循环  │      │
│                            └──────────────────────┘      │
│                                                          │
│  apps/  （自动生成的 Mini App 实例）                       │
│  ├── app_001_token_tracker/                              │
│  ├── app_002_tap_game/                                   │
│  ├── app_003_ai_translator/                              │
│  └── ...                                                 │
└────────────────────────────────────────────────────────┘
```

---

## 三、共享基座详细设计

### 3.1 统一用户系统

```
标识符：Telegram User ID（全局唯一）
功能：
  - 一个用户可使用所有 App
  - 跨 App 用户画像（活跃度、付费能力）
  - 跨 App 推荐引流（A App 用户导流到 B App）

技术方案：
  - 所有 Mini App 共享一个 PostgreSQL 用户表
  - Telegram initData 验证用户身份
  - 用户首次使用任意 App 时自动注册
```

### 3.2 统一支付系统

```
收款渠道（三选一或组合）：
  1. TON Connect — Telegram 原生钱包，TON 代币支付
  2. USDT/USDC — 链上直接转账到项目金库钱包
  3. Telegram Stars — Telegram 内置支付，适合小额

归集机制：
  - 每个 App 有独立收款地址（或用 memo 区分）
  - 每日自动归集到 AI 金库主钱包
  - 每个 App 独立记账，统一金库管理

支出渠道：
  - VPS 费用 → 加密支付 VPS（BitLaunch/Akash）API 自动续费
  - AI API → ByBig 虚拟 U 卡 → 绑定 Cursor/Anthropic 订阅
  - 域名（如需） → 加密支付域名注册商
```

### 3.3 统一数据埋点

```
每个 App 自动收集的指标：
  - DAU（日活跃用户数）
  - 次日留存率
  - 7 日留存率
  - 付费用户数
  - 付费转化率
  - 单用户收入（ARPU）
  - 累计收入

技术方案：
  - 所有 App 共享一个 analytics 表
  - 每次用户操作写入事件（app_id, user_id, event, timestamp）
  - 每日 22:00 由 factory-analytics Skill 汇总生成报表

存储：
  - PostgreSQL（与用户系统共享实例）
  - 或轻量方案：SQLite + JSON 日志文件
```

### 3.4 统一部署管线

```
一个新 Mini App 的部署流程（全自动）：
  1. 调 BotFather API → 创建新 Telegram Bot
  2. 从模板生成代码 → 定制内容/主题
  3. Docker build → 推送到共享 VPS
  4. Nginx 配置自动生成（共享域名 + 子路径，或 Bot Webhook）
  5. 接入数据埋点
  6. 接入支付系统
  7. 发送上线通知

所有 App 共享一台 VPS：
  - 每个 App 是一个 Docker 容器
  - Nginx 反向代理路由
  - 预计一台 $20/月 VPS 可承载 100+ 轻量 Bot/Mini App
```

---

## 四、4 大 Mini App 模板

### 4.1 模板 A：工具型

```
定位：查询/计算/转换/提醒类工具
开发时间：1-2 小时/个
技术栈：Node.js + Telegram Bot API (或 Mini App React 前端)

可批量变体的方向：
  - 代币价格追踪器（不同代币/链）
  - Gas 费计算器（不同链）
  - 钱包余额查看器（多链）
  - 空投资格检查器（不同项目）
  - K线技术分析器
  - 合约地址安全检测
  - DeFi 收益率比较器
  - NFT 地板价追踪
  - 链上鲸鱼监控
  - 代币解锁日历

盈利方式：
  - 免费基础功能 + Pro 订阅（USDT/TON/Stars）
  - Pro 功能：实时推送、更多链、高级分析
  - 参考定价：$3-10/月
```

### 4.2 模板 B：游戏型

```
定位：Tap-to-Earn / 小游戏 / 抽奖类
开发时间：2-4 小时/个
技术栈：React (Mini App) + Canvas/CSS 动画

可批量变体的方向：
  - 点击挖矿（不同主题：太空/海洋/赛博朋克）
  - 猜涨跌（BTC/ETH/SOL 等）
  - 答题赢币（Crypto 知识/通识）
  - 幸运转盘
  - 跑酷/弹球/消消乐
  - 2048 变体
  - 扫雷变体
  - 贪吃蛇变体

盈利方式：
  - Telegram Stars 广告
  - 道具购买（复活币、加速器）
  - 排行榜重置付费
  - 参考：$0.5-2/次 微交易
```

### 4.3 模板 C：社交型

```
定位：匿名/投票/匹配/排行/群工具
开发时间：1-3 小时/个
技术栈：Node.js Bot + Mini App React 前端

可批量变体的方向：
  - 匿名告白墙
  - 群投票工具（多种投票类型）
  - 匿名问答（AMA 工具）
  - 群红包（TON/USDT）
  - 交友匹配
  - 排行榜 PK
  - 群活跃度统计
  - 表情包生成器

盈利方式：
  - 增值功能（匿名查看谁投了票、高级统计）
  - 群管理员 Pro 版
  - 参考定价：$2-5/月
```

### 4.4 模板 D：AI 能力型

```
定位：AI 包装成 Telegram 服务
开发时间：1-2 小时/个
技术栈：Node.js/Python + Claude/GPT API + Telegram Bot API

可批量变体的方向：
  - AI 翻译 Bot（多语言实时翻译）
  - AI 文案 Bot（社媒文案生成）
  - AI 合约审计 Bot
  - AI 行情分析师
  - AI 图片生成 Bot
  - AI 简历优化 Bot
  - AI 代码解释 Bot
  - AI 日报生成 Bot
  - AI 语音转文字 Bot
  - AI 摘要 Bot（链接/PDF → 摘要）

盈利方式：
  - 按次付费（$0.1-0.5/次）
  - 日/月订阅（$1-10）
  - 免费额度 + 超出付费
```

---

## 五、OpenClaw Skill 详细设计

### 5.1 factory-research Skill

```yaml
# skills/factory-research/SKILL.md
名称: factory-research
功能: 全网调研，筛选有利可图的 Telegram Mini App 方向
触发: 每天 06:00 Cron 自动触发，或手动说"调研"

执行步骤:
  1. 扫描数据源：
     - Telegram Bot 排行榜（BotFather 热门 Bot 列表）
     - Product Hunt（最近 Telegram 相关产品）
     - Twitter/X #TelegramMiniApp #TON 话题
     - DeFiLlama（DeFi 趋势数据）
     - CoinGecko 热门代币（工具型 App 选品参考）

  2. 分析竞品：
     - 已有多少类似 Bot/Mini App
     - 用户评价（好评/差评关键词）
     - 定价模式
     - 技术复杂度评估

  3. 输出选品报告：
     写入 workspace/miniapp-factory/daily-research/YYYY-MM-DD.md
     格式:
       ## 今日推荐方向（3-5个）
       ### 方向 1: [名称]
       - 类型: 工具/游戏/社交/AI
       - 对应模板: A/B/C/D
       - 竞品数量: N 个
       - 差异化点: ...
       - 预估开发时间: X 小时
       - 预估收入潜力: $/月
       - 推荐优先级: 高/中/低

  4. 从已有数据学习：
     - 读取 workspace/miniapp-factory/analytics/ 下已有 App 的表现数据
     - 优先推荐与"加注" App 同类型的方向
     - 避免推荐与"已关停" App 相同的方向
```

### 5.2 factory-builder Skill

```yaml
# skills/factory-builder/SKILL.md
名称: factory-builder
功能: 根据调研报告，使用模板 + coding-agent 并行开发 Mini App
触发: 调研完成后自动触发，或手动说"开始开发"

前置条件:
  - workspace/miniapp-factory/daily-research/YYYY-MM-DD.md 存在
  - 选品方案已确定

执行步骤:
  1. 读取今日调研报告
  2. 为每个方案选择对应模板（A/B/C/D）
  3. 为每个 App 创建独立目录:
     workspace/miniapp-factory/apps/app_XXX_[名称]/
  4. 从模板复制骨架代码到目录
  5. 生成定制化 prompt，包含：
     - App 名称、描述、功能列表
     - 使用的模板类型
     - 差异化点
     - 支付方式接入要求
     - 数据埋点接入要求
     - 多语言要求（至少 en + zh）

  6. 启动 coding-agent 并行开发（每个 App 一个独立 agent）:
     bash pty:true workdir:~/workspace/miniapp-factory/apps/app_XXX background:true \
       command:"claude '--print --permission-mode bypassPermissions' '根据模板和需求开发此 Mini App...'"

  7. 监控所有 agent 进度:
     - 每 10 分钟 poll 一次
     - agent 完成后检查产出是否可编译
     - 编译失败则重试一次（最多重试 1 次）
     - 记录开发耗时和 token 消耗

  8. 输出开发报告:
     workspace/miniapp-factory/daily-build/YYYY-MM-DD.md
       ## 今日开发结果
       | App | 模板 | 状态 | 耗时 | Token 消耗 |
       | ... | ...  | 成功/失败 | ... | ... |

注意事项:
  - 并行 agent 数量上限: 3 个（避免 VPS 资源耗尽）
  - 单个 App 开发超时: 2 小时（超时自动 kill）
  - coding-agent 的 workdir 必须设为 App 独立目录（避免上下文污染）
  - 使用 '--print --permission-mode bypassPermissions' 模式（无需 PTY）
```

### 5.3 factory-deployer Skill

```yaml
# skills/factory-deployer/SKILL.md
名称: factory-deployer
功能: 将开发完成的 Mini App 自动部署上线
触发: 开发完成后自动触发，或手动说"部署"

执行步骤:
  1. 读取今日开发报告，筛选状态为"成功"的 App
  2. 对每个成功的 App 执行:

     a. 创建 Telegram Bot:
        - 调用 BotFather API（通过已有的 Telegram 网关）
        - 设置 Bot 名称、描述、头像
        - 获取 Bot Token
        - 保存到 App 配置文件

     b. 构建 Docker 镜像:
        - cd workspace/miniapp-factory/apps/app_XXX/
        - docker build -t miniapp-app_XXX .
        - docker-compose up -d

     c. 配置 Nginx 路由:
        - 生成 Nginx server block（子域名或子路径）
        - reload Nginx

     d. 设置 Webhook:
        - 将 Bot Webhook 指向新部署的服务
        - 验证 Webhook 连通性

     e. 接入共享系统:
        - 注册 App 到统一用户系统
        - 配置支付回调
        - 启用数据埋点

     f. 冒烟测试:
        - 发送 /start 命令验证 Bot 响应
        - 检查 Mini App URL 可访问
        - 验证支付按钮存在

  3. 上线公告:
     - 在种子 Telegram 群/频道发布新 App 公告
     - 在已有 App 内做交叉推广

  4. 输出部署报告:
     workspace/miniapp-factory/daily-deploy/YYYY-MM-DD.md

部署失败处理:
  - Docker build 失败 → 记录错误，标记为"部署失败"，不重试
  - Webhook 验证失败 → 重试 1 次，仍失败则标记
  - 失败的 App 在下一个开发周期由 builder 修复后重新部署
```

### 5.4 factory-analytics Skill

```yaml
# skills/factory-analytics/SKILL.md
名称: factory-analytics
功能: 收集所有在线 App 数据，执行关停/加注决策
触发: 每天 22:00 Cron 自动触发，或手动说"分析数据"

执行步骤:
  1. 收集所有在线 App 的数据（查询共享数据库）
  2. 计算关键指标（DAU、留存、付费、收入）
  3. 执行生死判定:

生死判定规则:
  ┌──────────────────┬─────────────┬──────────────┐
  │    指标           │   关停线    │   加注线     │
  ├──────────────────┼─────────────┼──────────────┤
  │ 上线 3 天 DAU    │   < 30      │   > 200      │
  │ 上线 7 天 DAU    │   < 50      │   > 500      │
  │ 7 日留存         │   < 5%      │   > 15%      │
  │ 7 日付费用户     │   = 0       │   > 5        │
  │ 14 日累计收入    │   < $3      │   > $30      │
  │ 30 日累计收入    │   < $10     │   > $100     │
  └──────────────────┴─────────────┴──────────────┘

  4. 执行决策:
     关停 App:
       - docker stop miniapp-app_XXX
       - 释放端口
       - 移除 Nginx 配置
       - Bot 设置为维护模式（回复"服务已下线"）
       - 记录关停原因

     加注 App:
       - 生成优化方案（加功能/优化UI/增加语言/投放推广）
       - 写入 workspace/miniapp-factory/boost-queue/app_XXX.md
       - 下一个开发周期优先处理

  5. 输出日报:
     workspace/miniapp-factory/daily-analytics/YYYY-MM-DD.md
       ## 数据日报
       ### 整体概览
       - 在线 App 总数: N
       - 今日总 DAU: N
       - 今日总收入: $X
       - 累计总收入: $X

       ### 各 App 详情
       | App | DAU | 留存 | 付费用户 | 收入 | 状态 |
       | ... | ... | ...  | ...      | ...  | 运行/观察/加注/关停 |

       ### 今日操作
       - 关停: [列表]
       - 加注: [列表]
       - 新上线: [列表]
```

### 5.5 factory-treasury Skill

```yaml
# skills/factory-treasury/SKILL.md
名称: factory-treasury
功能: 管理 AI 金库钱包收支，确保资金健康运转
触发: 每天 23:00 Cron 自动触发（在 analytics 之后），或手动说"查看财务"

AI 金库钱包:
  - 地址: [启动时配置]
  - 链: EVM (USDT) + TON
  - 种子资金: 1000 USDT（人工注入，一次性）

执行步骤:
  1. 收入归集:
     - 扫描所有 App 收款地址的链上交易
     - 将分散收入归集到金库主钱包
     - 记录每个 App 的独立收入

  2. 支出管理:
     - VPS 费用: 检查余额，自动续费（API 调用）
     - ByBig U 卡: 检查余额，低于 $50 时提醒充值
       （如 ByBig 有 API 则自动充值，无 API 则通知人工充值 — 每月 1 分钟）

  3. 财务健康检查:
     - 金库余额是否够撑 3 个月运营成本
     - 月收入趋势（增长/持平/下降）
     - ROI 计算（总收入 / 总成本）

  4. 输出财务报告:
     workspace/miniapp-factory/treasury/YYYY-MM-DD.md
       ## 财务日报
       ### 余额
       - 金库钱包: $X USDT + X TON
       - ByBig U 卡: ~$X（上次充值日期）
       - 各 App 未归集: $X

       ### 今日收支
       - 收入: $X（来自 N 个 App）
       - 支出: $X（VPS $X + API $X + 其他 $X）
       - 净利润: $X

       ### 累计
       - 总投入: $1000（种子资金）
       - 总收入: $X
       - 总支出: $X
       - ROI: X%
       - 预估可运营月数: N 个月

  5. 告警:
     - 金库余额 < $100 → 高优先级通知
     - ByBig U 卡余额 < $30 → 通知人工充值
     - 单日支出 > $50 → 异常告警（可能有 agent 失控循环消耗 token）
```

---

## 六、Lobster 工作流定义

### 6.1 每日生产循环（主工作流）

```
名称: daily-factory-run
触发: cron "0 6 * * *"（每天 06:00 UTC）
模式: isolated session（不污染主聊天）

流水线:
  factory-research.scan_trends
    → factory-research.pick_top_3
    → factory-builder.generate_apps (parallel: 3)
    → factory-deployer.deploy_all
    → 等待到 22:00
    → factory-analytics.daily_report
    → factory-analytics.kill_or_boost
    → factory-treasury.daily_report
    → 发送日报到 Telegram
```

### 6.2 加注优化工作流

```
名称: boost-app
触发: analytics 标记 App 为"加注"后自动触发
模式: isolated session

流水线:
  读取 boost-queue/app_XXX.md
    → factory-builder 在现有 App 目录添加功能
    → factory-deployer 重新部署
    → 通知完成
```

### 6.3 HLTrader 维护工作流

```
名称: hltrader-healthcheck
触发: cron "0 * * * *"（每小时）
模式: main session

流水线:
  检查后端 API 响应（curl http://backend:8000/health）
    → 检查前端可访问
    → 检查 WebSocket 连接
    → 异常则通知 Telegram
```

---

## 七、经济模型

### 7.1 成本结构

```
固定成本（月）:
  Cursor/AI API 订阅   $20/月（ByBig U 卡支付）
  VPS（共享）          $20/月（加密支付）
  域名                 $1/月（可选）
  杂项                 $10/月
  ─────────────────────────
  合计                 ~$51/月

变动成本（月）:
  AI API Token 消耗    ~$50-200/月（取决于生产量）
  （每个 App 开发消耗 ~$1-3 的 API Token）
  
总成本: $100-250/月
1000 USDT 种子资金 → 至少撑 4 个月
```

### 7.2 收入预期（保守估计）

```
月产 30-50 个 Mini App
假设 5% 有收入（1-3 个赢家）
每个赢家月收入 $50-300

保守场景: 1 个赢家 × $50/月 = $50/月（不够覆盖成本）
中性场景: 2 个赢家 × $150/月 = $300/月（盈利 $50-200）
乐观场景: 3 个赢家 × $300/月 = $900/月（强盈利）

关键变量: 赢家率和单赢家收入
滚雪球: 累计在线 App 越多，赢家越多，收入越高
```

### 7.3 盈亏平衡点

```
月成本 ~$150（中位数）
需要月收入 > $150 才能自我维持

按保守 5% 赢家率、$50/赢家估算:
  需要 $150 / $50 = 3 个赢家
  需要 3 / 5% = 60 个 App 在线
  按月产 30 个、50% 关停率:
  → 约第 4-5 个月达到 60+ 在线 App
  → 第 5 个月左右实现盈亏平衡
```

---

## 八、风险评估（基于真实案例）

### 8.1 已验证的风险

| 风险 | 来源 | 缓解措施 |
|------|------|----------|
| AI 生成代码质量不稳定 | getmocha.com 测评 | 模板化降低复杂度；编译检查；失败不部署 |
| Agent Token 消耗失控 | blog.rezvov.com（1天16次事故） | 单 App 开发超时 2 小时自动 kill；每日 Token 预算上限 |
| Session 间失忆 | coclaw.com 案例总结 | 使用 MEMORY.md 维持上下文；每个 App 独立目录避免污染 |
| 大任务成功率低 | coclaw.com（"小任务远优于大任务"） | 模板化 = 把大任务拆成小任务；模板已解决 80% 的代码 |
| OpenClaw 安全漏洞 | 42,900 暴露面板报告 | 配置认证；限制 IP；用 VPN 访问控制面板 |
| 部署 POC→生产有 Gap | team400.ai 报告 | 先在测试环境跑通全流程再上生产 |

### 8.2 风险缓解策略

```
资金安全:
  - AI 金库钱包与个人钱包隔离
  - 金库钱包单笔转出上限 $100（智能合约层控制）
  - 每日支出告警阈值 $50

Token 消耗控制:
  - 单个 coding-agent 最大 Token: 100K
  - 单日总 Token 预算: 500K
  - 超预算自动停止所有 agent

质量控制:
  - App 必须通过编译才能进入部署
  - 部署后冒烟测试（/start 响应检查）
  - 上线 3 天 DAU < 30 自动关停，及时止损

系统稳定性:
  - OpenClaw Gateway 配置 restart: unless-stopped
  - Cron 失败自动重试 1 次
  - 每小时心跳检查所有服务
```

---

## 九、实施路径

### Phase 1: 基础设施搭建（第 1-2 周）

```
目标: 搭建共享基座 + 4 个模板骨架 + 5 个 Skill

Week 1:
  Day 1-2: 创建 miniapp-factory 仓库，搭建项目结构
  Day 3-4: 开发共享基座（用户系统 + 支付 + 埋点）
  Day 5-7: 开发 4 个模板骨架（工具/游戏/社交/AI）

Week 2:
  Day 1-3: 编写 5 个 OpenClaw Skill（research/builder/deployer/analytics/treasury）
  Day 4-5: 配置 Lobster 工作流 + Cron 定时任务
  Day 6: 端到端测试（手动触发一次完整流水线）
  Day 7: 修复问题，准备上线

验收标准:
  - [ ] 能从模板生成一个完整的 Mini App
  - [ ] 能自动部署到 VPS 并通过冒烟测试
  - [ ] 能收集到数据埋点
  - [ ] 能生成数据日报
  - [ ] Cron 定时触发正常工作
```

### Phase 2: 试运行（第 3 周）

```
目标: 每天自动生产 1-2 个 App，验证全流程

操作:
  - 人工选定 10 个已验证方向（参考成功案例）
  - 写入 workspace/miniapp-factory/seed-directions.md
  - 启动 Cron 自动循环
  - 每天查看日报，观察质量和稳定性

关注指标:
  - 开发成功率（目标 > 70%）
  - 部署成功率（目标 > 90%）
  - 单 App 开发成本（目标 < $3）
  - 冒烟测试通过率（目标 100%）

优化项:
  - 根据失败原因优化模板
  - 调整 coding-agent 的 prompt
  - 优化部署脚本
```

### Phase 3: 量产（第 4 周起）

```
目标: 每天 1-2 个，月产 30-50 个

操作:
  - 增加 AI 自主调研权重（减少人工选方向）
  - 增加并行 agent 数量（2-3 个同时开发）
  - 开启自动加注/关停
  - 开启交叉推广

关注指标:
  - 在线 App 总数
  - 总 DAU
  - 月收入 vs 月成本
  - 赢家率
```

### Phase 4: 自我维持（第 2-3 月）

```
目标: 收入覆盖成本，实现自我维持

标志性里程碑:
  - 月收入 > 月成本（$150+）
  - 金库余额稳定不降
  - AI 自主选品准确率提升（通过数据反馈学习）
  - 人每周参与 < 30 分钟
```

---

## 十、与 HLTrader 的协同

### 10.1 共享资源

```
HLTrader 和 Mini App 工厂共享:
  - OpenClaw 编排层（同一个 OpenClaw 实例管理）
  - VPS 基础设施（同一台或同组服务器）
  - 技术栈经验（Next.js + FastAPI + 链上交互）
  - 用户池（HLTrader 的 Crypto 用户 ↔ Mini App 用户）
```

### 10.2 互相引流

```
HLTrader 是一个成熟的 Crypto 带单平台:
  - HLTrader 用户 = 高价值 Crypto 用户
  - 可以在 HLTrader TG 群推广新 Mini App
  - 工具型 Mini App（代币追踪、K线分析）与 HLTrader 用户高度匹配

Mini App 工厂的工具型 App 可以反向导流到 HLTrader:
  - 代币追踪器 → "想跟单顶级交易员？试试 HLTrader"
  - K线分析器 → "AI 分析完成，点击一键跟单"
```

### 10.3 HLTrader 的 OpenClaw Skills

```
除了工厂 Skill，同时为 HLTrader 创建:

hltrader-dev:
  - 用 coding-agent 自动开发 HLTrader 新功能
  - 遵循 HLTrader 的开发规则（R1-R7）
  - 权限分级：auto/ask/block

hltrader-deploy:
  - 自动执行 deploy-hltrader.sh
  - 支持热更新(h)、全量编译(c)、仅后端(b)

hltrader-monitor:
  - 每小时检查服务健康状态
  - API 响应时间监控
  - WebSocket 连接检查
  - 异常自动通知
```

---

## 十一、成功案例参考（经全网验证）

### 11.1 已验证成功的模式

| 案例 | 关键数据 | 启示 |
|------|----------|------|
| OpenClaw 夜间修 27 Issue/75min | 真实生产环境 | 小任务+并行 = 高效 |
| SubEasy（TG Mini App） | 18K 行代码，TG App Center 审核通过，真实付费用户 | AI 辅助开发 TG Mini App 完全可行 |
| Chart 分析 Mini App | 真实用户+收入，Telegram Stars 付费 | K线工具在 TG 有市场 |
| Bananapics Bot | 完整生产系统，Stars 付费+推荐+管理后台 | AI 图片 Bot 模式可复制 |
| Gerus Lab 3 款 DeFi App | TON 链上运行，真实用户 | DeFi 工具 + TG Mini App 组合验证 |
| Koii Prometheus | 24/7 AI 写代码赚 Token | AI 自主赚加密货币模式存在 |
| Cod3x | Hyperliquid 自动交易，无人干预 | 与 HLTrader 同赛道，验证可行 |

### 11.2 失败教训

| 教训 | 来源 | 对策 |
|------|------|------|
| Agent 进入无限重试循环 | blog.rezvov.com | 设超时+Token 预算上限 |
| 代码质量波动大 | getmocha.com | 模板化降低 AI 自由度 |
| Session 间丢失上下文 | coclaw.com | MEMORY.md + 独立目录 |
| 大任务失败率高 | coclaw.com | 模板+小任务拆解 |
| 部署不等于可用 | team400.ai | 冒烟测试+3天观察期 |

---

## 十二、给 OpenClaw 的执行指令

当你（OpenClaw AI）读到这份文档后，请按以下优先级执行：

### 最高优先级（立即执行）

1. 确认自身环境：
   - OpenClaw Gateway 是否运行
   - Telegram 网关是否连通
   - coding-agent Skill 是否可用
   - workspace 目录是否正确挂载

2. 创建项目目录结构：
   ```
   workspace/miniapp-factory/
   ├── shared/
   ├── templates/ (tool, game, social, ai-bot)
   ├── apps/
   ├── daily-research/
   ├── daily-build/
   ├── daily-deploy/
   ├── daily-analytics/
   ├── treasury/
   ├── boost-queue/
   └── seed-directions.md
   ```

### 高优先级（第一周完成）

3. 开发 4 个模板骨架（最简可运行版本）
4. 开发共享基座（用户系统 + 支付 + 埋点）
5. 编写 5 个 factory Skill

### 中优先级（第二周完成）

6. 配置 Lobster 工作流
7. 配置 Cron 定时任务
8. 端到端测试
9. 手动触发第一次完整生产循环

### 持续运行（第三周起）

10. 每天 06:00 自动执行 daily-factory-run
11. 每天 22:00 自动执行 analytics + treasury
12. 根据数据持续优化模板和策略

---

## 附录 A：关键配置

### OpenClaw docker-compose.yml 补充挂载

```yaml
volumes:
  - /path/to/HLTRADER:/home/node/.openclaw/workspace/hltrader
  - /path/to/miniapp-factory:/home/node/.openclaw/workspace/miniapp-factory
```

### Cron 配置

```yaml
cron:
  - name: "daily-factory-run"
    schedule: "0 6 * * *"
    session: isolated
    model: "anthropic/claude-sonnet-4-20250514"
    prompt: "执行每日 Mini App 工厂生产循环。参照 factory-research → factory-builder → factory-deployer 流程。"
    deliver:
      mode: announce
      channel: telegram

  - name: "daily-analytics"
    schedule: "0 22 * * *"
    session: isolated
    prompt: "执行每日数据分析和财务报告。参照 factory-analytics → factory-treasury 流程。"
    deliver:
      mode: announce
      channel: telegram

  - name: "hltrader-healthcheck"
    schedule: "0 * * * *"
    session: main
    prompt: "检查 HLTrader 所有服务健康状态：API、前端、WebSocket。异常立即通知。"
    deliver:
      mode: announce
      channel: telegram
```

### 安全配置

```yaml
# OpenClaw 安全加固
gateway:
  auth: required
  allowedIPs: [你的固定IP]
  
# 金库钱包
treasury:
  maxSingleTransfer: 100  # USDT
  dailySpendingLimit: 50  # USDT
  alertThreshold: 100     # 余额低于此值告警
```

---

> 文档版本: 1.0
> 创建日期: 2026-04-05
> 基于: 与 AI 架构师的完整讨论记录
> 目的: 作为 OpenClaw 的项目指导文件，指导 AI 自主实施 Mini App 工厂
