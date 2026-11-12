# 交接单 2026-11-12 — 图标第二单接线（主控 Muse → 公司侧）

用户 2026-11-12 12:15 令：图标第二单剩余工作移交公司侧继续，主控退验收席。
本单原文在 Notion 任务 `415858d4-06aa-814e-877f-febf8e5d2667`（Due 2026-11-16）。

## 接手点

- 分支：**`wip/icons-wire-b`**（自 `align-fix13` @16aff51 拉出，含 U1 签核关闭 + 图标第一单验收合并）。
- 尖端：**366d488**（已推 GitHub，ls-remote 核验）。从这里续，不要从 main 拉新分支（main 没有对齐线与第一单）。
- 提交链：4b2c336 落位 292 文件 → 299997d W2 吉祥物等比＋徽章族 → 7049b3a W3 触控 → 67e82dc W4 卡框＋祝福字形 → f3c2315 W5 地图标记 → 87c4118 W6 持有物品/绿丝带/选中勾/状态族/splash → 366d488 验证批脚本。

## 已完成（接线全部落地，只差验证与收口）

- **落位**：291 个文件按 zip 相对路径进 `assets/`（badges 93 / glyphs 45 / items 140 含 vit_* / touch 12 / frames 6 / decorations 7 / ui-v2 PNG 11 / `assets/ui/splash.png`）。`icon_small.png` 按单删除、未入库；无任何既有文件被覆盖（逐字节比对过）。
- **W2**：`partner_hero` 改等比（205×240 KEEP_ASPECT_CENTERED，脚底基线不变）；`assets/menu/v2-mascot.png` 已用 A17 版覆盖（菜单实际读的是 `u2-art-mascot.png` 的 Atlas 区 (89,91,947,1109)，与 A17 逐字节同图）。UiBadge 前缀族 type_/move_/weather_/lab_/class_ 直达 `badges/<key>.png`；`set_icon()` 可热换。抽卡招式卡改 move_ 图、move_new 卡右上角 class_physical/special 36px、暂停状态页招式行换 move 图 22px。天气片 UiIcon→UiBadge，7 种天气全映射。实验室 `LAB_ICON`（world.gd 常量）把 profile.gd 全部 **24** 个 LAB id 映射到 11 张 lab_*.png；0 级节点直接戴 lab_locked。
- **W3**：摇杆底盘/钮、五键（interact/jump/dash/aim/pause）换 touch PNG（状态 modulate 驱动图面、按压 alpha 同步）；大招改双图切换（btn_ult_charging / btn_ult），`UltGauge.art_mode` 只作用于触控实例，HUD 版保持 U1 签核形态。btn_lockon/btn_skill_burst/btn_skill_leaf 本树无对应控件——文件只落位、未造控件。
- **W4**：`UiTheme.make_card(accent, min_size, frame_rarity)` 接 frames/card_<rarity>.png（focus=card_selected）。只接等比（444×604≈0.735）卡：抽卡桌面 222×302 原样、手机高 230→**300**；祝福桌面 190×**258**、手机 220×**300**。横版的商店/通用选择卡保持面板纹理（框是竖版图，禁拉伸）。祝福卡字形换 A02 `glyphs/glyph_blessing.png`（不是 S14 星版）。
- **W5**：小地图玩家改朝向箭头（map_player_arrow 按玩家朝向旋转）、祭坛星、宝箱 map_chest、敌人红/守护者橙点、队友绿点、标记黄点、事件 event_dot_red；大地图玩家/标记改 map_pin_player（标记金调）、侧栏图例行各戴对应标记图。
- **W6**：持有物品 `_item_tex()` 规则＝`assets/ui/items/item_<id 的 - 换 _>.png`，126 件全中（另有 item_slot_empty/locked 两文件落位）。接线：暂停状态页物品行 26px、商店卡 40px（文本右移让位）。显示名仍走 `GameData.item_def().name`，文件名永不外露。结算横幅丝带引用 logo_ribbon→**ribbon_green**（橙丝带文件未动）。初始伙伴选中勾换 badge_check_selected.png。`project.godot` 加 `boot_splash/image=res://assets/ui/splash.png`。

## ⚠ 已知缺陷 — 接手第一件事

- **`scripts/touch_controls.gd:408` 解析失败**（NUC 权威门 rc=1）：`var art_path := {...}.get(kind, "")` —— Dictionary.get 返回 Variant，推断类型在 check-only 下按错误处理。修法：显式声明 `var art_path: String = String({...}.get(kind, ""))`。import 阶段 world.gd 的连带加载错误源于此，world.gd 本门 rc=0。其余六门（world/ui_badge/ui_theme/minimap/big_map/ult_gauge）全 rc=0、import rc=0。
- **`.import` 边车未入库**：import 阶段已在 NUC 树生成约 291 个新 `.import`，**尚未回拉提交**。铁律：提交进分支之前，任何一次默认 `sync_to_nuc`（带 --delete）都会把 NUC 上的边车删掉（第一单实证教训）。在公司侧本地导入生成亦可，但最终分支必须含全部落位 PNG 的 `.import`。

## 正在跑的验证（NUC）

`Test/icons2_batch.sh` 于 12:14 在 NUC 以 366d488 启动：import ✓ rc=0、解析门如上（touch_controls rc=1、余 rc=0），suite 与 phonehud 2340/2400 s150/s100、bootsmoke、neutral 续跑中，结果落 NUC `Test/out/icons2_*.log` 与 `icons2_batch.done`。批次只读代码、不写代码（只生成 .import 与 Test/out）。

## 收口清单（剩余步骤）

1. 修 touch_controls:408 → 重跑解析门。
2. 全批绿（suite / phonehud 2340＋2400 s150 / bootsmoke / neutral）。注意：W4 改了手机抽卡/祝福卡高（300），phonehud 若有旧高度 pin，按「等强度改向＋记录理由」处理，不许静默放宽。
3. s100 证据图逐项亲检本单验收项：实验室映射与银锁、触控（含大招不重「必」字）、卡框不变形、天气可区分、地图标记、物品正式名＋空/锁槽、绿丝带、splash 生效、祝福＝A02 字形。
4. 写 `design/icon-order2-record.md`，**必含两张映射表**：实验室 24 id↔11 图（即 world.gd 的 LAB_ICON）、物品 id→文件规则与 126 件全中结论。
5. 验收后合入 `align-fix13`（现仍 @16aff51，可直进），NUC 推送＋ls-remote 核验；Notion 第二单 → Done（回填 SHA 与截图结论）。

## 已裁定事项（不要重开）

- type_ 贴图**只到机制层**：HUD 技能盘是 U1 签核形态（类型色盘＋白字形），不许换成 type_ 整图。
- status_* 同理只到机制层（UiBadge 前缀已通）：游戏内没有 2D 状态图标面，状态靠 3D 身体效果呈现（同原作），不要为接图新造 HUD 元素。
- items.json 的 name 字段仍是原包西班牙语名——既有文案债，属下一轮文案对照范围，本单不改、不因此阻塞；但接线不得让文件名 id 出现在任何玩家可见文本里（已守）。
- 吉祥物设计是用户自备图，只许调构图位置/尺寸，不重出设计。

## 后续队列（第二单收口后）

U2 签核（吉祥物构图、托盘右移 x514→x560 适配裁定、左组图标高光差、提示条宽）→ U3（暂存稿在 `design/ui-alignment-progress.md`「U3 暂存」节，照稿施工）→ U5 → U4 → U6 → S07–S24。关闭门不变：并排零可见差异才算关、检查全绿只是必要条件、验收由主控亲看 compare 图签核。
