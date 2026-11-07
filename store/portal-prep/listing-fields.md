# Listing Fields — Publisher Portal form稿（DRAFT）

状态：**草稿，未提交**。用途：Solana dApp Store Publisher Portal 建 App 时逐字段粘贴。
来源：字段值搬运自 `store/config.yaml`（2026-10-25 版）；字段上限以 docs.solanamobile.com
*Listing Page Guidelines*（2026-10-24 修订）与 *Submit a New App* 为准。
凡标注处均为第三方 IP 名词占位（台账 R23 / 里程碑 M3 硬门禁），
本稿**不自行改名**，换皮定名后统一替换并重渲素材。

---

## 1. 基本字段

| 字段 | 值 | 备注 |
|---|---|---|
| App name | `SpriteBonk` | 10 字符 ≤ 25 上限 ✓ |
| Package name | `com.spritebonk.game` | 与签名 APK applicationId 精确一致（aapt2 实测）；门户保存后不可改 |
| Category | Games（建议） | 门户分类在提交时选定；本 App 为游戏类 |
| Support email | | config `TODO_PUBLISHER`，待用户给发布者邮箱 |
| Contact email | | 同上；审核结果也发到开发者邮箱 |
| App website | | 必须为公开可达 HTTPS 页（门户逐个校验链接） |
| Privacy policy URL | | 文案稿见 `privacy-policy-draft.md`，托管 URL 待用户关口 |
| Terms of service URL | | 文案稿见 `terms-draft.md`，托管 URL 待用户关口 |
| License / copyright URL | | config 中为空，待定 |

## 2. Short description（≤ 50 字符，硬上限）

现有 en-US 稿为 108 字符，超限一倍多（台账 R16），**不可用**。重写候选如下，
字符数逐个实测（2026-10-25，含空格与标点）；三稿均无第三方 IP 名词，
口径与长描述/测试说明一致（3D 怪物生存竞技场、游客可玩、只读钱包）。

| # | 候选 | 字符数 |
|---|---|---|
| 1 ★推荐 | `3D monster-taming survival arena. Play as guest.` | 48 |
| 2 | `A 3D monster survival arena. Free guest play.` | 45 |
| 3 | `Tame monsters, survive, escape the portal.` | 42 |

推荐 #1：品类（monster-taming survival arena）+ 最低门槛（guest）一句说清，
与测试说明 “Guest play needs no account or wallet” 呼应。

zh-CN 现有稿（32 字符，长度合规）：
`在常磐森林求生、召唤守护者、冲进传送门——3D 怪物生存竞技场。`
⚠️ 其中「常磐森林」为第三方 IP 名词，长度替换后需重新计数确认 ≤50。

## 3. Long description（搬运自 config.yaml 原稿，逐字未改）

### en-US

SpriteBonk is a 3D survival arena set in the Viridian Forest. Pick your
starter partner, roam a terraced forest arena, fight off waves of wild
monsters, then activate the Boss Altar to face a guardian trio —
Scyther, Pinsir or Nidoking — and escape through the portal before the
10-minute zone timer runs out and the Final Swarm begins.

Features:
- Three starters with distinct moves (Vine Whip, Ember, Water Gun)
- Stage flow: roam -> altar -> guardian -> portal -> next zone
- Optional Solana wallet connect (read-only): play as a guest with no
wallet, or connect to show your address and SOL balance
- No account, no ads, no in-app purchases in this release

On-chain features ($SPRT token and Genesis NFT eligibility) are
planned for a later season update and are not part of this release.

⚠️ IP 名词标注（均，本稿不改名）：
`Viridian Forest`、`Scyther`、`Pinsir`、`Nidoking`、`Vine Whip`、`Ember`、`Water Gun`。

### zh-CN

《SpriteBonk》是一款以常磐森林为舞台的 3D 生存竞技场游戏。选择你的初始
伙伴，在梯田状的森林竞技场中漫游，击退一波波野生怪物，然后激活 Boss
祭坛，直面守护者三巨头——飞天螳螂、凯罗斯或尼多王——并在 10 分钟区域
倒计时结束、终局兽潮降临之前，从传送门逃出生天。

特色：
- 三只初始伙伴，招式各异（藤鞭、火花、水枪）
- 关卡流程：漫游 -> 祭坛 -> 守护者 -> 传送门 -> 下一区域
- 可选 Solana 钱包连接（只读）：游客无需钱包即可游玩；连接后可显示
地址与 SOL 余额
- 本版本无账号、无广告、无内购

链上功能（$SPRT 代币与 Genesis NFT 资格）将在后续赛季更新中推出，
不属于本版本内容。

⚠️ IP 名词标注（均，本稿不改名）：
`常磐森林`、`飞天螳螂`、`凯罗斯`、`尼多王`、`藤鞭`、`火花`、`水枪`。

## 4. What's New（每版发布说明，搬运自 config.yaml 原稿）

### en-US

Initial release: Zone 1 — Viridian Forest, 3 starters, guardian trio, optional read-only wallet connect.

⚠️ `Viridian Forest`。

### zh-CN

首发版本：第 1 区·常磐森林、3 只初始伙伴、守护者三巨头、可选只读钱包连接。

⚠️ `常磐森林`。

## 5. Testing instructions（搬运自 config.yaml `solana_mobile_dapp_publisher_portal`，逐字未改）

Guest play needs no account or wallet: launch the app, pick any starter, play. Wallet connect (optional, read-only) is on the main menu — use 'Connect Wallet', paste any Solana address, and the menu shows the address and its SOL balance. No transactions are possible in this build.

（此段无第三方 IP 名词，无需标注。）

## 6. 素材字段（指针，非本稿范围）

- Icon 512×512 不透明有底色：已合规（`store/media/icon-512.png`）。
- Banner 1200×600：缺失，规格见 `banner-spec.md`（换皮后制作，M1）。
- Screenshots：现有 4 张 1280×720，数量与同尺寸合规；高度未达 ≥1080 推荐值，
且含 IP 内容，换皮后按 1920×1080 重渲（M1）。
