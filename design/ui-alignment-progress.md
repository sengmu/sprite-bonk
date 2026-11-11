# SpriteBonk 界面对齐台账（1:1 工程）

用户指令（2026-11-11 01:07）：各界面与效果图做 1:1，没 1:1 不要停；唯一豁免 = 3D 模型本体（还没做，占位保持，hero 形象差异不算未对齐）；缺插画素材找 Grok Bot 美术总监拿（经 Projects Manager 会话派单，先喂游戏简介）。

## 基线
- 仓库 main = fc7a33d（U1 round 5 英雄簇药丸底＋技能底带／金边／奶油等级签＋Boss 卡实拍，2026-11-11；上一基线 dda683f）
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
- U1 局内 HUD（2026-11-11 06:1x–06:5x，第 4 轮）：**未关闭**。第 2 项已改（英雄簇紧凑单 pill：手机隐藏 `_hero_info` 名＋签＋进化行，HP 轨上移至奖章旁居中 (94,33)、队伍行上提 (94,60)，簇盒 340×86／有队友 340×104；检查改向：P2 簇盒高 110/158→86/104）；第 4 项已清（Boss 卡单行化：头像＋名隐藏、红轨上移 y15、奶油「守护者」签覆于轨右端、签字深墨／狂怒红，静态类型 foot 行只在招式预告 2.2s 内显示；裁定②＝去名／去类型行——v2 定稿为准，招式预告是唯一保留的实战信息）；第 6 项已改（技能栏固定 5 格：已学在前、锁格补足，超 5 格已学招式续排不隐藏；`_bl_locks` 增量锁格，P4 检查改向计入）；第 5 项已清（小地图 N/W/E/S 罗盘字母两处全删）；第 8 项已查（菜单 Resources pill 按内容自适应宽——`get_combined_minimum_size` 定位，无固定宽溢出机制；2400 菜单实拍两 pill 均贴合，400908 长数字目视复核仍待带该数值的菜单截图）。解析门 world.gd / minimap.gd / phonehud.gd 在 NUC `--check-only` 均 rc=0（9 条 error 全是既有 SolanaSDK 4.4 扩展噪音）。重跑批 NUC **1545/0 rc=0**（Test/out/u1_fix4_phonehud_2340.log，.done OK，07:05）。compare/U1.png 已刷新（fix4 实拍 hud_start）。**提交 dda683f，已推送，ls-remote 核验 main=dda683f。**桌面批本轮补跑（Test/u1_fix4_desktop_run.sh，log `Test/out/u1_fix4_phonehud_desktop.log`，**710 检 4 红，与 fix2/fix3 批逐条相同**——P5 模态几何 wallet/menu 680×420、lab/upgrades 与 lab/items 840×560；P1 alpha 横幅文案——既有、非回归）。fix4 compare 目检结论（第 5 轮清单）：第 2 项残余确认（簇内仍无统一药丸底——奖章圆＋血条为两个独立件，参考为一体药丸，须加底板）、第 6 项残余确认（无底带、已学格无金边／无「1级」奶油签、格 46px 偏小）、第 4 项仍缺一张卡片可见的 2340 boss 态图（fix4 新图仍只见精英 mini 条，主卡 alpha 淡出未解）。复跑脚本留痕（未提交，供下轮复用）：Test/u1_fix4_run.sh、Test/u1_fix4_parse.sh、Test/u1_fix4_desktop_run.sh、Test/make_compare_u1.py。
- U1 局内 HUD（2026-11-11 08:1x–08:5x，第 5 轮）：**未关闭**。第 2 项已清（英雄簇深色药丸底板 `_hero_plate` (56,8,284,78)，手机可见、桌面隐藏，`_p2_hero_box` 控显）；第 6 项已改（技能底带 `_bl_strip`＝rows 全幅深色药丸、已学格类型色底＋GOLD 2px 金边＋白字图标居中、「N级」由格内移至格下奶油签 (3,40,40,24)，仍为 dict `lv`、P4 检查与 `_p4_fit_fonts` 不动）；第 4 项已清（Boss 卡 2340 实拍：断言后 harness 把守护者挪开 +60x 再抓拍，主卡 alpha=1，红轨 33197＋白字＋tick＋奶油「守护者」签与参考一致，实拍 Test/out/mobile_p2_boss_2340x1080_s150_i0.png）。解析门 world.gd / phonehud.gd 在 NUC `--check-only` 均 rc=0。重跑批 NUC **1545/0 rc=0**（Test/out/u1_fix5_phonehud_2340.log，.done OK，08:41）。compare/U1.png 已刷新（fix5 实拍 hud_start）。桌面批本轮补跑（Test/u1_fix5_desktop_run.sh，log `Test/out/u1_fix5_phonehud_desktop.log`，**710 检 4 红，与 fix2/fix3/fix4 批逐条相同**——既有、非回归，已与 fix4 逐行 diff 对账）。**提交 fc7a33d，已推送，ls-remote 核验 main=fc7a33d。**剩余项：第 6 项格尺寸（须裁定）、第 2 项 Lv 徽色／位，见第 6 轮清单。复跑脚本留痕（未提交，供下轮复用）：Test/u1_fix5_run.sh、Test/u1_fix5_parse.sh、Test/u1_fix5_desktop_run.sh、Test/make_compare_u1.py。

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

## 下一轮：U1（局内 HUD）第 6 轮——差异清单（2026-11-11 08:5x 更新）
对照 design/ui-reference/v2/U1_final.jpg，compare/U1.png（fix5 实拍）现状：
1. ~~顶栏配色~~→ **已清（第 2 轮，深色药丸，提交 ca06561，phonehud 2340 1552/0）。**
2. ~~顶左簇~~→ **已改（第 5 轮，药丸底板，提交 fc7a33d，phonehud 2340 1545/0）。残余**：Lv 徽仍为深色 pill、位于奖章右下（参考为奶油签、位于头像右上）。**第 6 轮**：Lv 徽改奶油底＋深墨字、位置向参考靠拢（注意 P2 簇内布局与 `_p2_fit_fonts` 的 Lv 字号下限）。
3. ~~顶中签＋萤尘~~→ **已清（第 3 轮，提交 2a5e099，phonehud 2340 1545/0）。**
4. ~~Boss 血条~~→ **已清（第 5 轮，单行化＋奶油签＋2340 实拍对条，提交 fc7a33d，phonehud 2340 1545/0；实拍 Test/out/mobile_p2_boss_2340x1080_s150_i0.png：红轨 33197＋白字＋tick＋奶油「守护者」签与参考一致）。**
5. ~~小地图提亮~~→ **已清（第 3 轮，烘焙真色＋浅绿 lerp）。**击杀 pill「+1」：按设计保留（Z3 折叠，见第 3 轮评估），不再列为差异。~~小地图 N/W/E/S 罗盘字母~~→ **已清（第 4 轮，两处全删，提交 dda683f）。**
6. ~~左下技能栏~~→ **已改（第 5 轮，底带＋金边＋奶油「1级」签，提交 fc7a33d，phonehud 2340 1545/0）。残余**：格尺寸——参考格约 130 设计 px（2340 档实测），现 46 设计 px（×s_bl 1.35≈62 屏 px），约 2.1×。**第 6 轮裁定项**：46px 是已批准 P4 手机布局（P4_MOVE_STEP 50、P4_ROWS_H 82、phonehud 内 82.0 硬编码），放大须联动改常量＋检查改向，且 s_bl 上限 1.35 会吃掉部分放大——须先裁定参考格尺寸是否按字面执行，还是概念渲染夸张、46px 布局为准。另：底带现与 rows 等幅（零 padding），参考底带外扩约 8px——若裁定放大，一并处理。
7. ~~右下大招钮紫底「必」~~→ **已清（第 3 轮，UltGauge 紫盘）。**参考钮带双环纹、现为素紫盘——渲染 flourish，暂不列差异。
8. ~~菜单 Resources 长数字~~→ **目视复核已做，确认溢出（2026-11-11 07:2x）**：2400 菜单实拍 `Test/out/mobile_p5_menu_2400x1080_s100_i0.png`（11-10 23:33，fix4 首批）右上「累计 300908 +」pill 右端超出 2400 视口、"+" 半截被裁；「萤尘 0 +」完整。先前「内容自适应宽、无溢出机制」结论作废——该行疑似从固定 x 向右排布、未右锚定。**属菜单（U2）域，非 U1 局内 HUD 阻塞项**；修法（右锚行尾／按视口宽限长）留 U2 轮或专项处理。另见同图两处既有菜单瑕疵（仅记录）：「选择初始伙伴」标题字形重叠、左下提示 pill 底部文字被视口底裁。
补充观察（第 5 轮实拍）：Lv.1 首招为普通系撞击（tackle），已学格底色＝普通系米色、白 spark 图标对比偏弱——按类型色规则属实（参考绿叶为草系招式态），不列缺陷；维生素行存在时奶油等级签会与维生素格上下交叠（签 y40–64、维生素行 y48 起），仅在有维生素的对局出现，留待维生素态实拍复核。
断点：第 5 轮已提交 fc7a33d 并推送（ls-remote 核验 main=fc7a33d）；桌面批 u1_fix5 已绿对账（710/4，既有 4 红与 fix4 逐条相同）。**同步铁律（2026-11-11 08:5x 实证）**：sync_to_nuc.sh 会把 VM 的 .git 整体 rsync 到 NUC——NUC 侧提交推送后，必须先把新提交取回 VM（本轮经 NUC .git 反向 rsync），再跑 sync_to_nuc；否则 NUC 的 .git 会被回滚到 VM 的旧 HEAD（本轮 fc7a33d 推送后、台账同步时 NUC .git 被滚回 05ab1e5，远端 fc7a33d 无恙，靠 `git reset --hard origin/main`＋重提台账恢复；VM 无 GitHub 直连，`git pull` 会报权限错、须走 NUC .git 反向 rsync）。第 6 轮从第 6 项格尺寸裁定＋第 2 项 Lv 徽奶油化起工；U1 仍未关闭。
## 第 5 轮侦察（2026-11-11 07:2x，只读，未动代码）
- Boss 卡淡出机制（world.gd:12325–12326, 12328）：`_boss_card.modulate.a = 0.0 if _boss_body_overlaps_header() else bossOpacity`；`_boss_body_overlaps_header()` 为守护者各 MeshInstance3D 投影包围盒（grow 16）与 `_p3_draw_rect(_boss_card)` 相交即淡出。生产逻辑按设计不动；取主卡可见图须在 harness boss 态让守护者离开 header 投影区再抓拍（或 reskin_boss.tscn 单独拍）。
- 技能格构造（world.gd:14870 `_p4_refresh_slots`）：已学格 46×46 Panel＋`UiTheme.badge_base()`＋22px 类型 icon＋格内「N级」label（y24）；锁格同尺寸深色 `_style(...)`。第 5 轮：底带（`_bl_rows` 背后加深色药丸底板，勿动 `_p4_rows_w` 宽度断言）、已学格金边（badge stylebox 换金 rim）、格下奶油「1级」签（注意行锚点 (12, vh−12)，签须叠在底带下沿内、不扩行高）。
- 英雄簇构造（world.gd:14239 `_p2_hero_box`）：簇盒手机 340×86（有队友 104）。第 5 轮：簇内加深色药丸底板（Panel 子件放最底层、dark_glass、尺寸随簇盒），头像圆可沿参考 protrude 于底板左缘；须过 P2 簇盒断言与 P5 重叠检查（底板不得与顶中卡相交）。
