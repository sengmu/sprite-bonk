# SpriteBonk 界面对齐台账（1:1 工程）

用户指令（2026-11-11 01:07）：各界面与效果图做 1:1，没 1:1 不要停；唯一豁免 = 3D 模型本体（还没做，占位保持，hero 形象差异不算未对齐）；缺插画素材找 Grok Bot 美术总监拿（经 Projects Manager 会话派单，先喂游戏简介）。

## 基线
- 仓库 main = 089b31da7471449ade3f29769efd289f95cb1d55（todo 0 菜单重叠修复，2026-11-11；上一基线 d7ec090）
- 参考：design/ui-reference/v2/（U1–U6 横屏定稿）、design/ui-reference/v3/（S07–S24 + A01–A18 图版 + INVENTORY.md）
- 验收口径：横屏 2340×1080 phonehud；每屏产出 design/ui-reference/compare/<屏>.png 并排图才算验收物

## 顺序（Notion 对齐单 414858d4 定版）
U1 → U3 → U5 → U4 → U6，然后 S07–S24 按号推进。

## 已知待办（开工前存量）
0. ~~菜单图块重叠缺陷~~——**已清（2026-11-11 02:05，提交 089b31d，phonehud 2340 1536/0）**。一次性探针定位六组相交对（MenuHeroStone×MenuPartnerHero、×StarterFold、MenuPartnerHero×Resources、hint 背板×MenuHintPad、钱包行×MenuLogo、StartButtonArt×StartButton），布局重排＋两件改子件，检查未动、玩法数值未动。证据：Test/out/ui1_fix0_phonehud_2340.log、Test/out/menu_fix0.png。探针与跑批脚本事后已删。
1. U3 三选一卡面密度：接线轮实拍卡身偏空（布局密度差，非素材差）。
2. 非 p5（桌面）布局下 Resources 药丸丢了 sparkle UiBadge（合并 0cac8d1 本意保留）——小修，顺手补回。
3. 台账旧账：M5 换皮单里「2340 档长跑中」一行已过时（实为 1536/0 修复批），回写时一并纠正。

## 轮次记录
（每轮一行：屏 / 状态 / compare 图 / phonehud 数字 / 提交 SHA）
- U2 菜单：公司线已对齐（compare/U2.png 在库）；遗留第 0 项重叠缺陷已于 2026-11-11 02:05 清除（提交 089b31d，phonehud 2340 1536/0）。
- todo 0 菜单重叠：已清。phonehud 2340 1536/0。提交 089b31d。实拍 Test/out/menu_fix0.png。
- U1 局内 HUD（2026-11-11 03:06，第 1 轮）：**未关闭**。主题方向已裁定（见下）＋钱包图标空白已修（ui_icon.gd 预加载，phonehud 2340 1536/0）；其余 7 项未动。compare/U1.png（参考 vs fix1 实拍）已入仓；实拍 Test/out/phone_hud_touch_2340x1080_s150_i0_hudstart.png、boss 态 Test/out/phone_hud_touch_2340x1080_s150_i0.png。提交待本轮关账。

## U1 第 1 项裁定：HUD 走深色药丸（2026-11-11 03:06）
- 证据：v2 定稿 U1_final.jpg（2026-11-10 23:04 归档「approved」，晚于奶油换皮关账 ad460f9 10:27）顶栏/技能行/Boss 条均为深色药丸、白字；同批 U2_final.jpg 菜单是奶油——**v2 语言 = 菜单奶油、HUD 深色**，与用户 2026-11-11 01:07「按效果图 1:1」指令一致。
- 机制：奶油是代码强制的，不是选错贴图——`world.gd:_style()` 把亮度 <0.32 且 alpha >0.4 的面板底色静默改成 CREAM；`UiTheme.glass_color()` 无视 alpha 直接返回奶油；`_mk_label` 经 `UiTheme.text_color()` 把 WHITE  authored 字色转成深色墨字。HUD 转深色须：①绕过 `_style()` 的深色面板专用 stylebox（菜单不动），②把顶卡/英雄簇/Boss 卡/击杀 pill/技能行上的 label 逐个改回白色，③危险段、pips 等浅色件同步检查。属下一轮主活，不宜与图标修复同批混交。
- 结论：第 1 项不再是「待确认」，而是「HUD 转深色」的施工单。

## U1 其余项进展（2026-11-11 03:06）
- 第 3 项（资源图标空白）**已修**：根因＝`ui_icon.gd:_draw()` 内 `load()` coin.svg / wooden-chest.svg——首帧绘制时纹理未进渲染器画成默认白块，且 Control 不自行重绘，白方块永久化（探针复现：Test/out/u1_icon_render.png 全白 vs 预加载后 u1_icon_render2.png 金色；SVG 本体像素正常，探针 u1_icon_probe.log）。修法：icon 赋值时（setter/_init）即解析并进程级缓存 `_svg_cache`，`_draw` 只画；另留 `_tex==null` 时 `queue_redraw` 自愈。钱包 pill 现为金币图标 0＋木宝箱图标 18（红字）。phonehud 2340 1536/0（Test/out/u1_fix1_phonehud_2340.log，.done rc=0）。探针脚本事后已删（Test/u1_icon_probe.gd、u1_icon_render*.gd）。
- 第 3 项剩余：手机布局隐藏「区域 1/4」「普通」签（`_apply_top_card_phone` 显式 hidden 列表）与萤尘项（`_dust_icon/_dust_label` 同列表）；参考为 3 项。放回需重排手机顶卡第二行（位置与 pips/天气签抢位），下一轮做。
- 第 4 项（Boss 条）：boss 态实拍已取（`phone_hud_touch_2340x1080_s150_i0.png`，9:54、致命 5 段）：只见到精英 mini 条「比比鸟·头领 1654」（橙轨、奶油卡），**主守护者红条未出现**（横幅「守护者出现了！」已出、龙形占位 Boss 在场）。下一轮先查 `_boss_card.visible` 置位条件再对条（参考：红轨 8420＋右侧「守护者」奶油签）。
- 第 5 项（小地图深黑绿）：根因＝`_bake_minimap` 把地形色 ×0.55 再向 navy lerp 0.18。提亮口径（下一轮）：因子 0.55→约 0.85、navy lerp 0.18→约 0.08；只影响 minimap 烘焙纹理（big_map 共用同一纹理，一并受益）。
- 第 5 项（击杀 pill「+1」）：非 bug——`_kills_badge`（`+%d`，Plan Z3/P7）是目标 pill 折叠后的入口指示（`_obj_folded` 时显）。2340 档目标 pill 被折叠故显示；要去「+1」须让目标 pill 在 2340 不折叠（调 `_p3_z_over` 折叠阈），而不是删 badge（删了会断 P2「隐藏项可达」检查）。下一轮评估。
- 第 2 项（顶左簇）、第 6 项（技能栏 5 格）、第 7 项（右下按钮组）、第 8 项（Resources 长数字）未动。技能栏备注：现行 P4 双排圆槽（`_bl_move_slots/_bl_vit_slots`）是已批准手机布局；实拍仅 2 枚因 1 级只解锁 1 招——参考 5 格（4 锁＋1 叶）是否要求常驻 5 格待下一轮核 `_p4_refresh_slots` 补锁逻辑。
- 断点：未动 `world.gd`；只改 `scripts/ui_icon.gd`（+41/−4）。下一轮从「HUD 转深色」施工单起工（先加深色 stylebox＋逐 label 改白，再跑 phonehud 2340 出新 compare）。

## 下一轮：U1（局内 HUD）——差异清单已列（2026-11-11 02:05）
现状取自 phonehud hudstart 实拍 Test/out/phone_hud_touch_2340x1080_s150_i0_hudstart.png，对照 design/ui-reference/v2/U1_final.jpg：
1. ~~顶栏配色：参考深色药丸，现奶油卡片（顶左＋顶中）——先查 ui-reskin-changes.md / UI_SPEC.md 确认 HUD 主题方向再动（奶油换皮是否只管菜单）。~~→ **已裁定：HUD 转深色（见上节），下一轮施工。**
2. 顶左簇：参考紧凑一体（头像＋等级徽＋血条）；现为大卡（名＋双属性签，血条分离在下方）。名字／头像占位种属属下一轮，不列入本次。
3. 顶中：缺「区域 1/4」「普通」签；~~右侧资源计数图标为空白方块（疑图标未加载），~~**已修（ui_icon.gd 预加载，2026-11-11 03:06，phonehud 2340 1536/0）**；且只有 2 项（参考 3 项：萤尘／金币／宝箱）。
4. Boss 血条：~~本截图无 Boss，未比对——下一轮取 boss 态截图。~~→ **boss 态截图已取**（`phone_hud_touch_2340x1080_s150_i0.png`）：仅见精英 mini 条，主守护者红条未出现——下一轮先查 `_boss_card.visible` 置位条件。
5. 小地图：现深黑绿、看不清地形；参考明亮地形图。击杀 pill 多 "+1" 后缀。
6. 左下技能栏：参考 5 格一排（4 锁＋1 叶 1级）；现仅左下角两枚小圆钮（星 1级 ＋ 锁），与摇杆挤在一起。
7. 右下按钮组：大招钮现为橙星（参考紫底「必」字）；布局近似，字形／配色差；右下角另有一 faint 圆圈（右摇杆？）参考无。
8. 观察项：菜单 Resources pill 长数字（累计 400908）疑超 pill 宽——U1 轮复核（测试档数字偏大，真机档再看）。
断点：差异清单已列完；未动代码；未跑批次。下一轮从第 1 项（主题方向确认）起工。
