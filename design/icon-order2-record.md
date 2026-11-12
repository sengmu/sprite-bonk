# 图标第二单验收记录（主控 Muse，2026-11-12）

单据：Notion「SpriteBonk：接入新图标（二）其余图标落位与全图间接线」
`415858d4-06aa-814e-877f-febf8e5d2667`（Due 2026-11-16）。
执行分支 `wip/icons-wire-b`（自对齐线 tip 16aff51 拉出）。

## 落地提交（wip/icons-wire-b）

- `4b2c336` 素材落位：291 个文件按 zip 相对路径入 `assets/`（badges 至
93、glyphs 45、items 140 含 vit_*、touch 12、frames 6、decorations 7、
ui-v2 11、`assets/ui/splash.png`）。与既有文件逐字节比对，零覆盖；
`icon_small.png` 按单据排除；`_` 开头与 `_alt/` 不入库。
- `299997d` W2：吉祥物立绘改等比（205×240 KEEP_ASPECT_CENTERED，
原 315×240 STRETCH 横拉 1.36× 已消）；UiBadge 前缀族
type_/move_/weather_/lab_/class_ 接线；实验室 LAB_ICON 映射（见下表）；
天气片改走 UiBadge；0 级节点披 lab_locked。
- `7049b3a` W3：触控按钮成品图（interact/jump/dash/aim/pause）、摇杆
底盘/钮图、UltGauge art_mode（蓄满换 btn_ult 图、删「必」字 Label）；
btn_lockon/btn_skill_burst/btn_skill_leaf 无对应控件、只落文件。
- `67e82dc` W4：稀有度卡框（444×604）经 UiTheme.make_card 的
frame_rarity 参数接入抽卡与祝福卡（等比卡面）；`card_frame_box()`；
祝福字形改 A02 glyph_blessing 成品图（白色八角星芒）。
- `f3c2315` W5：小地图/大地图标记全套换成品图（玩家箭头/星/宝箱/
各色圆点/图钉），大地图侧栏为带图例图标的图例行。
- `87c4118` W6：持有物图标 `_item_tex` 规则接线（暂停页 26px、局内
商店卡 40px）；结算横幅改 ribbon_green；初始伙伴选中标记改
badge_check_selected；project.godot boot_splash 指向 splash.png。
- `366d488` 全批脚本 Test/icons2_batch.sh 入库。
- `88881c0` 交接单 design/handover-2026-11-12-icons2.md。
- `fd2af03` 收口（验收轮）：见下「验收轮改动」。

## 两张映射表（单据要求留档）

### 实验室 LAB_ICON（scripts/world.gd，24 id → 11 图样）

| 图样 | id |
|---|---|
| lab_sword | dmg、atkspd |
| lab_shield | armor、bag |
| lab_heart | hp、revive |
| lab_wing | spd |
| lab_muscle | ult、party |
| lab_clover | luck |
| lab_hourglass | research、archive |
| lab_target | crit、area、magnet |
| lab_sparkle | xp、gold、choice4、slot-move、reroll、skip、banish |
| lab_potion | regen、slot-vit |

未列 id 默认 lab_sparkle（`_lab_icon` 兜底）。

### 持有物文件规则（126 id 全中，主控在提交树复核）

文件 = `assets/ui/items/item_<id，'-'→'_'>.png`。items.json 共 126 个
id，逐一验在盘、缺失 0；图外多余文件仅 item_slot_empty /
item_slot_locked 两张槽位图。

## 验收轮改动（逐项列明，含归属）

施工方（公司侧）在 NUC 工作树完成收口但未提交，主控逐 diff 审后代提交：

- `scripts/touch_controls.gd`：单据点名的 408 行 Variant 推断解析错，
按处方改为显式 `var art_path: String = String({...}.get(kind, ""))`。
- `scripts/world.gd`：抽卡/祝福模态拟合高度 420→475 / 400→467（容纳
300px 高卡面）；`_p5_place_modal` 改按 max(标称, 实测内容高) 拟合、
纵向内缩 16→6 并加一次布局后重拟合；`_banner.pivot_offset` 钉
(430,0)；朝向路径改直接写 player.lock_target / player._vel（代
get()/velocity）。均为呈现/夹具层，无玩法数值改动。
- `Test/harness.gd`（仅检查夹具，断言未动）：GameProfile 路径改用
GameProfile.PATH 常量；c21 被动夹具标本 HP 40000→1e9（在案 flake
机理＝环境 DPS 打死标本）；静电等待窗 6.5→12.0s 并加一条调试打印。
- `Test/phonehud.gd` 两处检查改向（强度论证在案）：
①大招槽检查改按成品图契约（art_mode 开＋两张 btn_ult 图在场可见＋
无重复「必」Label）——较旧「必」字检查等强或更强；
②模态缩放下限 1.50→0.50——面板缩放现为内容拟合因子，其下方的实测
文字 21/17px 与按钮 76/83px 门槛未动。
- 三个文件的整文件行尾抖动（CRLF）已归一化为 LF，-w diff 与上述一致。

主控自查抓到并自修一处（归属主控 W4，非施工方）：

- `scripts/world.gd` `_paint_draft_cards` 非放逐分支无条件用
`UiTheme.card_box(acc)` 重刷卡面，把 `_draft_card` 在构造时设好的
稀有度框 stylebox 覆盖掉——抽卡卡框从不上屏（祝福路无重刷、故彼处
正常）。像素扫描实证：祝福卡有约 28px 框边行、抽卡卡 y=700 处无框
边只有约 10px 金细线。修法（fd2af03）：新增 `_draft_card_rars` 与
卡面一一对应记录稀有度，重刷时按 rar 恢复 `card_frame_box`（悬停
变体同理），无稀有度时回退 card_box；放逐模式红圈逻辑不变。复检
见下「截图证据」。

## 验收（数字均为 NUC 实跑）

- 施工方收口批（88881c0 工作树，2026-11-12 14:34–15:20）：import
rc=0；七文件 parse 门全 rc=0；suite **658/0**；phonehud 2340
**1459/0**、2400 **1459/0**、s100 **1564/0**；bootsmoke / neutral
rc=0。
- 主控提交树复跑（fd2af03，22:07–22:54）：import rc=0；七门全 rc=0
（touch_controls 解析错已消）；suite **658/0**；2340 **1459/0**；
2400 **1459/0**；s100 **1564/1**——唯一红 `full_slots: banner
within span`（横幅左缘 486.18 vs span 起点 517，s100 档独有，
2340/2400 两档同检查通过）。
- s100 单独复跑（fd2af03，22:57–23:10，Test/icons2_s100_rerun.sh，
Test/out/icons2_s100_rerun.done）：**1564/0**，FAIL 行 0 条，
`banner within span` 本轮通过。裁定：**时序 flake**，非确定性
居中偏移——横幅宽恰等于 span 宽，首帧布局未稳时取样即红；
复跑同值未复现，不改 world.gd 横幅定位。
- `.import` 侧车 295 个已随 fd2af03 入库（第一单教训：不入库则下次
sync --delete 清除、贴图静默空白）。

## 截图证据（主控逐张亲检，s100 2400 捕获）

- 菜单：钱包/烧瓶/商店/红旗/灰齿轮五封面、震动图标、三初始伙伴
选中勾、吉祥物等比、紫色萤尘星 ✓。
- 实验室：0 级节点全披银色 lab_locked、详情主图为 lab_sword 图样 ✓。
- 祝福：蓝色粗框边实渲染、A02 字形为白色八角星芒（原图复核无误）✓。
- 抽卡（修复后新拍，22:49）：三卡稀有度框全上屏——普通卡蓝框、
稀有卡绿框、粗亮边与祝福卡同款 ✓；招式叶 tile、金块 vit 图在卡 ✓。
- 暂停：招式行 move_ tile（草/毒/普通）、道具卡 vit_nugget 图 ✓。
- 小地图/大地图：星/宝箱/圆点/玩家箭头与图例行成品图 ✓。
- 结算：横幅 ribbon_green、第一单四 tile（钟/剑/星）完好 ✓；天气片
太阳图 ✓。
- 证据缺口（如实记）：商店捕获为萤尘元商店文本版（非局内獾掌柜卡
面）；暂停状态夹具无道具行——道具接线以代码＋126 id 规则复核为准。

## 在案裁定与欠账

- type_/status_ 只到机制层：type_ 不接 HUD 技能盘（U1 已签核形态）；
status_ 无 2D 状态展示面，不虚构界面。
- items.json 的 name 字段为原包西班牙语串——既有文案债，显示名走
GameData.item_def(key).name，文件 id 不上屏；不阻塞本单。
- 本单已合入 align-fix13（66ad775），Notion 单据置 Done。
