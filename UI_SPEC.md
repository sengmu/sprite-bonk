# UI_SPEC.md — SpriteBonk UI 对齐规格（原作挖掘 vs 我们现状）

> 用途：UI 专项轮的施工图。左列是原作（PokéBonk）UI 的实测规格，右列是我们
> 当前实现的实测状态与具体差距。用户裁定（2026-10-26 10:26）：UI 界面粗糙，先对齐。
>
> 证据规则：原作条目标注 bundle 字节偏移（`main-CkI7dQhz-mvml8e65.js`，
> 位于 `~/workspace/pokebonk-rea/scripts_out/files/origins/3be62a…/assets/`，
> 2,154,272 字节；偏移均为 grep -bo 字节偏移或 dd 读窗实证）。我们条目标注
> `文件:行号`。凡标「CSS 缺口」者为证据不存在、不得当作已证规格施工。

## 0. 证据基座与最大缺口

- 原作 UI 是 DOM（`X(tag,{class,style},…)` 助手函数）+ 外部样式表 + 少量
  canvas 绘制（小地图、罗盘、伤害数字图集）。
- **⚠ CSS 缺口（决定性）**：主样式表 `main-3GBmkmCM.css`（**519,910 字节**，
  capture_only.json 资源清单 res_c554459c 条目）与 `news-DN-Mfepf.css`
  （6,104 字节）的**正文未被抓取**——各 capture 文件中无任何 CSS 规则文本。
  因此每个 class 的 padding / 圆角 / 阴影 / 定位 / 多数文字字号在证据上是
  空白。下文能给的精确值全部来自：JS 内联 `style:{…}`、cssText 字符串、
  canvas 绘制代码、DOM 结构与资源清单。施工时凡遇 CSS 缺口，按第 1 节
  已证的 token 体系（深紫玻璃面 + 白字 + 语义色）推定，不得另起风格。
- DOM 快照（page_src.json）只有结构（属性值被策略过滤），可作元素清单旁证。

## 1. 设计 token（原作）

### 1.1 字体

| 用途 | 规格 | 证据 |
|---|---|---|
| 世界空间文字（伤害数字图集） | `900 54px Fredoka, Nunito, "Arial Rounded MT Bold", Arial, sans-serif`，64px 单元图集，描边 `#1a1030` 线宽 12、round join，白填充 + 实例色 | font @186920；描边色 @187085 |
| 罗盘字母 | 同一字体栈，`900 ${o}px`（o≈16·scale） | @1981168 |
| DOM UI 字体 | 网页字体 **Nunito 700/800/900** 与 **M PLUS Rounded 1c 800/900**（woff2 实际加载） | page_src.json `normalized_result/resources` |
| 图标 | SVG 图标系统 `Z(name, px)`，实测尺寸档：16/18/20/22/26/28/30/32/34/44/56/64/80/104 px；物品图标 `Q(key)`、头像 `VT/kT/az()` 带环徽（`mapbadge` 以 `--rc` 环色、`--s` 尺寸驱动） | 全 bundle 用法 |

要点：原作全线是**圆体 + 重字重（700–900）**。我们只有一套 subset 化的
Noto Sans SC 常规字重（world.gd:443 加载 `assets/NotoSC-subset.ttf`，
world.gd:334 声明），所有“加粗”靠放大字号和颜色假装——这是粗糙感的第一来源。

### 1.2 颜色

核心色（bundle 内实测，频率为全文件计数）：

| 色 | 值 | 角色 | 证据 |
|---|---|---|---|
| 面板墨紫 | `#1d1236` | 一切深色面的基色；以 alpha .78/.80/.82 作玻璃面（如 toast 面） | @1979047；`rgba(29,18,54,.82)` @2134144 |
| 浅面墨字 | `#2a2350` | 白 pill 按钮上的字色 | @2133917 |
| 描边墨 | `#1a1030` | 浮动文字/字母描边 | @187085 |
| 金 | `#ffd23a` | 主强调：钱包、事件 pill、地图图钉默认色（×24） | evpill 内联 `--c`（HUD 构造区 @2000510 起）；图钉默认色同区 |
| 黄 | `#ffe23a` | 强调黄（×21） | 色表簇 @831482 区 |
| 绿 | `#7aff8a` / `#36c96a` | 正向/队友点（×24 / ×6） | 同上 |
| 天蓝 | `#8ae8ff` | 信息蓝（×11） | 同上 |
| 粉红 | `#ff5a8a` / `#ff9ae0` | 警示粉 / 闪光粉 | 同上 |
| 紫 | `#9a6aff` / `#c8a8ff` | 史诗紫 | 同上 |
| 灰紫（弱化字） | `#9aa0b4`、`#6a6488` | muted 文本 | 同上 |

语义 CSS 变量（值在缺失的 CSS 中，仅知存在与用途）：
`--r0..--r4` 稀有度五级（`UT` 数组 @1337537）；`--blue/--green/--yellow/
--purple/--red/--orange/--yellow-d/--ink/--ink-2`（菜单项与设置分节的
accent，如实验室 `var(--purple)`、成就 `var(--orange)`、排行
`var(--yellow-d)`、设置 sound=gfx=ctrl=keys=hud 分节分别用
orange/blue/green/yellow/red）；`--c` 逐元素 accent（菜单项、事件 pill、
队伍槽、契约 chip 都带）；`--rc` 稀有度/环色；`--tc` 属性色（队伍/同伴
chip）；`--tcs` 触控缩放；`--p` 滑杆填充比；`--d` 入场错峰延时；
`--evo-d` 进化演出时长；`--shine` 高稀有卡面高光开关；`--shadow-sm`。

稀有度色序（图鉴图例原文）：“蓝=普通、绿=稀有、紫=史诗、金=传说”
（showMapLegend 区，@2079k 区读证）→ `--r1..r4` ≈ 蓝/绿/紫/金，`--r0` 为基色。

属性色（`Yi` 表 @3184，十进制转 hex）：

normal #c8c4a8 · fighting #e0523a · flying #a8c4ff · poison #b560e0 ·
ground #e0b860 · rock #bfa65a · bug #a8c832 · ghost #7a6ad8 ·
steel #b8c8d8 · fire #ff7a2a · water #3aa0ff · grass #5ad24a ·
electric #ffd82a · psychic #ff5aa0 · ice #8ef0ff · dragon #7a5aff ·
dark #6a5048 · fairy #ffa0e0

小地图环色（`gR` @1978630）：boss `#ff2a4a`、alpha `#ff8a2a`、
capture `#5af0ff`、treasure `#ffc83a`、totem `#c25aff`、summoner `#3ac85a`。

威胁等级（危险度计，UR 阈值 [0,1,2,3,4,5.5,7]，HUD 区读证）：
`#36c96a / #9bd23a / #ffc21a / #ff8a2a / #ff4a4a / #d0206a / #6a1aa8`，
七级各有名称（Tranquilo…Imposible）。

### 1.3 按钮与控件（由用法反推的组件库）

- `btn` 基类 + 语义色：`green`=主确认（继续/购买确认/开始）、`blue`=次要
  操作（重抽/装备）、`red`=危险（重试/放逐/删除）、`ghost`=安静按钮
  （跳过/卖出/暂停菜单项/关闭类）；尺寸修饰 `big` / `small`。
- 按钮解剖：`[图标 Z 18–20px] 文字 [kbd 键位片]`（`ez()` 生成键位片）；
  disabled 用原生 disabled（草稿工具钮）或整卡 opacity .45（商店售罄，
  @2053527 区读证）。
- `pill`：分段/开关片，选中加 `.on`；`seg` 为其容器（设置、筛选、分页签）。
- `switch`：拨动开关（内 `<i>` 钮），`.on` 态。
- `st-range`：滑杆，`--p` 变量驱动已填充段，旁配 `st-val` 数值（%）。
- `kbd`：键位片（菜单/暂停/图例中满屏使用）。
- 两段确认模式（防误触）：卖出/删除类先点变 `armed` + 文案变“再点一次”，
  3 秒超时自动解除（qR 助手与商店卖出区读证）；放逐为模式切换 + 目标卡
  `outline: 4px solid #ff4a4a` + 卡组滤镜 `hue-rotate(-30deg) saturate(1.4)`。
- 模态防连点：modal 打开后 600ms（链式 150ms）内点击被吞（modal() @2044586 区）。

### 1.4 面板、圆角、阴影、动效（JS 可证部分）

- 模态壳：`season-modal > panel season-card`（@1944717）或裸 `modal`
  （@2044586）；暂停/子页统一 `panel pz-st` + `scr-head`（back-btn 带
  Esc kbd + `scr-title` 的 h1 + 副标题 span）脚手架。
- pill 圆角实证：toast 按钮/条 `border-radius:999px`、padding 2px 10px /
  5px 10px、面 `rgba(29,18,54,.82)`、字 600 12px/1.3（Mz toast cssText，
  @2133917–2134144 区读证）。
- 阴影：仅知变量 `--shadow-sm` 存在；**各类面板阴影值 = CSS 缺口**。
- 动效：菜单项入场错峰 `--d = 序号×0.05s`（mm-item @1822478 区）、赛季行
  ×0.08s；toast 入场 `translateY(10px) scale(1.01)→none`、
  `cubic-bezier(.2,.8,.3,1)`（Mz 区读证）；`app-notice` 3.6s 淡出 / 4.2s
  移除（@2151950 区读证）；购买失败按钮 `shake` 类抖动；购买成功从按钮
  飞出 `-{价格}` 星尘片（图标 24px）+ 卡面 `var(--yellow)` 星火（18px）
  + 卡加 `bought` 闪（Lab 区 @1903300 区读证）；进化演出 `--evo-d` 默认
  3.6s（evo @2065987 区）。
- 全局 UI 缩放：`kR() = clamp(min(vw/1920, vh/1080), 1, 2) × 1.1`
  （@1980939）——以 1920×1080 为设计基准的统一缩放因子；另有用户级
  `hudScale` / `hudOpacity` 设置（设置 hud 节 keys @1970253）。

### 1.5 我们的 token 现状

- 无 token 体系：颜色以裸 `Color(r,g,b)` 字面量散落在 world.gd 各处
  （如墨字 `Color(0.14,0.13,0.24)` world.gd:2533 区、灰 `Color(0.45,0.45,0.55)`）。
- 唯一收口是 `_style(bg, radius, border, bw)`（world.gd:2437）：只设底色、
  统一圆角、可选边框——**从不设阴影、从不设内边距**（全工程 grep
  `shadow_size/content_margin` 在 scripts/*.gd 零命中）。
- **全部 Button 用 Godot 默认主题**：world.gd 中 `StyleBoxFlat` 仅 2 处
  （_style 本体与圆钮助手），没有任何按钮的 normal/hover/pressed/disabled
  stylebox 覆盖——每个按钮都是系统灰按钮（仅换字体与字号）。这是与
  「btn 语义色组件库」之间最大的单点差距。
- 面板语言自相矛盾：HUD 顶栏用**白面**（`Color(1,1,1,0.96)`）+ 墨字，
  而 Lab/商店/祝福/选择面板用**深面**（`Color(0.07,0.08,0.13,0.98)`）+ 白字；
  原作全线只有一套深紫玻璃语言。

## 2. 逐屏规格：原作 vs 我们

### 2.1 主菜单

**原作**（DI 构建器，mm-item @1822478 区）：
- **没有面板**：菜单项直接浮在实时 3D 菜单场景上（`menuScene.setBiome /
setView('main')`），左列 `mm-left / mm-nav`。
- 菜单项 `button.mm-item.<kind>`：`--c` accent + `--d` 错峰入场；
解剖 = `mm-ic` 图标 + `mm-tx`（`<b>` 标题 + `<small>` 副标题）+ 可选
`mm-badge` 计数徽。项与 accent：开始（球图标）、图鉴 `var(--blue)`、
实验室（稀有糖图标，副标题=“{n} 星尘”，`var(--purple)`，可领时带徽）、
成就（星星碎片，`var(--orange)`，带徽）、排行（金图标 32px，
`var(--yellow-d)`）。
- 小项行 `mm-small`：设置（节拍器图标）、反馈（bug 26px）、Discord
（品牌色 #5865f2）、X（#14171a），accent 皆 `var(--ink-2)`。
- 顶右：邮件钮 `tr-mail`（26px）与新闻钮 `tr-mail tr-news`（26px），
带 `mm-badge` 未读数与 `.new` 态；玩家身份片（游客/名字 + 赛季框头像
44px）；全屏钮 `lang-btn fs-btn`（22px 图标）。另有 `mm-today` 日常区。
- 支持手柄/键盘焦点导航（`.focus` 态逐项轮转）。

**我们**（world.gd:2866–2975）：
- 居中 `PanelContainer` 520×456（world.gd:2867），**未设任何 stylebox** →
引擎默认灰面；标题 “SpriteBonk 3D” 40px 浅蓝平字（:2876），副标题 20px。
- 初始伙伴 = 3 个默认主题 Button（22px、高 52，:2881），纯文字
“妙蛙种子 (Bulbasaur)”——无头像、无属性片、无数值、无大招信息；
解锁伙伴同样追加为文字按钮。
- 下方依次：14px 两行操作说明（:2899）、钱包状态行 + 6 个全宽默认按钮
（连接钱包 / 研究室 / 商店 / 声音设置 / 联盟挑战 / 画面震动开关，
均 16px 高 36，:2905–2970）——设置不是一个屏，而是菜单堆里的一颗
开关按钮；无徽标、无图标、无副标题、无焦点导航。

### 2.2 初始伙伴选择（原作 ls 屏）

**原作**（ls-* 类簇，@1827698–1868000 区； ult 列表 dR 区 @1971k）：
这是一个完整的出战配置屏，不是三选一：
- 队伍条 `ls-team`：6 个 `ls-tslot`（头像 `ls-tpic` + `--c` 属性色），
可拖拽排序、空槽带 `ls-plus`，头部计数 “n/6”。
- 图鉴格 `ls-grid / ls-tile`：头像 `ls-portrait`、名 `ls-name`、收藏星
`ls-star`、锁态 `ls-lock` + 未解锁进度 `ls-lkcount / ls-prog`（进度条）。
- 英雄详情：`ls-hero / ls-id`（编号、名、属性片、排名 `ls-rank`）、
`ls-top-stats` 属性行（stat-row）、招式 `ls-move`（含芯片与克制
`ls-mu`）、进化链 `ls-evo`、大招列表 `ls-ult`（每行：进化阶头像或
属性图标 28px + 名 + 描述，`--c` 属性色）、条件 `ls-cond`、被动
`ls-passive`、推荐 `ls-rec`、修饰 `ls-mods`、套装 `ls-kit`。
- 底部：`ls-cta`（含 `ls-go` 开始钮）、`ls-roster` 名册、`ls-wins` 战绩行；
另有随机选人钮 `pill ls-random`（带老虎机式跳选动画）。

**我们**：无此屏。菜单即选人（见 2.1）；STARTER_HUD 数据（world.gd:183–187：
medal 色、单字 glyph、属性片色、进化文案）只服务于局内 HUD，菜单里
一点没用上。玩家在选人时看不到任何数值/招式/大招信息。

### 2.3 HUD

**原作**（UI 类 nz 构造器，@2000510–2004500 区；类名后为字节锚）：
根 = 全屏 `div.passthru` + `#hud`，元素按构造顺序：

- **左上 `hud-tl`**（@2000510）：`tl-medal` 奖章组 = `tl-ring`（**经验环**，
内 `<em>` 扫过）+ `tl-portrait` 头像 + `tl-lvl`（`<small>Nv</small>` +
`<b>` 等级）；侧 `tl-plate`：`tl-head`（名 `tl-name` + 属性片 `tl-types`
+ 命数 `tl-lives`）、`tl-evo` 进化进度。其下 `hud-party` 队伍头像行。
- **plate 下行 `under`**：`bar hpbar`（@2000712）五层子元素
`<i>填充 <s>滞后影 <b> <u> <em>数字`（滞后影 hold/drain 逻辑在
update 区，Cycle 10 已实测 0.4s/0.9）；旁 `pw-row` **战力片行**
（powerChips 方法：当前构筑的实时战力片）。
- **顶中 `hud-top`**：左 `ht-l`：`ht-biome`（粗体区名）+ `ht-row`
（阶段点 `ht-pips`、区 `ht-zone`、档 `ht-tier`、**天气 `ht-weather`**、
契约 `ht-pacts`）；中 `ht-c`：大 `timer`、**危险度计 `danger`**
（名 + `dg-seg` 七段，色序见 1.2）、**钱包 `wallet`**（金块图标 + 数额 +
`wl-ball` 球图标 + 下颗球价格 `<em>`）；右 `ht-r`：`runclock`
（`<b>0:00.0</b>` 十分之一秒 + small）。
- **右上 `hud-tr`**：`minimap` **canvas 400×400**（@2001752，点击开大图，
见 2.11）、`leftpill`、`counters`（击杀计数：球图标 + 数）、`kgoal`
目标卡（头像 + 名 + “还差 n” + `kgoal-bar` 进度 + 下一目标）、事件
pill 栈：`milepill` 里程碑、`evpill` 事件、`evpill shop`（`--c #ffd23a`)、
彗星 pill（`--c #4aa8ff`）、迁徙 pill（`--c #9a6aff`）、围攻 pill
（`--c #ff4a3a`）——每种事件一颗带自有 accent 的 pill。
- **左下 `hud-bl`**：两行 `slots`（维生素槽 / 招式槽）+ `bl-row` 内的
**大招表 `ult`**（`ult-ring` 环 + `ult-core` + `<kbd>` 键位 + `ult-nm` 名）。
- **右下 `hud-br`**：物品栏。
- 其他常驻层：低血量 vignette（`lowhp`)、伤害闪（flashEl)、
toast 栈（toastsEl)、交互提示（promptEl)、准星/锁定（reticle /
crosshair / lockHint)、罗盘图钉（见 2.11)、`popup` 浮动字（@2007503，
并发上限 8)、FPS / 连杀（streak）/ 自动奔跑指示。
- 演出层：`ultcut` 大招 cut-in（@2011249)、关卡开场卡（stageIntro)、
捕获电影 `capcine`（@2011668：上下黑边 `lb`、vignette、头像牌 +
`cap-pips`)、进化 `evo`（@2065987 区，`--evo-d`)。

小地图绘制（drawMinimap 区 @2038k 读证）：400×400 画布，地形以
144×144 高度烘焙图打底；boss/alpha 等标记为**环中头像**（boss 27·c、
余 22·c，环色 gR 表）；队友点 `#7aff9a` 填充 + `#1d1236` 描边 r6；
金点 `#ffd23a` r5；指北针为白箭头（描边 `#1d1236` lw3）+ 罗盘字母
（描边圆底 `rgba(29,18,54,.8)`、N 红 `#ff6a5a` 余白）。

**我们**（world.gd:2484–2799 `_build_hud`）：
- 左上：78×78 圆 medal 面（r39，白边 3，:2525）内**一个 34px 汉字**
（“妙”，:2526）代替头像；等级徽 42×24；经验是 medal 下一条
78×7 的**细条**（:2531）而非环；信息面 232×78 **白色** r14（:2533），
名 19px 墨字、属性片行、进化行 13px 灰字。HP 条 232×15（轨 r7、
填充 (0.27,0.85,0.47)、滞后影、11px 数字 + 1px 阴影，:2547）。
**无队伍行、无 pw-row。**
- 顶中：白卡 480×52 r13（:2558）：区名中 17px / 英 12px、阶段点是
**“● ○ ○ ○”文字符号** 14px（:2565）、Zone 片与 NORMAL 片；计时
pill 108×32 深色 r16 19px（:2573）；已用时 13px 裸字；其下自创
“CALM” 12px 标签 + **12 个 11×8 方角 ColorRect 色块**（:2596，
原作危险度计为 7 段带色序与等级名）；计数 pill 为白面 13px 文字
“✦ 星尘 0 · ₽ 0”（:2620）——**无图标、无钱包结构、无天气显示**
（天气仅有世界粒子，HUD 无任何天气位，scripts 内无 weather label)。
- 右上：Minimap 控件 168×168（minimap.gd；烘焙地形图以**方形**贴入，
无圆形裁剪、无框，minimap.gd:40；标记为纯色圆点；方位字母用
**引擎默认字体** 13px，minimap.gd:82；不可点击，无大图）；
击杀 pill 为深色面 “击杀 0” 14px 纯字（:2671）。**无目标卡、无事件
pill 栈。**
- 左下：4 个 46×46 空槽（深面 r10、白 25% 边 1，:2684，无图标）、
招式槽白面 56×56 绿边 2 内 15px 招式名文字（:2694）、锁定槽 “—”、
大招钮 62×62（ult_gauge.gd 自定义绘制：扫弧 + 就绪脉冲 + 拒绝罩，
是我们最接近原作的一件）+ “必” 20px + R 徽 + 12px 大招名（:2714）。
**大招在左下槽行**（原作的触控大招钮在右下动作簇，见 2.13)。
- 横幅 30px 金字 + 2px 阴影（:2765）；交互提示 20px **裸字无底**
（:2775)。cut-in 面板（:2519 区）建了 Panel 却**没给 stylebox**，
是默认灰面配白字。
- **缺失整件**：低血量 vignette、捕获电影、关卡开场卡、连杀/FPS/
锁定指示、罗盘图钉、浮动字并发管理（我们的浮字是世界 Label3D:
42px、描边 10、world.gd:6372，字体为常规字重，对比原作 900 圆体
图集 + 距离缩放 clamp(dist×0.08, 0.6, 2.4)）。

### 2.4 Boss 条

**原作**（bossbar @2003924 区）：`bb-pt` 头像 + `bb-body`：
`bb-head`（`bb-name` + `bb-tag` 标签 + `bb-rage` “狂怒！”)、`bb-bar`
（`<u>` 滞后层 + `<i>` 填充 + **两个阶段刻度 `<s>` 在 left 66.6% /
33.3%**（@2003755) + `<b>`)、`bb-foot`（`bb-sub` + 状态行）。
另有 `minibars`：**2 条同构 mini 条**（`bossbar mini`，无刻度）。
（注：Cycle 10 台账曾记“刻度仅相位型传说”——DOM 层面刻度是主条的
常驻子元素，是否显示由 CSS/运行时决定，属 CSS 缺口；mini 条两条
为构造器实证，我们当时未建。）

**我们**（world.gd:2639–2658）：白卡 460×54 置于顶中下方（top 160)，
名 16px + 右对齐标签 12px + 432×16 轨（填充 (0.93,0.3,0.22)、
滞后影 (1,0.82,0.78,0.8)、11px 数字）。无头像、无刻度、无狂怒位、
无状态行、**无 mini 条**。

### 2.5 升级三选一（草稿）

**原作**（showLevelUp 区；card offer @2047756）：
- 壳 = `modal`（@2044586）+ `h1` “¡Nivel {lvl}!”；卡组 `div.cards`。
- 卡 `button.card.offer`：`--i` 序号（错峰）、`--rc`（新招式=属性色，
否则=稀有度色 var(--r*)）；`bd` 内：h3 标题、`sub`、新招式为单行
`<p>` / 强化为 `<ul><li>` 逐行、满级警告条 `ban-warn`、页脚
`key` = `[1]/[2]/[3]`；禁用/满级有专门态。同组件的标准卡尺寸
可由同族实证：换队卡 200×250（@2042545)、进化分支卡 180×230、
物品卡 300 宽（top 高 140、描述 16px、风味字 12px muted、
稀有度 ≥2 时 top 带 `--shine` 高光）。
- 工具行 `actions`：重抽 `btn blue small`（reroll 图标 18px + 计数）、
跳过 `btn ghost small`（18px）、放逐 `btn red small`（18px），
次数为 0 时 disabled；放逐为两段模式（见 1.3）。
- 卡组下方 `buildMini`：当前构筑片行（居中 wrap、maxWidth 900px):
招式片底色=属性色（融合带 ★ 与等级）、维生素片底色 `#6a5aa8`
（@2050205）；再下为 Yk 局内构筑条。数字键 1–9 直选（YR 解析）。

**我们**（world.gd:3389 建壳、3555–3598 渲染）：
每项 = 一个默认主题 Button(196×120)，三行文字 “标题\n描述\n”
16px(:3578)——无图标/头像、无稀有度着色（只剩括号里的文字）、
无 [n] 键位页脚、无悬停/焦点态；放逐是每卡下方一颗 12px 小按钮
（:3590)，与原作的模式化放逐完全不同；工具只有一行文字标签
“重抽 x · 跳过 x · 放逐 x”(:3598)——没有按钮、没有图标、没有
disabled 态；无当前构筑片行。

### 2.6 祝福弹窗

**原作**（showBlessing @2064649）：`modal` + `h1.small`（祭坛名）+
`help` “为本局选一项祝福”；卡 `button.card` minHeight 200px
（@2064760)：`top`（稀有度字徽 `rar` + **祝福图标 64px**）、`bd`
(h3 名 + `key` [n])、`--rc` = 稀有度色；底部带 Yk 构筑条；
数字键在打开 350ms 后才武装（防误触）。

**我们**（world.gd:5534–5613）：面板 860×340 深面白边（:5541）算
全场较好的壳，但供选项是默认 Button 170×110、两行文字
“名称\n”16px(:5580)——无图标、无稀有度色、无键位页脚、
无构筑条；标题带 “✦” 文字符号凑数。

### 2.7 研究所 / Lab

**原作**（SL 构建器，lab-card @1899254 区；脚手架 rL):
- 通用屏架 rL：`scr-head` + 统计片行（cL = 名 + 值 + 进度分数）。
- 模式页签 `lab-mode`（`--c` accent、图标 `lm-ic`、新内容带
`lm-new` “NUEVO” 角标）；升级区 `lab-grid` 网格卡 `lab-card`:
`lab-top`（图标 `lab-ic` + 等级 `lab-lv`)、`lab-bd` 正文、
`lab-buy` 购买钮；分组 `lab-group`。
- 物品模式即商店：`shop-wrap / shop-intro / shop-meta / shop-btn`
（图标 `shop-btn-ic` + 名 `shop-btn-lbl`)——原作的“商店”是 Lab 的
一个模式，不是独立每日商店（与 Cycle 16 核查结论一致）。
- 购买反馈（@1903300 区）：失败 = 钮 `shake` + deny 音；成功 =
钮上飞出 “-{价格}” 星尘片（24px 图标）、卡图 `var(--yellow)`
星火 18 粒、卡 `bought` 闪、350/900ms 连点节流、重绘保持滚动位。

**我们**（world.gd:3062–3127）：660×560 深面金边 2 面板（:3069）是
我们的自选风格（金边与原作 token 无对应）；内容 = 纯文字行：
名 “标签 Lv.x/y” 15px（宽 330)+ 价 15px + 默认 “购买” Button
（:3100)，行距 4——无图标、无等级点、无分组、无页签、无购买反馈
（仅 Cycle 16 的音效）；标题把规格编号写进了 UI:“研究室 · Lab
（§6.2 星尘永久升级）”(:3075)——文档编号漏进了玩家界面。

### 2.8 设置

**原作**（lR @1959742）：模态 `panel pz-st` + scr-head（标题
“Ajustes”、副标题“即时生效”）。六节页签，每节带图标与 accent 色：
**声音**（soothe-bell / --orange：总/乐/效/叫声四滑杆 0–1 步.05、
后台静音开关、iOS 静音播放开关）、**图形**（scope-lens / --blue:
画质、省电、FPS 上限分段 [0,30,60,90,120,144]、震屏开关与强度、
特效不透明度等 13 键）、**控制**（quick-claw / --green：瞄准模式、
灵敏度、Y 反转、FOV、镜头距、固定摇杆、**触控缩放**、自动大招、
大招姿势、静音大招、手柄震动/死区.05–.4)、**键位**（choice-band /
--yellow：键鼠与手柄改绑 + 手柄图例 `pad-map`)、**界面**
（wide-lens / --red:**hudScale、hudOpacity**、boss 条不透明度、
横幅/小地图缩放/图标/北向/显隐、toast/连杀等 12 键）、**账户**
（master-ball / --red：改名、重置、删号——危险操作走两段确认）。
控件行统一 `st-row`（标签 + `<small>` 说明 + 控件 + `st-val`)。

**我们**：设置面 = 声音面板（world.gd:3275–3330）+ 菜单里一颗
震屏开关（:2955）。声音面板：480×380 深面蓝边（:3283)，四行
**默认主题 HSlider**（min 宽 240，:3300）+ % 文字，后台静音是
一颗全宽默认按钮（:3317)，关闭亦然。无图形/控制/键位/界面/账户
任何一节；无 hudScale/hudOpacity；滑杆无填充段表现（原作 `--p`)。

### 2.9 结算 / 胜利

**原作**（showSummary 区；sm-dust @2086104）：
`season-modal > panel season-card`（@1944717）壳内多节面板
（节构建器 p/m)：首节 “Tu partida”(sm-run)：**结算片**
`sm-dust`（星尘图标 32px + 粗体 +n + 标签）、BONK 片
`sm-dust sm-bonk`；`sm-facts` 四格事实（值粗体 + 标签：首领/
传说/契约/最佳连杀 或 反应/进化/连杀/受击）；逐招式伤害条
（dk 图）；契约片行 `sm-pact`(--c + 图标 + 名）；捕获格
`sm-mons`（同伴片：头像 + 名 + 击杀/伤害/羁绊）；任务行
`sm-task`（祝福图标 22px + 名 + 日/周 small）；空态文案
`sm-empty`；次节 “Pokédex”（物种数、新见、研究进度前 6 家族）；
纪录节 recordBlock。另有 savedCard 恢复卡与 rivalToast 等。

**我们**（world.gd:3653–3675）：480×260 PanelContainer **无
stylebox**（默认灰面），36px 金字标题 + **一个 18px 标签**装全部
统计（多行纯文本）+ 一颗默认 “再来一局” 按钮（20px 高 46，
点击直接 reload 场景）。无结算片、无事实格、无伤害分布、
无捕获格、无任何图标。

### 2.10 局内商店（喵喵）与通用选择弹窗

**原作**（showShop 区；shop-sell @2053527）：
模态带 `shop-modal` 类；头 `h1.small` = “Meowth 台词 · {金币} ₽”；
商品为卡片格（`--rc` 稀有度、售罄/装不下时整卡 opacity.45);
卖出行 `row shop-sell`：每件 = `btn ghost small`（物品图标 + “卖出
+{n}")，**两段确认**（armed → 文案变“再点一次卖出”，3s 解除）；
刷新钮 `btn ghost small shop-reroll`（reroll 图标 18px + 价格，
金币不足 disabled)；重绘保持双滚动位；空仓有台词空态。

**我们**：无局内商店面板（Cycle 15 已判喵喵 OUT)；道具互动走
通用选择弹窗（world.gd:4845–4905)：860×380 深面白边壳（:4853)
尚可，但选项是默认 Button 200×120 纯文字（:4887)，页脚是一颗
默认按钮。我们另有一个原作不存在形态的“每日星尘商店”
（world.gd:3184–3273)：660×504 深面金边，标题 **“星尘商店 ·
Tienda”**（:3198，西语词漏入），行式文字（名+述 13px / 计数
13px / 默认购买钮，多行状态文案写在钮面上）。

### 2.11 大地图模态与罗盘图钉

**原作**（FR @1982885）：方形地图边长公式——横屏
`min(vh×.72, vw×.58)`、竖屏 `min(vw×.9, vh×.5)`、大图变体
`min(vh×.82, vw×.9)`;`bm-cv` 画布（DPR 上限 2）+ `bm-side`
侧栏（本区已发现清单 `ml-row`：图标 30px + 名 + ×n；说明
`bm-note`)；可放 ≤3 枚标记、滚轮/捏合/± 缩放、拖移；雾效
（只显示到过之处，祭坛/神殿/传送门例外）。罗盘图钉为 HUD 层
DOM：屏外目标钉在距中心 `min(vw,vh)×0.34` 处（`cp-tip` 箭头
旋转指向、`cp-ic` 图标 34px、距离字），屏内安全边距
x∈[40, vw-40]、y∈[150, vh-130]。

**我们**：无大地图（小地图不可点、无标记/缩放/雾效）；无罗盘
图钉（目标指引只有小地图上的点）。

### 2.12 暂停

**原作**（showPause 区 @2077k 读证）：`sm-modal` 内 `panel`:
scr-head 式头部 + 页签内容（招式图鉴 / 融合图鉴 / 地图图例 /
设置，皆 `panel pz-st mp-pause` 子页）+ 钮行：地图 `btn ghost`、
设置 `btn ghost`、反馈 `btn ghost pz-bug`（bug 图标 20px）、
继续 **`btn green big`**。地图图例行 `ml-row`（图标 34/28px +
名 + 说明 + 计数），标记徽 `mapbadge ml-ring`(--rc / --s)。

**我们**：**没有暂停界面**（scripts/*.gd 内无暂停面板/菜单；
玩家只能在主菜单里改声音与震屏）。触控层也没有暂停钮
（原作触控簇含 `tc-pause` 26px)。

### 2.13 触控层

**原作**（bO 类，tc-stick @1497257 区）：
容器 `div.tc`：浮动摇杆 `tc-stick`（`<i>` 钮）、动作钮
`tc-btn tc-act`（图标 + 文字，按上下文显隐）、大招钮 =
**大招表的完整克隆** `ult tc-btn tc-ultb`（环 + 芯 + kbd R + 名）、
跳 `tc-jump`（图标 44px)、冲刺 `tc-dash`(34px)、锁定 `tc-lock`
(28px)、瞄准 `tc-sm tc-aim`（26px + “Auto” 字）、暂停 `tc-sm
tc-pause`(26px)、全屏 `tc-sm tc-fs`(26px，按需显）；整簇缩放
`setScale` 钳 [0.7, 1.5] 写入 `--tcs`；多点触控 + 捏合 +
看镜拖动区与摇杆同层管理。

**我们**（touch_controls.gd）：摇杆基 124×124 圆形（深面 42% +
白 38% 边 2，:66)、钮 58×58 白 30%（:75)，浮动落点——这一件
与原作同形；动作钮只有 3 颗：互动 96 / 跳跃 80 / 滑铲 80
（:47)，**纯文字标签**（15px,:166）无图标；**无大招钮**
（大招在 HUD 左下槽行）、无瞄准/锁定/暂停/全屏；无整簇缩放
设置（原作 touchScale)。

## 3. 竖屏 / 移动端：哪些照抄、哪些必须改编

**原作本身的移动规则（可证）**：
- 设计基准 1920×1080 横屏，统一缩放 `kR()`（@1980939，见 1.4）；
  模态按宽高比分支：`vw > vh×1.1` 判横屏，否则走竖屏公式
  （大地图 @1982885：竖屏边长 min(vw×.9, vh×.5)、侧栏改纵向堆叠
  maxHeight 解除）。
- 触控是独立一层（2.13），带自动检测（触屏/键鼠/手柄三态，
  设置里可手动覆盖）与用户缩放 `touchScale`；HUD 另有
  `hudScale / hudOpacity` 两级用户调节。
- 也就是说：原作的“移动适配” = **统一缩放因子 + 模态分支 +
  触控层**，不是重排布局。DOM 字号/间距随 kR 整体缩放。

**我们的现状（实测）**：
- project.godot:21–25：视口 1280×720、`orientation="landscape"`、
  stretch `canvas_items / expand`。Seeker 上横屏运行，expand 让
  宽高比跟随设备——但全部 HUD 用**绝对像素偏移**从角/中心布设
  （world.gd:2484 起），没有任何缩放因子：换一台更宽/更窄的屏，
  元素物理尺寸与相对位置直接漂移。
- 固定宽面板：菜单 520、Lab 660、商店 660、祝福/选择 860、
  结算 480（world.gd 各 _build_*）。860 宽的祝福/选择面板在
  1280 设计宽下已占 67%；一旦有效宽度 < 1000（竖屏持机、
  分屏、小窗），必然溢出或压住 HUD。
- 顶栏三簇宽度之和：左上 336（16+78+10+232）+ 顶中 480 +
  右上 184 ≈ 1000px，在 1280 设计宽下仅余 280px 呼吸；窄屏
  expand 下三簇会互相挤压（顶中卡是中心锚 ±240，与左上信息面
  右缘 336 在 <1216px 宽时相撞）。
- **无安全区处理**：scripts/*.gd 全量 grep 无 DisplayServer
  safe-area 调用——挖孔/刘海与手势条区域未避让（左上 medal 在
  (16,14)、右上小地图贴右 16，都是危险位）。
- 无 hudScale/hudOpacity 等价设置；触控簇不可缩放。

**改编指引（建议，非原作规格）**：
1. 照抄原作思路而非像素：引入单一 UI 缩放因子（以
   min(vw/1920, vh/1080) 钳 [1,2] ×1.1 为起点，或以我们
   1280×720 基准等价换算），全体 HUD/面板乘因子；再补
   hudScale 用户项。
2. 竖屏/窄屏分支只动三处：顶中卡移到左上簇下方（纵向堆叠）、
   祝福/选择/草稿卡组改纵向滚动、大招钮并入右下触控簇。
3. 面板宽度改为 min(固定值, vw×0.92)，高度同理钳制 + 内滚。
4. 四角元素加 safe-area 内边距（ medal / 小地图 / 摇杆 /
   动作簇各让出系统安全距）。

## 4. 证据缺口清单（施工时不得假装已证）

1. `main-3GBmkmCM.css`（519,910 B）正文未抓取：所有 class 的
   底色/圆角/阴影/内边距/定位、`:root` 变量值（含 --r0..r4 与
   --ink 的确切 hex）、逐元素 font-family 与字号、按钮四态、
   动画关键帧——全部未知。本规格中此类数值只给了 JS 可证者。
2. `news-DN-Mfepf.css`（6,104 B）同样未抓取（新闻面板不在本轮范围）。
3. Fredoka 的 woff2 未出现在已抓资源清单中（canvas 引用实证其
   存在；Nunito / M PLUS Rounded 的文件与字重已证）。
4. HUD 各元素的 CSS 尺寸/坐标未知；本规格的 HUD 几何只到
   结构与顺序，像素位以我们现有布设为基线、按 token 语言重做。
5. boss 条阶段刻度 `<s>` 的显隐条件未知（DOM 常驻，见 2.4 注）。

## 5. 施工优先级（按玩家可见度）

见交付报告 Top 10。一句话总纲：先立 token 与按钮组件（一处改、
全屏变），再逐屏换壳（菜单/草稿/结算最先），最后补缺失整件
（队伍行/事件 pill/目标卡/暂停/大地图）。
