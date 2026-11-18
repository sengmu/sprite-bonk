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

| # | 语言 | 文案 | 字符数 | 状态 |
|---|---|---|---|---|
| 1 | en-US | `3D monster-taming survival arena. Play as guest.` | 48 | ✅ ≤ 50 字符，无第三方 IP |
| 2 | zh-CN | `3D 幻兽生存竞技场，击退兽潮，逃出生天。游客免登秒开。` | 28 | ✅ ≤ 50 字符，无第三方 IP |

## 3. Long description（已完成去 IP 化合规）

### en-US

SpriteBonk is a fast-paced 3D monster-taming survival arena. Choose your
elemental companion, explore wild biomes, fend off endless monster waves,
activate ancient elemental altars to defeat powerful zone guardians, and
escape through the portal before the 10-minute swarm overwhelms you.

Features:
- Unique elemental starters with custom signature moves and evolutions
- Full stage progression: roam -> activate altar -> defeat guardian -> portal
- In-run ability draft, elemental reactions, and rogue-lite upgrades
- Native Solana Mobile Wallet Adapter (MWA) support: connect your wallet or play as guest
- No intrusive ads, no forced accounts, fair progression

On-chain features ($SPRT token and Genesis NFT eligibility) are planned
for a later season update and are not part of this release.

### zh-CN

《SpriteBonk》是一款快节奏 3D 幻兽生存竞技场游戏。选择你的元素伙伴，
探索原野秘境，击退汹涌的野生怪物潮，激活远古祭坛迎战区域终极守护者，
在 10 分钟倒计时兽潮降临前冲入传送门逃出生天。

特色：
- 三大元素初始伙伴，拥有专属标志招式与阶段进化形态
- 完整关卡循环：旷野漫游 -> 激活祭坛 -> 击破守护者 -> 传送门进阶
- 局内三选一技能构筑、元素克制反应与实验室深度强化
- 支持原生 Solana 移动钱包 (MWA) 授权连接，亦可游客极速免登畅玩
- 纯粹游戏体验，无强制弹窗广告，无复杂账号绑定

链上功能（$SPRT 代币与 Genesis NFT 资格）将在后续赛季更新中推出，
不属于本版本内容。

## 4. What's New（每版发布说明）

### en-US

Initial release: 3 elemental starters, 4 biomes, guardian bosses, and native Solana Mobile Wallet Adapter.

### zh-CN

首发版本：3 大元素伙伴、4 大生态地带、守护者试炼与 Solana MWA 原生钱包支持。

## 5. Testing instructions（与 `store/config.yaml` 同步）

Guest play needs no account or wallet: launch the app, tap any starter, tap Start, and play with on-screen touch controls. Wallet connect (optional, read-only) is on the main menu — tap Wallet then Connect to authorize via Solana Mobile Wallet Adapter (MWA) and view your read-only short address and SOL balance, or tap Copy Address to copy it. No transactions or signing fees are possible in this build.

（此段无第三方 IP 名词，无需标注。）

## 6. 素材字段（指针，非本稿范围）

- Icon 512×512 不透明有底色：已合规（`store/media/icon-512.png`）。
- Banner 1200×600：缺失，规格见 `banner-spec.md`（换皮后制作，M1）。
- Screenshots：已更新为 4 张最新实机渲染 1920×1080 宣传图（满足 ≥1080 推荐分辨率，全面呈现优化后 HUD、3D 战斗特效、守护者 Boss 阵与垂直发光传送门；换皮定名后可直接沿用渲染脚本复产无 IP 版本）。
