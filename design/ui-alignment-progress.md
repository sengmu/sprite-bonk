# SpriteBonk 界面对齐台账（1:1 工程）

用户指令（2026-11-11 01:07）：各界面与效果图做 1:1，没 1:1 不要停；唯一豁免 = 3D 模型本体（还没做，占位保持，hero 形象差异不算未对齐）；缺插画素材找 Grok Bot 美术总监拿（经 Projects Manager 会话派单，先喂游戏简介）。

## 基线
- 仓库 main = 2a5e099（U1 round 3 顶卡恢复＋小地图提亮＋紫色大招，2026-11-11；上一基线 ca06561）
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
- U1 局内 HUD（2026-11-11 03:06，第 1 轮）：**未关闭**。主题方向已裁定（见下）＋钱包图标空白已修（ui_icon.gd 预加载，phonehud 2340 1536/0）；其余 7 项未动。compare/U1.png（参考 vs fix1 实拍）已入仓；实拍 Test/out/phone_hud_touch_2340x1080_s150_i0_hudstart.png、boss 态 Test/out/phone_hud_touch_2340x1080_s150_i0.png。提交 2555678。
- U1 局内 HUD（2026-11-11 04:2x，第 2 轮）：**未关闭**。深色 HUD 施工单落地（见下节）＋小地图烘焙提亮；phonehud 2340 **1552/0**（Test/out/u1_fix2_phonehud_2340.log，.done rc=0；1552 vs 1536 的 +16 全是 full_prompt 场景同名断言的重复计数，非新增检查）；compare/U1.png 已刷新（参考 vs fix2 实拍，顶栏/横幅/Boss 卡已深色）。提交 ca06561。桌面 4 红经 A/B 定性为 clean main 既有（见下节），非本轮回归、未动检查。剩余项：第 2、3（签＋萤尘未放回）、4（待 2340 boss 态截图）、5（击杀 +1）、6、7、8。
- U1 局内 HUD（2026-11-11 05:4x，第 3 轮）：**未关闭**。第 3 项已清（顶卡第二行重排＋钱包三项，phonehud 2340 **1545/0**，见下节）；第 5 项小地图已提亮（烘焙改真色＋浅绿 lerp 0.45，实拍已接近参考亮度）；第 7 项大招钮已改紫底＋「必」（UltGauge._draw 紫盘）；第 4 项已取 2340 boss 态图（mobile_p2_boss_2340x1080_s150_i0.png，本轮 _p2_snap 角列表加 2340）但对条未闭合（见下节）；桌面 4 红与 fix2 批逐条相同（P5 模态几何×3＋P1 alpha 横幅文案），既有、非回归。compare/U1.png 已刷新（参考 vs fix3 实拍）。提交 2a5e099。剩余项：第 2、4（Boss 卡对条余项）、6、8。

## U1 第 1 项裁定：HUD 走深色药丸（2026-11-11 03:06）
- 证据：v2 定稿 U1_final.jpg（2026-11-10 23:04 归档「approved」，晚于奶油换皮关账 ad460f9 10:27）顶栏/技能行/Boss 条均为深色药丸、白字；同批 U2_final.jpg 菜单是奶油——**v2 语言 = 菜单奶油、HUD 深色**，与用户 2026-11-11 01:07「按效果图 1:1」指令一致。
- 机制：奶油是代码强制的，不是选错贴图——`world.gd:_style()` 把亮度 <0.32 且 alpha >0.4 的面板底色静默改成 CREAM；`UiTheme.glass_color()` 无视 alpha 直接返回奶油；`_mk_label` 经 `UiTheme.text_color()` 把 WHITE  authored 字色转成深色墨字。HUD 转深色须：①绕过 `_style()` 的深色面板专用 stylebox（菜单不动），②把顶卡/英雄簇/Boss 卡/击杀 pill/技能行上的 label 逐个改回白色，③危险段、pips 等浅色件同步检查。属下一轮主活，不宜与图标修复同批混交。
- 结论：第 1 项不再是「待确认」，而是「HUD 转深色」的施工单。

## U1 其余项进展（2026-11-11 03:06）
- 第 3 项（资源图标空白）**已修**：根因＝`ui_icon.gd:_draw()` 内 `load()` coin.svg / wooden-chest.svg——首帧绘制时纹理未进渲染器画成默认白块，且 Control 不自行重绘，白方块永久化（探针复现：Test/out/u1_icon_render.png 全白 vs 预加载后 u1_icon_render2.png 金色；SVG 本体像素正常，探针 u1_icon_probe.log）。修法：icon 赋值时（setter/_init）即解析并进程级缓存 `_svg_cache`，`_draw` 只画；另留 `_tex==null` 时 `queue_redraw` 自愈。钱包 pill 现为金币图标 0＋木宝箱图标 18（红字）。phonehud 2340 1536/0（Test/out/u1_fix1_phonehud_2340.log，.done rc=0）。探针脚本事后已删（Test/u1_icon_probe.gd、u1_icon_render*.gd）。
- 第 3 项剩余：手机布局隐藏「区域 1/4」「普通」签（`_apply_top_card_phone` 显式 hidden 列表）与萤尘项（`_dust_icon/_dust_label` 同列表）；参考为 3 项。放回需重排手机顶卡第二行（位置与 pips/天气签抢位），下一轮做。
- 第 4 项（Boss 条）：~~boss 态实拍已取（`phone_hud_touch_2340x1080_s150_i0.png`，9:54、致命 5 段）：只见到精英 mini 条「比比鸟·头领 1654」（橙轨、奶油卡），**主守护者红条未出现**（横幅「守护者出现了！」已出、龙形占位 Boss 在场）。下一轮先查 `_boss_card.visible` 置位条件再对条（参考：红轨 8420＋右侧「守护者」奶油签）。~~→ **纠正（2026-11-11 04:4x，第 2 轮复核）**：上一轮看错了图——`phone_hud_touch_2340x1080_s150_i0.png` 是全程终帧，不是 boss 态快照。机制上 Boss 卡无缺陷：`_boss_card.visible = guardian != null and hp > 0`（world.gd:12220），harness state 5 `summon_guardian()` 后三断言全绿（fix2 log L718–720：guardian summoned / boss card visible / banner up）。缺的只是 **2340 档 boss 态截图**：`_p2_snap("boss")` 只对 2400/1920 corner 存档（phonehud.gd:1701），2340 不在列。下一轮取图二选一：① corner 列表加 2340（改 harness，慎动检查）；② 用 Test/reskin_boss.tscn 单独拍 boss 态。再与参考对条（红轨 8420＋右侧「守护者」签；注意参考签是奶油底，本轮 Boss 卡已转深色，签色以参考为准）。
- 第 5 项（小地图深黑绿）：根因＝`_bake_minimap` 把地形色 ×0.55 再向 navy lerp 0.18。提亮口径（下一轮）：因子 0.55→约 0.85、navy lerp 0.18→约 0.08；只影响 minimap 烘焙纹理（big_map 共用同一纹理，一并受益）。→ **已改（第 2 轮，提交 ca06561）**：0.85 / 0.08 已落地；fix2 实拍小地图仍偏深绿（地形底色本身暗，参考是亮色手绘风）——下一轮目检 compare 判定是否够亮，不够再提因子或接受「烘焙地形」上限。
- 第 5 项（击杀 pill「+1」）：非 bug——`_kills_badge`（`+%d`，Plan Z3/P7）是目标 pill 折叠后的入口指示（`_obj_folded` 时显）。2340 档目标 pill 被折叠故显示；要去「+1」须让目标 pill 在 2340 不折叠（调 `_p3_z_over` 折叠阈），而不是删 badge（删了会断 P2「隐藏项可达」检查）。下一轮评估。
- 第 2 项（顶左簇）、第 6 项（技能栏 5 格）、第 7 项（右下按钮组）、第 8 项（Resources 长数字）未动。技能栏备注：现行 P4 双排圆槽（`_bl_move_slots/_bl_vit_slots`）是已批准手机布局；实拍仅 2 枚因 1 级只解锁 1 招——参考 5 格（4 锁＋1 叶）是否要求常驻 5 格待下一轮核 `_p4_refresh_slots` 补锁逻辑。
- 断点：未动 `world.gd`；只改 `scripts/ui_icon.gd`（+41/−4）。下一轮从「HUD 转深色」施工单起工（先加深色 stylebox＋逐 label 改白，再跑 phonehud 2340 出新 compare）。

## U1 第 2 轮进展（2026-11-11 04:2x，提交 ca06561）
- 接手状态：上一轮收尾时 fix2 WIP 被 stash（`u1-fix2-dark-hud-temp-baseline`，04:06），本轮 pop 恢复（无冲突，字节与 03:55 绿批一致）后提交；`design/ui-reference/compare/U1.png`（03:58 生成）随批入仓。解析门：world.gd / ui_theme.gd `--check-only` 均 rc=0。
- 施工内容：`UiTheme.dark_glass()`＋`HUD_DIM`（深色药丸底 Color(0.10,0.07,0.20,0.92)＋白字）；`world.gd` 的 `_style/_panel/_mk_label/_mk_dlabel/_label_in` 加 `dark:/raw:` 开关（菜单仍走奶油）；转换面：顶卡英雄簇、顶中区卡、钱包 pill、Boss 卡、目标 pill/drawer、击杀 badge、横幅/提示/cutin、勋章/等级/大招 badge；小地图烘焙 0.85 / navy 0.08。
- 桌面 4 红 A/B 定性（**既有，非回归**）：fix2 桌面批 696 检 4 红（P5 modal legacy geometry wallet/menu 680×420 want 560×248、lab/upgrades 与 lab/items 840×560 want 660×560；P1 alpha banner keeps keyboard verb）——上一轮 stash 后在 clean main 重跑桌面批（Test/out/u1_fix2_phonehud_desktop.log，04:11），**同样 4 红**。结论：桌面 4 红在 U1 之前就存在，与深色 HUD 无关；本轮未动任何检查、不降断言。归属：菜单/lab 模态几何与 alpha 横幅文案，待 U2/U6 轮或专项处理，U1 轮不扩范围。证据：Test/out/u1_fix2_phonehud_desktop.log、Test/out/u1_fix2_phonehud_desktop_withfix.log。
- 计数说明：phonehud 2340 由 1536→1552（+16），同名检查集合经 diff 相同，全是 full_prompt 场景重复断言的逐帧计数波动。
- 复跑脚本留痕（未提交，供下轮复用）：Test/u1_fix2_run.sh（2340）、Test/u1_fix2_desktop_run.sh（桌面）；`.import` churn 一律不提交。
- 断点：本轮只提交 fix2 检查点；第 3 项放回（签＋萤尘）、第 4 项 boss 态截图、第 5 项击杀 +1、第 2/6/7/8 项均未动代码，见下一轮。

## U1 第 3 轮进展（2026-11-11 05:4x，提交 2a5e099）
- 第 3 项**已清**：顶卡手机布局重排（卡宽保持 560，不动「P2: top card design width 560」断言）：区名 rect 150→120、计时器 220→180（中心 280→230）、钱包 pill 156→220（x392→328）容下三项（萤尘 icon＋label、金币、宝箱价）；第二行恢复区域签（18,40,74,22）＋难度签（98,40,44,22，新增 `_tier_chip_label` 变量）＋天气签（148,40,48,26）；pips 下移第三行 y64，危险段重定中心 171+i*17（对齐计时器中心 230）；隐藏列表只剩 `_pw_row/_zone_en/_elapsed_label`。签 label 进 `_p2_fit_fonts/_p2_restore_fonts`（区/难度签 11→下限 14px、萤尘 15→f24），P2 glance floor 全绿。检查改向（非放水）：phonehud.gd「collapsed top-band items hidden」去掉区/难度签/萤尘，新增「restored top-band items visible」同等严格断言可见；`_p2_snap` 角列表加 2340（只多取图，不动断言）。phonehud 2340 **1545/0**（Test/out/u1_fix3_phonehud_2340.log，.done rc=0；1545 vs 1552 的 −7 已对账：本轮 full_prompt 态横幅未起、11 条横幅 disjoint 检查未跑（fix2 有 10 条），＋4 条新增 restored-visible＝−7，非回归；P2 sub-floor labels 全空）。
- 第 5 项小地图**已提亮**：`_bake_minimap` 改真色（因子 1.0、navy 0）＋向浅草绿 lerp 0.45＋lift 基底 1.0；fix3 实拍小地图已亮绿、接近参考。击杀 pill「+1」**评估结论＝按设计保留**：Plan Z3 折叠是已批准行为（目标 pill 折叠进击杀 pill 的 +N，phonehud 显式断言折叠态全绿）；参考无 +1 是概念渲染简化，不改折叠阈（改阈会动 P3 右列栈与「隐藏项可达」检查）。
- 第 7 项大招钮**已改**：`UltGauge._draw` 底盘由 `badge_star_empty` 星形贴图改紫盘（0.55,0.28,0.88）＋浅紫 rim，充能 sweep 与 deny veil 不动；「必」字（桌面 label＋触屏 `_ult_glyph`）现读于紫底上。右下角 faint 圆圈**已查清来源、非缺陷**：左下是左摇杆底环，右下是 interact「!」钮的待机透明态（`_interact_fill_a()`，无可互动物时淡）；参考渲染略去触屏件，不列入差异。
- 第 4 项 Boss 条：2340 boss 态图已取（Test/out/mobile_p2_boss_2340x1080_s150_i0.png），机制三断言全绿（guardian summoned / boss card visible / banner up，fix3 log L723–725；卡几何 [P:(508.8,137.8), S:(798.4,79.8)]）；但该帧卡片处 alpha=0（守护者躯体重叠 header 的按设计淡出，reskin 门行为），图中只见精英 mini 条。对条改用 2400 旧档 boss 图（Test/out/mobile_p2_boss_2400x1080_s150_i0.png，卡片本体自 10-28 未动）：红轨＋白字血量＋相位 tick **与参考一致**；差异两处：①参考「守护者」是奶油签，现为深卡上的灰字文本；②参考无名无类型行，现卡面有「穿山王 Sandslash」名＋「地面」行。改签为奶油签是小改，但去名/去类型行涉及已批准的卡面信息（cycle 10），**留下一轮裁定**，本轮不动卡片。
- 桌面 A/B：fix3 桌面批 710 检 4 红（Test/out/u1_fix3_phonehud_desktop.log，.done rc=1），与 fix2 批逐条相同（P5 模态几何 wallet/menu 680×420、lab/upgrades 与 lab/items 840×560；P1 alpha 横幅文案）——既有、非回归。
- 解析门：world.gd / ult_gauge.gd / phonehud.gd 在 NUC `--check-only` 均 rc=0（VM 副本同命令 rc=1 是 autoload 未解析的既有环境 artifact，clean main 同样 rc=1，diff 证明零新增错误）。
- 复跑脚本留痕（未提交，供下轮复用）：Test/u1_fix3_run.sh（2340）、Test/u1_fix3_desktop_run.sh（桌面）、Test/make_compare_u1.py（compare 拼图）；`.import` churn 一律不提交（提交前 `git checkout -- addons/` 已清）。

## 下一轮：U1（局内 HUD）第 4 轮——差异清单（2026-11-11 05:5x 更新）
对照 design/ui-reference/v2/U1_final.jpg，compare/U1.png（fix3 实拍）现状：
1. ~~顶栏配色~~→ **已清（第 2 轮，深色药丸，提交 ca06561，phonehud 2340 1552/0）。**
2. 顶左簇：参考紧凑一体（头像＋等级徽＋血条）；现为大卡（名＋双属性签，血条分离在下方）。名字／头像占位种属属下一轮，不列入本次。**主活**：英雄簇改紧凑单 pill（头像＋Lv 徽＋血条一体），须核 `_p2_hero_box`（340×110/158）与 P2「hero cluster box = 340 x HP/party bottom」断言是否随之改向。
3. ~~顶中签＋萤尘~~→ **已清（第 3 轮，提交 2a5e099，phonehud 2340 1545/0）。**
4. Boss 血条：红轨＋白字＋tick 已与参考一致；余两处：①「守护者」签改奶油签（小改，`_boss_tag_label` 加签底）；②名＋类型行去留待裁定（参考无名，现卡面 cycle 10 已批准信息）。先裁定②再动手；另 2340 boss 态图本轮已取但卡片处 alpha=0（按设计淡出），对条以 2400 档图为准。
5. ~~小地图提亮~~→ **已清（第 3 轮，烘焙真色＋浅绿 lerp）。**击杀 pill「+1」：按设计保留（Z3 折叠，见第 3 轮评估），不再列为差异。余：小地图 N/W/E/S 罗盘字母参考无——是否去掉，下一轮目检定（小项）。
6. 左下技能栏：参考 5 格一排（4 锁＋1 叶 1级）；现仅左下角两枚小圆钮（星 1级 ＋ 锁）。设计问题先定：参考 5 格是固定 5 格还是 MOVE_CAP（=8）？P4 检查以 `_bl_move_slots.size() == pl.moves.size()` 断言已学招式数，补锁格须用独立数组（不动 `_bl_move_slots`）并同步 `_p4_rows_w` 宽度。定 5 格再施工。
7. ~~右下大招钮紫底「必」~~→ **已清（第 3 轮，UltGauge 紫盘）。**faint 圆圈已查清（摇杆底环＋interact 待机透明），非差异。
8. 观察项：菜单 Resources pill 长数字（累计 400908）疑超 pill 宽——用 fix3 批的菜单态截图复核（测试档数字偏大，真机档再看）。
断点：第 4 轮从第 2 项（顶左簇紧凑化）起工；第 6 项先定 5 格口径再施工；第 4 项②先裁定再动手。本轮 fix3 检查点已提交 2a5e099（待推送，见下）。
