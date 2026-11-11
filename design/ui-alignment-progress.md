# SpriteBonk 界面对齐台账（1:1 工程）

用户指令（2026-11-11 01:07）：各界面与效果图做 1:1，没 1:1 不要停；唯一豁免 = 3D 模型本体（还没做，占位保持，hero 形象差异不算未对齐）；缺插画素材找 Grok Bot 美术总监拿（经 Projects Manager 会话派单，先喂游戏简介）。

## 基线
- 仓库 main = 75f1187（U1 第 7+8 轮代码提交，已推送并经 `git ls-remote` 核验；台账提交另见本轮提交信息）
- 参考：design/ui-reference/v2/（U1–U6 横屏定稿）、design/ui-reference/v3/（S07–S24 + A01–A18 图版 + INVENTORY.md）
- 验收口径：横屏 2340×1080 phonehud；每屏产出 design/ui-reference/compare/<屏>.png 并排图才算验收物

## 关闭门（2026-11-11 10:30 用户定版，10:33 重申）
- **U1 第 6 轮的「已关闭」被用户撤销**。新门：并排图逐项零可见差异才算关闭（豁免仅 3D 模型本体／动态数值／状态性内容须同状态对照）；检查全绿只是必要条件，**主控须亲看 compare 图签核，worker 自报不算**。
- 用户原话（10:33）：「我要一条龙你给我一条蛇，这能一样吗」——**效果图就是规格本身而非参考方向；未过门就停在该屏修到过门为止，不许跳过去**。U3 在 U1 重过门＋主控目检签核前不得开工；U2 菜单亦须按新门复核一次。

## 顺序（Notion 对齐单 414858d4 定版）
U1 → U3 → U5 → U4 → U6，然后 S07–S24 按号推进。

## 已知待办（开工前存量）
0. ~~菜单图块重叠缺陷~~——**已清（2026-11-11 02:05，提交 089b31d，phonehud 2340 1536/0）**。一次性探针定位六组相交对（MenuHeroStone×MenuPartnerHero、×StarterFold、MenuPartnerHero×Resources、hint 背板×MenuHintPad、钱包行×MenuLogo、StartButtonArt×StartButton），布局重排＋两件改子件，检查未动、玩法数值未动。证据：Test/out/ui1_fix0_phonehud_2340.log、Test/out/menu_fix0.png。探针与跑批脚本事后已删。
1. U3 三选一卡面密度：接线轮实拍卡身偏空（布局密度差，非素材差）——**已暂存**：U1 重开后 U3 不得开工，差异清单＋实施草案见本台账「U3 暂存」节，U1 重过门后再开。
2. 非 p5（桌面）布局下 Resources 药丸丢了 sparkle UiBadge（合并 0cac8d1 本意保留）——小修，顺手补回。
3. 台账旧账：M5 换皮单里「2340 档长跑中」一行已过时（实为 1536/0 修复批），回写时一并纠正。（2026-11-11 第 6 轮：M5 单号本轮手头没有，未改，留待下轮带单号处理。）

## 轮次记录
（每轮一行：屏 / 状态 / compare 图 / phonehud 数字 / 提交 SHA）
- U2 菜单：公司线已对齐（compare/U2.png 在库）；遗留第 0 项重叠缺陷已于 2026-11-11 02:05 清除（提交 089b31d，phonehud 2340 1536/0）。
- todo 0 菜单重叠：已清。phonehud 2340 1536/0。提交 089b31d。实拍 Test/out/menu_fix0.png。
- U1 局内 HUD（2026-11-11 03:06，第 1 轮）：**未关闭**。主题方向已裁定（见下）＋钱包图标空白已修（ui_icon.gd 预加载，phonehud 2340 1536/0）；其余 7 项未动。compare/U1.png（参考 vs fix1 实拍）已入仓；实拍 Test/out/phone_hud_touch_2340x1080_s150_i0_hudstart.png、boss 态 Test/out/phone_hud_touch_2340x1080_s150_i0.png。提交 2555678。
- U1 局内 HUD（2026-11-11 04:2x，第 2 轮）：**未关闭**。深色 HUD 施工单落地（见下节）＋小地图烘焙提亮；phonehud 2340 **1552/0**（Test/out/u1_fix2_phonehud_2340.log，.done rc=0；1552 vs 1536 的 +16 全是 full_prompt 场景同名断言的重复计数，非新增检查）；compare/U1.png 已刷新（参考 vs fix2 实拍，顶栏/横幅/Boss 卡已深色）。提交 ca06561。桌面 4 红经 A/B 定性为 clean main 既有（见下节），非本轮回归、未动检查。剩余项：第 2、3（签＋萤尘未放回）、4（待 2340 boss 态截图）、5（击杀 +1）、6、7、8。
- U1 局内 HUD（2026-11-11 05:4x，第 3 轮）：**未关闭**。第 3 项已清（顶卡第二行重排＋钱包三项，phonehud 2340 **1545/0**，见下节）；第 5 项小地图已提亮（烘焙改真色＋浅绿 lerp 0.45，实拍已接近参考亮度）；第 7 项大招钮已改紫底＋「必」（UltGauge._draw 紫盘）；第 4 项已取 2340 boss 态图（mobile_p2_boss_2340x1080_s150_i0.png，本轮 _p2_snap 角列表加 2340）但对条未闭合（见下节）；桌面 4 红与 fix2 批逐条相同（P5 模态几何×3＋P1 alpha 横幅文案），既有、非回归。compare/U1.png 已刷新（参考 vs fix3 实拍）。提交 2a5e099。剩余项：第 2、4（Boss 卡对条余项）、6、8。
- U1 局内 HUD（2026-11-11 06:1x–06:5x，第 4 轮）：**未关闭**。第 2 项已改（英雄簇紧凑单 pill：手机隐藏 `_hero_info` 名＋签＋进化行，HP 轨上移至奖章旁居中 (94,33)、队伍行上提 (94,60)，簇盒 340×86／有队友 340×104；检查改向：P2 簇盒高 110/158→86/104）；第 4 项已清（Boss 卡单行化：头像＋名隐藏、红轨上移 y15、奶油「守护者」签覆于轨右端、签字深墨／狂怒红，静态类型 foot 行只在招式预告 2.2s 内显示；裁定②＝去名／去类型行——v2 定稿为准，招式预告是唯一保留的实战信息）；第 6 项已改（技能栏固定 5 格：已学在前、锁格补足，超 5 格已学招式续排不隐藏；`_bl_locks` 增量锁格，P4 检查改向计入）；第 5 项已清（小地图 N/W/E/S 罗盘字母两处全删）；第 8 项已查（菜单 Resources pill 按内容自适应宽——`get_combined_minimum_size` 定位，无固定宽溢出机制；2400 菜单实拍两 pill 均贴合，400908 长数字目视复核仍待带该数值的菜单截图）。解析门 world.gd / minimap.gd / phonehud.gd 在 NUC `--check-only` 均 rc=0（9 条 error 全是既有 SolanaSDK 4.4 扩展噪音）。重跑批 NUC **1545/0 rc=0**（Test/out/u1_fix4_phonehud_2340.log，.done OK，07:05）。compare/U1.png 已刷新（fix4 实拍 hud_start）。**提交 dda683f，已推送，ls-remote 核验 main=dda683f。**桌面批本轮补跑（Test/u1_fix4_desktop_run.sh，log `Test/out/u1_fix4_phonehud_desktop.log`，**710 检 4 红，与 fix2/fix3 批逐条相同**——P5 模态几何 wallet/menu 680×420、lab/upgrades 与 lab/items 840×560；P1 alpha 横幅文案——既有、非回归）。fix4 compare 目检结论（第 5 轮清单）：第 2 项残余确认（簇内仍无统一药丸底——奖章圆＋血条为两个独立件，参考为一体药丸，须加底板）、第 6 项残余确认（无底带、已学格无金边／无「1级」奶油签、格 46px 偏小）、第 4 项仍缺一张卡片可见的 2340 boss 态图（fix4 新图仍只见精英 mini 条，主卡 alpha 淡出未解）。复跑脚本留痕（未提交，供下轮复用）：Test/u1_fix4_run.sh、Test/u1_fix4_parse.sh、Test/u1_fix4_desktop_run.sh、Test/make_compare_u1.py。
- U1 局内 HUD（2026-11-11 08:1x–08:5x，第 5 轮）：**未关闭**。第 2 项已清（英雄簇深色药丸底板 `_hero_plate` (56,8,284,78)，手机可见、桌面隐藏，`_p2_hero_box` 控显）；第 6 项已改（技能底带 `_bl_strip`＝rows 全幅深色药丸、已学格类型色底＋GOLD 2px 金边＋白字图标居中、「N级」由格内移至格下奶油签 (3,40,40,24)，仍为 dict `lv`、P4 检查与 `_p4_fit_fonts` 不动）；第 4 项已清（Boss 卡 2340 实拍：断言后 harness 把守护者挪开 +60x 再抓拍，主卡 alpha=1，红轨 33197＋白字＋tick＋奶油「守护者」签与参考一致，实拍 Test/out/mobile_p2_boss_2340x1080_s150_i0.png）。解析门 world.gd / phonehud.gd 在 NUC `--check-only` 均 rc=0。重跑批 NUC **1545/0 rc=0**（Test/out/u1_fix5_phonehud_2340.log，.done OK，08:41）。compare/U1.png 已刷新（fix5 实拍 hud_start）。桌面批本轮补跑（Test/u1_fix5_desktop_run.sh，log `Test/out/u1_fix5_phonehud_desktop.log`，**710 检 4 红，与 fix2/fix3/fix4 批逐条相同**——既有、非回归，已与 fix4 逐行 diff 对账）。**提交 fc7a33d，已推送，ls-remote 核验 main=fc7a33d。**剩余项：第 6 项格尺寸（须裁定）、第 2 项 Lv 徽色／位，见第 6 轮清单。复跑脚本留痕（未提交，供下轮复用）：Test/u1_fix5_run.sh、Test/u1_fix5_parse.sh、Test/u1_fix5_desktop_run.sh、Test/make_compare_u1.py。
- U1 局内 HUD（2026-11-11 10:5x–11:0x，第 7 轮）：**未关闭，fix8 已验（1545/0）**。10:30 新门撤销第 6 轮关闭，U1 重开八项（见「U1 重开八项」）。fix7 批 NUC **1545/0 rc=0**（Test/out/u1_fix7_phonehud_2340.log，.done rc=0，约 360s；1545 PASS 全绿、零 FAIL/ERROR；P2「collapsed top-band items hidden」still shown=[]，zone_cn 隐藏断言已跑且过）。新图已拉回 VM：hud_start／chest／boss 三张 2340。目检结论：**第 6 项已修实证**——新 hud_start 顶栏首行已无「青苔林」；**第 5 项已修实证**——必盘外 12 段环已画出（crop 放大可见段块与段间缺口，0 充能时暗段较淡）；**第 8 项 boss 图已取**——新 boss 态（9:54，守护者红条 4229＋奶油「守护者」签＋横幅，无地名），待拼 compare/U1_boss.png；**第 1 项原方案被 chest 图证伪**——就绪态填充仅 0.20 alpha（P1 日志 `interact ready at chest :: bg_a=0.20000000298023`），chest 实拍仍是淡影圈＋白「!」，不是参考的实心橙盘。已改 fix8 补跑：`touch_controls.gd` INTERACT_FILL.a 0.20→0.95（就绪态实心），按压态 interact 专属 0.42→1.0（其余钮仍 0.42），idle 仍 0.06 不动；ult_gauge.gd 暗段 alpha 0.30→0.45（0 充能时环更可读）。P1 断言不受影响（ready ≥0.18、idle ≤0.10 均仍过）。解析门 touch_controls.gd / ult_gauge.gd 在 NUC `--check-only` 均 rc=0。**fix8 批 NUC 1545/0 rc=0（Test/out/u1_fix8_phonehud_2340.log，.done rc=0；P1 `interact ready at chest/altar/capture :: bg_a=0.95`；P2 hidden still shown=[] 全态）**，新 hud_start／chest／boss 三张 2340 已拉回 VM；chest 实拍就绪态已是实心盘（第 1 项结构修复证实），但盘色仍为金（采样 243,211,76）而非参考橙（245,133,21）——色差留第 8 轮 fix9 改。compare/U1.png 已刷新（fix8 实拍），新拼 compare/U1_boss.png（fix8 boss 态）。U3 改动已全数回滚（见「U3 暂存」）。
- U1 局内 HUD（2026-11-11 11:1x–12:0x，第 8 轮）：**未关闭，fix9 已验（1561/0）**。接手 fix8：①交互盘色差——`touch_controls.gd` INTERACT_FILL／INTERACT_BORDER 由金 (1,0.85,0.3) 改参考橙 (0.96,0.52,0.08)（参考盘采样 245,133,21；P1 只断言 alpha、无色相断言）；②大招盘——`ult_gauge.gd` 加深紫内底 (0.38,0.16,0.68, r_out−6) 衬白字，暗段 alpha 0.45→0.65、段宽 4→5，`touch_controls.gd` _ult_glyph 字号 22→48（两处：初值与 `_scale_s` 缩放行）；③小地图——`world.gd:_bake_minimap` meadow lerp 0.45→0.25、高程 lift 0.35→0.55（只改烘焙纹理，minimap 检查全是几何项、无颜色断言）；④冲刺钮字形——`ui_icon.gd` "wind" 由弧线＋横线 blob 重画为三横极速线（与参考绿钮字形一致；wind 同时是 spd／attackSpeed／sand 的速度意象，改后各处皆适用；shake 项早已改用独立字形，不受影响）。解析门 world.gd / touch_controls.gd / ult_gauge.gd / ui_icon.gd 在 NUC `--check-only` 均 rc=0（各 3 条 ERROR 既有 SolanaSDK 4.4 噪音）。重跑批 NUC **1561/0 rc=0**（Test/out/u1_fix9_phonehud_2340.log，.done rc=0；1561 vs 1545 的 +16 已对账：同名检查集合相同，全是 full_prompt 态重复计数 91→107，与 fix2 的 +16 同型波动；P1 interact ready 三态 bg_a=0.95）。实测：交互盘就绪态采样 (233.8,131.7,22.9)≈参考橙；必字放大加粗＋深紫内底＋分段环更亮，crop 目检与参考接近；绿钮三横线与参考一致；小地图已现路径＋高程明暗（不再是平绿）。桌面批补跑（Test/u1_fix9_desktop_run.sh，log `Test/out/u1_fix9_phonehud_desktop.log`，**696 检 4 红**；−14 已对账：同名集合相同，全是 meowth_prompt 重复计数 128→114；4 红与 fix2–fix6 逐条相同——既有、非回归）。compare/U1.png 与 compare/U1_boss.png 已刷新（fix9 实拍）。**提交 75f1187（代码＋compare：world／touch_controls／ult_gauge／ui_icon／phonehud＋U1.png／U1_boss.png，phonehud 2340 1561/0，桌面 696/4 既有）。**复跑脚本留痕（未提交，供下轮复用）：Test/u1_fix9_run.sh、Test/u1_fix9_parse.sh、Test/u1_fix9_desktop_run.sh、Test/make_compare_u1.py、Test/make_compare_u1_boss.py。
- U1 局内 HUD（2026-11-11 12:0x–13:0x，第 9 轮）：**未关闭，U2 复核完成、U1 仍等裁定＋主控目检**。本轮三件事：①2340 复验——u2_recheck 批 NUC **1545/0 rc=0**（Test/out/u2_recheck_phonehud_2340.log，.done rc=0 OK；1545 vs fix9 的 1561 的 −16 已逐名对账：全是 full_prompt 横幅未起时 16 条 banner-disjoint 检查未跑，与第 3 轮同型波动，非回归）；②U2 菜单按新门复核（见下「U2 复核」）；③2400 档新发现 ring-home 7 红（见下）。U1 三项裁定（②锁钮去留、④击杀 +1、③技能行贴边）仍等用户／主控；compare/U1.png 与 U1_boss.png（fix9 实拍）仍等主控目检签核 1、5、6、7、8 五项。复跑脚本留痕（未提交，供下轮复用）：Test/u2_recheck_run.sh、Test/u2_recheck2400_run.sh、Test/make_compare_u2.py。
- U1 局内 HUD（2026-11-11 09:3x–10:0x，第 6 轮）：**关闭已被用户撤销（见「关闭门」）**。用户裁定（2026-11-11 09:01）原文转记——「U1 第 6 项技能格尺寸：按 v2 参考字面放大（目标约 130 设计 px，以 2340 档实拍量为准），推翻先前批准的 P4 46px 布局。本裁定授权联动修改 P4 布局常量（P4_MOVE_STEP / P4_ROWS_H 等）与 phonehud 中写死的 82.0 等相关检查——检查改向须与新常量一致、断言强度不降。技能栏底带外扩约 8px 一并处理。」**执行状态：已执行**。第 6 项已清：P4_SLOT 130、P4_MOVE_STEP 140、P4_ROWS_H 192（130+28+34，维生素行下移至 y158，等级签悬空 18px、与维生素行留 10 设计 px 间隙）、底带改移行条（P4_BAND_H 80、P4_STRIP_PAD 8 外扩、格上下各露 25）、已学格／锁格 130 圆（金边／白字图标 62px）；第 2 项已清：Lv 徽改奶油底＋深墨字、移至奖章右上 (61,4,56,26) 压住奖章右上缘（与参考「12级」签同位）。联动改向：s_bl 下限由绝对 0.8 改为最小可读格尺寸 36.8 逻辑 px（P4_SBL_FLOOR 0.28，world 与 phonehud 同值——首批 20 红根因：0.8 下限盖过 B0.2 cap（宽 0.646／高 0.5），簇伸进中央区＋气泡 span 165<300；另 `end.x - right` 检查须按簇 scale 折 8px 外扩）；phonehud 82.0→192.0、簇右端断言改为 `right + 8.0 * scale`。解析门 world.gd / phonehud.gd 在 NUC `--check-only` 均 rc=0。重跑批 NUC **1545/0 rc=0**（Test/out/u1_fix6_phonehud_2340.log，.done OK，约 10:00）。实测：格直径 126 屏 px（2340 实拍像素扫描，设计 130 × s_bl 0.646 × 1.5；参考格 118–133，同量级）、间距 136、签悬空 17px、底带外扩 8px；compare/U1.png 已刷新（fix6 实拍 hud_start）。桌面批补跑（Test/u1_fix6_desktop_run.sh，log `Test/out/u1_fix6_phonehud_desktop.log`，**710 检 4 红，与 fix5 逐条相同**——既有、非回归，已 diff 对账）。**提交 067e15c（台账原记 6d9ee7d 并不存在——见「第 6 轮订正」），已推送，ls-remote 核验 main=01bee73。**复跑脚本留痕（未提交，供下轮复用）：Test/u1_fix6_run.sh、Test/u1_fix6_parse.sh、Test/u1_fix6_desktop_run.sh、Test/make_compare_u1.py。U1 第 6 轮施工内容本身成立（8 项中 1–7 已清；第 8 项属 U2 域；英雄头像物种为占位内容；已学格类型色规则属实），**但关闭判定被 10:30 新门撤销**——并排图逐项仍有八项可见差异（见「U1 重开八项」），待清完过主控目检才许重关。

## 第 6 轮订正（2026-11-11 10:1x，上一轮超时后续跑）
- 台账原记代码提交 6d9ee7d「待推送」从未存在（NUC `git show 6d9ee7d` 报错、reflog 无此提交）。后续跑已收尾：工作区改动即第 6 轮代码（经 `git diff` 核对 P4_SLOT 130 等全套改动一致），提交为 **067e15c**（信息注明 6d9ee7d 不存在），另补台账订正提交 **01bee73**，已推送，`git ls-remote origin main` = 01bee73；NUC 与 VM 两树均已快进到 01bee73、工作区干净、tree parity OK。u1_fix6 批日志（1545/0）即该代码的实测证据。

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

## U1 重开八项（2026-11-11 10:30 用户点名，第 7 轮逐项定性）
用户判 compare/U1.png（fix6 实拍 hud_start）仍有八项可见差异。逐项定性（第 7 轮实测为准）：
1. **交互钮淡影圈 vs 实心橙盘**——状态性差异，非布局错。实拍 hud_start 态无可互动物在旁，`_interact_fill_a()` 按设计回 0.06（P1 断言 idle alpha ≤0.10，`touch_controls.gd:461`；另 `set_interact_mode` 0/1/2 三态）；参考渲染画的是就绪态实心橙盘。第 7 轮原方案（只加 chest 截图作对照、代码不动）**被 fix7 chest 图证伪**：就绪态填充仅 `INTERACT_FILL.a = 0.20`（P1 日志 `interact ready at chest :: bg_a=0.20000000298023`），实拍仍是淡影圈＋白「!」。**fix8 已修**：`touch_controls.gd` INTERACT_FILL.a 0.20→0.95（就绪态实心），按压态 interact 专属 0.42→1.0（其余钮仍 0.42），idle 仍 0.06；P1 断言不受影响（ready ≥0.18、idle ≤0.10）。**fix8 chest 图证实已实心；fix9 补色差**：盘色由金 (1,0.85,0.3) 改参考橙 (0.96,0.52,0.08)，fix9 chest 实拍采样 (233.8,131.7,22.9)≈参考 (245,133,21)。**第 1 项已修实证，待主控目检签核。**
2. **多出的白色瞄准钮**——实为 **tc-lock（锁定钮，crit 十字准星图标）**，非 tc-aim：P3「thumb cluster 无 pause/aim」在 fix6 批全绿，aim 在新布局下本就隐藏（`set_layout_classic(false)`）；白盘图标经 `ui_icon.gd` 核对是 crit（环＋圆点＋四 tick），target 图标是双环无 tick。锁钮是 P3 批准件：`_toggle_target_lock()`（world.gd:16496，点按锁定最近目标／取消锁定）＋ phonehud P3「lock on the arc」断言钉死其弧位。**清除它＝去掉锁定切换入口＋改向 P3 断言，须用户裁定，不可静默隐藏。待裁定（fix8／fix9 未动）。**
3. **技能行首格被左缘切**——**「切掉约一半」已证伪**：fix9 compare 目检首格（已学格）盘体完整，条带左缘设计 12px（P4 日志 bl=[P:(12,584),S:(456,124)]），首格未逐像素切断。残余为**贴边观感**：与参考比（首格左缘约设计 31px）仍贴边 2 倍以上。收窄改法受限：簇右缘 468 已顶住 P4「centre clear」区左缘（rows_right=462.8，仅 5.2px 余量），整簇右移会撞红；缩 P4_MOVE_STEP（140→132）则格间距只剩 2px，比参考 10px 更挤。**右移方案须改向 centre-clear 断言，待用户裁定；或接受贴边为布局上限。**
4. **击杀 pill 常驻 +1**——目标 pill 在 2340 被折叠进击杀 pill 的 +N（Plan Z3 批准行为，P3「隐藏项可达」断言钉死；第 3 轮已评估保留）。参考无 +1 且无目标 pill 常驻。清除它＝改折叠阈或改目标 pill 常驻策略，动 P3 布局与检查。**本轮未动，待用户裁定（fix8／fix9 未动）。**
5. **大招盘缺分段环**——**第 7 轮已修，fix7 实拍已证实画出**：参考必盘外有一圈 12 段淡紫弧段（充能刻度）。旧 `UltGauge._draw` 只在充能 >0 时画单色 sweep，0 充能时盘面全素。已加 12 段环（`r_out+3`，段宽 4，亮段随 charge 点亮、暗段常驻可读），桌面／触屏共用同一 UltGauge；fix7 hud_start crop 放大已见段块与段间缺口。fix8 把暗段 alpha 0.30→0.45（0 充能时更可读）。**fix9 再补字重与底衬**：`_ult_glyph` 字号 22→48（两处），`UltGauge._draw` 加深紫内底 (0.38,0.16,0.68)，暗段 alpha 0.45→0.65、段宽 4→5；fix9 crop 目检：必字大粗白字＋深紫底＋分段环清晰，与参考接近。**另附带**：绿冲刺钮 wind 字形由 blob 重画为三横极速线，与参考绿钮字形一致。**第 5 项已修实证，待主控目检签核。**
6. **顶栏多地名**——**第 7 轮已修，fix7 实拍已证实**：手机顶卡第一行「青苔林」（`_zone_cn`，world.gd:2974，phone 布局 Rect2(18,8,120,26)），参考顶栏无地名（「区域 1/4」签已表位置）。已把 `_zone_cn` 并入 `_apply_top_card_phone` 手机隐藏列表；phonehud P2「collapsed top-band items hidden」同步加 `zone_cn`（同等严格、新目标，照第 3 轮先例）。fix7 批 1545/0 且该断言 still shown=[]；新 hud_start 顶栏首行已无地名。**横幅半项已证实为瞬态**：fix8／fix9 chest 态图无开局横幅（改由头领横幅接替），开局横幅只在开局数秒内出现。**第 6 项已修实证，待主控目检签核。**
7. **小地图平绿**——烘焙已是真色＋浅草绿 lerp 0.45（第 3 轮），但地形本身对比弱，2340 实拍仍是一片匀绿＋淡纹；参考是亮色手绘风、有路／林地层次。**fix9 已调烘焙对比**：meadow lerp 0.45→0.25、高程 lift 0.35→0.55（只改 `_bake_minimap` 纹理，minimap 检查全是几何项）；fix9 minimap crop 已现蜿蜒路径＋高程明暗，不再是平绿一片。与参考手绘风仍有差距（程序化地形色 vs 手绘图标），属烘焙上限。**待主控目检判定是否够格。**
8. **缺 boss 态对照**——**第 7 轮已取新图**：fix7 boss 态截图（`mobile_p2_boss_2340x1080_s150_i0.png`，9:54、守护者红条 4229＋奶油「守护者」签＋「守护者出现了！」横幅、顶栏无地名）已拉回 VM，待拼 `design/ui-reference/compare/U1_boss.png`（参考 vs boss 态）。旧轮 boss 图（08:40）是修前状态（带地名、无分段环），不可复用。**fix8／fix9 已拼 compare/U1_boss.png（fix9 实拍）**：守护者红条＋白字血量＋奶油「守护者」签＋顶栏无地名，与参考结构一致；额外两项属状态内容——精英 mini 条（头领在场时才出现）与「守护者出现了！」横幅（瞬态公告），参考态无此二者。**第 8 项对照已备，待主控目检签核。**

## U2 复核（2026-11-11 12:0x–13:0x，第 9 轮，按 10:30 新门重拍重审）
- **结论：U2 未过 1:1 关闭门，重开。** 公司线旧 compare/U2.png（b54d753，竖屏 1080×2340 实拍）本身已注明「不能视为视觉对齐验收通过」，旧「已对齐」不成立。
- 新实拍：phonehud 2400 s100 批（capture combo 唯一出菜单图的档位；2340 批 `_p5_snap` 不出图），`Test/out/mobile_p5_menu_2400x1080_s100_i0.png`（12:44），compare/U2.png 已刷新（参考 vs 新实拍）。
- **根因已修（本轮）**：首拍菜单图层全失——无 Logo、无卡片图标、无开始橙钮、无插画背景、只剩文字＋3D 实景。根因＝`assets/menu/*` 的 25 个 `.import` 文件从未入库（`git ls-files` 只有 png/svg 本体），`load()` 全报 `No loader found`（首拍日志 13 条）。修法：NUC `Godot --headless --import` 重生成（rc=0），只留 `assets/menu/*.import` 25 个新文件入库；同批生成的 addons/SolanaSDK 14 处 churn 已 `git checkout -- addons/` 撤回，其余 51 个杂散 `.import`（design/ 参考图、ui-v2 图标、board 图）已删——**只留菜单 25 个**。重拍验证：菜单类 `No loader found` 13→0，Logo／插画背景／英雄／卡片图标／橙色开始钮全数回归（新实拍与 02:05 menu_fix0.png 逐项一致）。**注意**：ui-v2 图标 coin.svg／wooden-chest.svg 的 `.import` 同样缺失（日志仍有 2 条报错），但 U1 钱包 pill 当前走 UiIcon 程序化 fallback 正常显示——恢复真实 SVG 会改变 U1 已验外观，留待下轮单独定性，不在本轮顺手带入。
- 修复后与参考逐项对照（新实拍 vs v2 U2_final.jpg），可见差异：
  1. 四卡一排 vs 参考 2×2 两排——结构差。
  2. 「累计」pill 右缘溢出：`累计 400908` 的 `+` 被屏缘切掉一半——长数字溢出仍在（旧账：300908 已确认截断，现 400908 同症）。
  3. 第三卡文案「伙伴营挑战」vs 参考「联盟挑战」，且 5 字在卡内被右缘切——文案＋溢出双差。
  4. 商店／挑战卡顶各一枚红角标 18／11，参考无——角标件本身不在参考内（数字是动态值，角标存在与否待裁定）。
  5. 画面震动行缺失——公司线已批准移除（shakeOn 已进设置页，见 U2-round2-results.md），属批准偏离、新门下待主控确认。
  6. 左下提示为 5 行全文大盒 vs 参考单行 pill——公司线高度修复已批准保留全文（见 U2-height-fix.md），属批准偏离、新门下待主控确认。
  7. 初始伙伴：参考为「选择初始伙伴」三格金边卡，实拍为已选态长 pill「初始伙伴 · 妙蛙种子」——属状态差，须新档（未选初始伙伴）实拍同状态对照才能判。
  8. 钱包行：参考「钱包」＋绿「已连接」，实拍「连接钱包（可选）」＋灰「未连接」——属状态差，须已连接态实拍同状态对照才能判。
  9. 其余已对：Logo 位／字形（附带：实拍 Logo 下多一条绿 swoosh，参考无）、插画背景＋英雄位、开始橙钮（叶饰齐）、进入出战配置文位。
- U2 重开轮待办：①修 1、2、3 项（卡片改 2×2、累计 pill 自适应宽或数字缩写、第三卡文案／卡宽）；②裁定 4（角标去留）、5、6（两处批准偏离在新门下是否维持）；③取新档＋已连接态两张同状态实拍，清 7、8。

## 2400 档 ring-home 7 红（第 9 轮新发现，U1 域）
- 2400 s100 两批（修复前后）均为 `PHONEHUD DONE fails=7`，其余全绿（1660→1644 的 −16 亦为 full_prompt 横幅未起的同型波动）。7 红全是同一条：`P4: ring home unmoved at touchScale >= 1`（7 态），ring_bottom=580.725 vs raw=586（差 5.275px），z7_top=580.725——摇杆环被顶起 5.3px 以避让技能行（`ring clears slot rows` 恰在等值处过）。
- 成因分析（无需再跑旧档验证）：该检查的计划注释即「ts >= 1 needs no home lift」；fix6 把 P4_ROWS_H 由 82→192（用户裁定的 130px 格所致），行顶上移约 110px 后在 2400 s100 档顶到环的 home 位（586），遂触发顶起；2340 s150 档因缩放几何不同不受影响（本轮复验 1545/0 全绿）。即：**fix6 的副作用，只在 2400 档暴露，U1 验收口径 2340 档仍绿**。
- 处理：不动——修它须动技能行位置（下移约 6px）或改向该断言（放水，禁）；两者都牵连用户裁定的 130px 格几何与 2340 绿批，留待主控裁定（修行位 vs 接受 2400 档环顶起 5.3px vs 改向断言）后再动手。下轮起 2400 批须带此 7 红作已知项，不再当新发现报。

## U1 第 10 轮（2026-11-11 13:0x，本轮）：主控裁定执行轮
执行主控 2026-11-11 12:1x–12:2x 亲看 compare/U1.png、compare/U1_boss.png 与 fix9 宝箱态实拍后的裁定（②③④⑨）。已签核通过、不许再动：①交互钮实心橙盘、⑤大招盘、⑥顶栏地名已去／横幅瞬态、⑦小地图场景豁免、⑧boss 态守护者条。
- **④ 改法（实施前写明，主控纠正裁定 12:2x）**：定性——+1 是目标 pill 折叠进击杀 pill 的**目标计数**（Plan Z3，`_obj_folded` 时 `_kills_badge` 显示 "+N"），常驻信息、不是击杀飘字；先前「改为临时飘字」方案作废。改法三步：① `world.gd:_p3_place_objective`：`_kills_badge.visible = has and _obj_folded` → 恒 false（节点保留、几何赋值行不动），击杀 pill 恢复参考干净形态（骷髅＋「击杀 N」）；②目标信息改走目标抽屉通道（S17）：折叠态目标 pill 仍隐藏（`_obj_pill.visible = has and not _obj_folded` 不动），`_p3_obj_target()` 折叠时仍返回击杀 pill 节点（点按开抽屉），抽屉 `_p3_fill_drawer()` 已列全部目标，可达性由 phonehud 现成「objective tap opens the drawer」「drawer lists all」覆盖；③phonehud 改向：`_p3_folded()` 改读 `_world.get("_obj_folded")`（不再以 badge 可见为折叠信号），「one objective pill on phone」折叠分支改断言击杀 badge 不可见，text-size roots 不再纳入隐藏 badge。不动：`_obj_badge`（目标 pill 自身的 +N，pill 可见态）、折叠阈 `_p3_z_over`、抽屉几何。
- ②改法：touch_controls.gd 移除 tc-lock 建钮（`_build_button "lock"` 删）＋LOCK_ARC 常量删＋`_apply_column`／`column_top` 循环去 "lock"＋`apply_scale` 的 lock 特例删；`set_lock_state`／`consume_touch_lock` 保留（守卫式空转，world 消费点不动）；锁定功能收进暂停菜单——`_pause_fill_quick` 增「锁定目标」行（`_st_row`＋`UiTheme.make_switch`，初态＝`player.lock_target != null`，点按调 `_toggle_target_lock()` 后按 live 态重绘开关）；设置页触控说明行「锁定最近敌人／准星键」改「暂停菜单「锁定目标」」。phonehud 改向：「no pause / aim」检查扩为 pause／aim／lock 三钮皆无；删「lock on the arc」「lock clears all」；P1 暂停块新增「锁定目标」行存在＋开关可视＋点按后开关态与 `lock_target` 一致断言。
- ③改法：`_p4_layout_bl` 簇锚点 offset_left 12.0→23.0（首格左缘 20→31 设计 px，参考约 31；格 130／间距 140／P4_SLOT／P4_MOVE_STEP 全不动），s_bl 上限公式的左距项同步 12.0→23.0（布局自洽；上限仍卡 0.30·vw，phonehud centre-clear 断言本身不改、仍全绿——改向的是布局上限公式的左距常量，台账记明）；其余 P4 断言不动。预计 s_bl 0.646→0.630，格实拍 126→约 123 屏 px（仍在参考 118–133 内）。
- ⑨(a)：Lv 徽改深底白字（`_panel` bg CREAM→Color(0.10,0.07,0.20,0.92) dark=true，`_lv_label` UiTheme.TEXT→Color.WHITE，位置 (61,4,56,26) 不动；第 6 轮「参考奶油徽」注释订正为误判）；技能格下「N级」奶油签是参考同款、不动。
- ⑨(b)：第三资源图标改回木纹宝箱——根因＝`assets/ui-v2/icons/wooden-chest.svg` 的 `.import` 从未入库（`load()` 失败 → UiIcon "ball" 程序化 fallback 红环）；修法＝NUC `--headless --import` 重生成后只留 `assets/ui-v2/icons/*.import` 入库（同第 9 轮菜单 .import 修法），金币 coin.svg 同批恢复（同缺失）。实拍核验宝箱／金币是否与参考一致。
- ⑨(c)：绿钮 wind 字形判定——局部放大对比确认不一致：参考为带速度线的「3」形旋涡，实拍（fix9 三横线）为三条直横线。改法：`ui_icon.gd` "wind" 重画为双弧「3」＋左侧两条速度线（24 空间：上弧心 (15,8) r5、下弧心 (15,16) r5，弧角 ±2.0、线宽 3.2；速度线 (3,10)→(9.5,10)、(3,14.5)→(9.5,14.5) 线宽 2.6）；wind 同时是 spd／attackSpeed／sand 的速度意象，改后各处皆适用。
- ⑨(d)：左上角小暂停钮来源＝`_pause_badge`（`_medal_panel` 左上 (-2,-2) 22×22「‖」徽，`_p3_apply_mode` 在新手机布局下常驻显示，意为「点头像暂停」）。定性：常驻 UI、参考无此徽 → 按参考移除：`_p3_apply_mode` 不再置 visible（节点保留、建时已 false），建处注释订正；phonehud「portrait wears the pause badge」改向为「portrait wears no pause badge（reference）」（徽存在但隐藏；头像点按暂停入口由前一断言继续覆盖）。
- 本轮新发现（目检 compare／裁剪图，待主控裁定、不擅自改）：①触屏大钮（绿／蓝／橙）参考为深色 rim，实拍为奶油 rim；②技能锁格参考为银色粗 rim＋奶油锁，实拍为细亮 rim＋浅灰锁。两处皆为系统性配色差，留主控定是否纳入关闭门。
- **fix10 首跑（NUC，Test/out/u1_fix10_phonehud_2340.log）：1449 检 16 红**。16 红全是同一对 P4 几何钉死断言（8 态 × 2）：「BL cluster is exactly the slot rows」（簇左缘钉死 ui_rect.x＋12.0）与「s_bl = min(s, 1.35, bubble fit)」（want 公式左距项 12.0）——正是③右移后须联动改向的断言：两处常量 12.0→23.0（断言本身不改、强度不变：左缘仍精确钉死、s_bl 仍精确等于公式值），另补相机滑动与经典布局两处锁钮残留（见下）。计数对账（1561→1449，−112 全数解释）：P1 ＋3（新增锁钮三断言）；P3 −14（删「lock on the arc」「lock clears all」−22、新断言＋11、相机滑动尾部 3 条因崩溃未跑 −3）；P4 −16（16 红由绿转红）；tc_lock 通用 disjoint 检查 −约 99（钮没了）；full_prompt 横幅重复 −15（时序波动，同 fix2／fix6 的 ±16 型）；其余 P2／P5 不变。
- **相机滑动崩溃（首跑漏 3 条断言的根因）**：`_p3` 相机滑动块直接读 `btns["lock"]`（SCRIPT ERROR，log L1061），函数中途退出，尾部 D6 round trip 未跑（「classic switch flips／round-trip」2 条＋滑动本身 1 条共 3 条缺失）。改向：滑动改跨 dash 钮（弧位原锁钮处、右拇指路径内），断言更名「camera swipe across the thumb cluster keeps turning」；`_p3_layout_sig` 删 "lock" 键；经典态 `_p3_classic_state` 的 column 断言改 pause／aim 两钮（xs[0] vs xs[1] 对齐），`_p3_desktop_state` 的 col 循环同改；world.gd 残留「pause / aim / lock column」注释五处一并订正。以上改动与 16 红改向同属本轮 fix10，不另起轮次。
- 已知待办 2（非 p5 布局 Resources 药丸 sparkle UiBadge 丢失）仍留 U2 轮，不混入本轮。

## 下一轮：U1 第 10 轮——起工清单（2026-11-11 13:0x 更新）
U1 已重开，U3 不得开工（见「关闭门」）。第 9 轮：2340 复验 1545/0；U2 复核完成——**U2 重开**（菜单 .import 已修、图层回归，残 9 项差异见「U2 复核」，其中 1、2、3 可修，4、5、6 待裁定，7、8 待同状态实拍）；2400 档 ring-home 7 红为 fix6 副作用、留待主控裁定。
- **等用户／主控裁定（U1 三项＋新增两项，皆不可静默改）**：U1 ②锁钮去留（清掉＝去锁定入口＋改向 P3 断言）；U1 ④击杀 +1 去留（清掉＝改折叠阈或目标 pill 常驻，动 P3 布局与检查）；U1 ③技能行贴边（右移须改向 P4 centre-clear 断言，或接受为布局上限）；2400 ring-home 7 红（修行位 vs 接受顶起 vs 改向断言）；U2 批准偏离确认（画面震动行移除、提示全文大盒、红角标去留）。
- 主控目检 compare/U1.png 与 compare/U1_boss.png（fix9 实拍）签核 U1 的 1、5、6、7、8 五项；过门则 U1 重关、开 U3；不过则按目检意见继续修。U2 重开轮在 U1 之后（顺序 U1→U3→U5→U4→U6，U2 复核已做、不插队），但 1、2、3 三项修复可在 U1 轮后顺手做。
- 同步铁律不变：NUC 侧提交推送后，必须先把新提交取回 VM（NUC .git 反向 rsync），再跑 sync_to_nuc；否则 NUC 的 .git 会被回滚到 VM 的旧 HEAD。**本轮新增：VM 直推 origin 已证实不通（本轮，`kex_exchange_identification: Connection reset by 198.19.0.1:3128`），推送须走 NUC scratch 克隆＋gh 路线。**
断点：第 9 轮代码未动（只补 `assets/menu/*.import` 25 个新文件）；compare/U2.png 已刷新（12:55，2400 s100 新实拍＋.import 修复后）。2400 批两份日志：Test/out/u2_recheck_phonehud_2400.log（修复前 1660/7、修复后 1644/7，.done rc=1 FAIL 系 7 红所致）；2340 复验 Test/out/u2_recheck_phonehud_2340.log（1545/0 rc=0）。ui-v2 图标 .import 缺失（coin／wooden-chest 日志仍报 2 条）留待下轮定性。

## U3 暂存（2026-11-11 10:3x，第 7 轮开工后因 U1 重开而全数回滚，代码未留痕）
- 回滚原因：10:30 用户撤销 U1 关闭并定版新关闭门，U3 在 U1 重过门前不得开工。本轮已做的 U3 改动（world.gd 草稿卡密度＋phonehud draft 截图）已 `git checkout` 撤回，VM／NUC 两树干净、tree parity OK（234 文件，10:48）。
- U3 差异清单（参考 U3_final.jpg vs 接线轮实拍 ui_draft_reskin_final.png＋2400 draft 图）：①卡身偏空（已知待办 1，布局密度差）：手机卡 220×230（桌面 222×302），顶区 112＋标题 18＋描述 13，描述与 [n] 脚之间约 60px（桌面约 130px）空洞；参考卡高瘦（宽高比约 0.68）、画板占约 46%、标题奶油 pill、叶形分隔、细节行到底无空洞；②标题无 pill；③无叶形分隔；④画板是扁平类型色＋小白字形标（78px），参考是大画幅场景＋英雄立绘（3D 模型豁免内，字形标暂留）；⑤主推卡（中间「优秀」）参考更高＋金边辉光，现为同高＋稀有度 rim＋shine；⑥顶横幅参考是奶油 pill「8级 · 升级！」＋金星＋绿叶，现为面板上金字标题；⑦参考无大面板、卡直接浮于场景，现为奶油面板（P5 模态 legacy 860×452 钉死，面板不动）；⑧工具行基本一致（重抽蓝／跳过／放逐，计数一致），buildMini＋队伍钮为功能外加行、保留。
- 已验证的实施草案（下轮 U3 开工时照此做，不用重侦察）：手机卡 220×230→220×300、顶区 114→150、字形标 78→96、flow 顶 122→158、标题 20px 进奶油 pill、标题与描述间加叶形分隔（UiBadge "leaf" 18px＋两侧细线，leaf 有 `assets/ui/badges/badge_leaf.png` 优先、无则 UiIcon 画字形）、描述 13→15px；桌面卡 302 高不变、同套内容改动共用 `_draft_card`；2340 draft 截图须在 phonehud P5 draft 块加 `_snap("phone_hud_touch_" + _run_tag() + "_draft")`（只取图、不动断言；`_p5_snap` 只在 2400/1920 组合出图，2340 须另加）；P5 断言约束：卡片单行在面板内、工具左／队伍右同行、面板 scale ≥1.5 且在 UI 区内；桌面模态 legacy 860×452 不可动。面板纵向预算：标题 32＋卡 300＋mini 36＋工具约 40＋分隔 30 ≈ 448 ≤ 452，紧但可进（超了看实拍再裁）。
- U1 重开前遗留的两项定性（已闭合，记此备查）：白色瞄准钮＝ tc-lock（crit 十字准星标，见八项第 2 项）；交互钮淡影圈＝无可互动物时的待机态（`_interact_fill_a()` 回 0.06，见八项第 1 项）。
## 第 5 轮侦察（2026-11-11 07:2x，只读，未动代码）
- Boss 卡淡出机制（world.gd:12325–12326, 12328）：`_boss_card.modulate.a = 0.0 if _boss_body_overlaps_header() else bossOpacity`；`_boss_body_overlaps_header()` 为守护者各 MeshInstance3D 投影包围盒（grow 16）与 `_p3_draw_rect(_boss_card)` 相交即淡出。生产逻辑按设计不动；取主卡可见图须在 harness boss 态让守护者离开 header 投影区再抓拍（或 reskin_boss.tscn 单独拍）。
- 技能格构造（world.gd:14870 `_p4_refresh_slots`）：已学格 46×46 Panel＋`UiTheme.badge_base()`＋22px 类型 icon＋格内「N级」label（y24）；锁格同尺寸深色 `_style(...)`。第 5 轮：底带（`_bl_rows` 背后加深色药丸底板，勿动 `_p4_rows_w` 宽度断言）、已学格金边（badge stylebox 换金 rim）、格下奶油「1级」签（注意行锚点 (12, vh−12)，签须叠在底带下沿内、不扩行高）。
- 英雄簇构造（world.gd:14239 `_p2_hero_box`）：簇盒手机 340×86（有队友 104）。第 5 轮：簇内加深色药丸底板（Panel 子件放最底层、dark_glass、尺寸随簇盒），头像圆可沿参考 protrude 于底板左缘；须过 P2 簇盒断言与 P5 重叠检查（底板不得与顶中卡相交）。

## 订正（2026-11-11 10:1x，主控补录）
- 第 6 轮台账提交 5d617a3 中引用的代码提交 6d9ee7d **不存在**（该轮超时中断，代码提交从未落盘；工作树改动完好留存）。真实代码提交为 067e15c（本提交），U1 关闭结论不变（phonehud 2340 1545/0，desktop 710/4 既有）。

## U1 第 10 轮（公司电脑续作，2026-11-11）
- 选择 **(a)**，从经 Git 核验的 `1b6b302` 续做 `wip/u1-fix10-handover-2026-11-11`。已同步 main 至 `b4226b2`，交接单与台账以该版本为准。
- 续作提交 `05b4f36` 已用 Git 核验。沿用 WIP 的 HUD 锁定钮迁到暂停设置、技能行右移、暂停徽隐藏及相机跨冲刺钮测试；把 P4 缩放公式最后一处左距由 12 改成 23，保留原等式及容差。实拍见 `compare/U1.png`、`compare/U1_boss.png`。
- 2400 ring-home 定性为 **真实位置偏移**。生产代码把技能行顶缘传给 `set_ring_bottom_limit`，`_joy_home` 按差值上移。fix10 的实际环底及技能行顶均为 583.7167，原始 home 底缘 586，差 2.2833 逻辑 px。断言 `P4: ring home unmoved at touchScale >= 1` 在 hud_start、hud_alpha、chest_prompt、meowth_prompt、boss、events3、moves3_vits2 七态失败，`P4: ring clears slot rows (Z7 top)` 仍通过。实拍 `compare/U1_ring_home_2400.png` 为 2400×1080 s100 开局，左下摇杆环底贴着技能行顶。保留断言及现有生产逻辑，交 Muse 裁定。
- U1 仍未关闭。实拍仍可见触屏钮浅 rim、锁格细 rim 与浅锁等差异；④目标折叠计数迁移与同状态逐项签核仍待完成。U3 未开工。
- 公司电脑 phonehud：2340×1080 s150 i0 **1482/0**（`Test/out/fix10-exact-2340.log`），锁定开关实际切到 locked=true、跨冲刺钮滑动 dyaw=-0.6、经典布局往返均通过。2400×1080 s100 i0 无窗口批 **1562/11**（`Test/out/fix10-headless-2400.log`），包括上述 7 条 ring-home，另有双指测试被 draft 遮住、抽屉自动收起、头像暂停可达、祝福打开共 4 条红。2340 同尺寸 main 对照 **1577/2**（抽屉自动收起、头像暂停可达），只作为同环境对账，主控按验收口径复跑。
- 本机用固定步长 60 复跑。为避免隐藏窗口的截帧等待挂住，图形诊断批临时强制绘制，最终无窗口批临时跳过截帧；这两处本地跑批处理未入库，检查条件未改。逐文件解析日志无脚本解析错误，Godot Windows 进程退出码为 -1073741819。以后公司电脑测试使用后台无窗口模式。

## U1 第 11 轮（主控裁定后续作）
- Muse 已确认 `fe2f631` 的 2340 1482/0 及②③⑨(d) 实拍。⑨(a) 深底白字等级徽、⑨(b) 木纹宝箱、⑨(c) 旋涡冲刺 glyph 的落地点均为经 Git 核验的 `1b6b302`。
- ④施工方案：击杀条折叠时隐藏 +N，点击击杀条打开目标抽屉，逐项保留事件标题、副文案、挑战及计数。核对 `1b6b302` 已按此落地，P3 检查验证折叠时徽标隐藏、实点可打开抽屉、抽屉内容齐全。补同状态实拍。
- 2400 裁定：允许摇杆避让技能行，预期环底为原 home 底缘与技能行顶限的较小值，维持 1.0 容差及独立不重叠断言。抽屉自动收起与头像暂停可达是 main 对照既有红；双指遇 draft 和祝福打开先用 main 2400 同档定性。
- `a4f1718`（Git 已核验）：触屏冲刺／跳跃／交互换深色外圈，技能锁格用 6px 银边和奶油锁。按折叠态实拍与抽屉展开实拍制作 `compare/U1_objective_folded.png`，2340 的抽屉触达与内容断言通过。 `compare/U1.png` 更新为宝箱就绪态，便于同状态看橙钮。截图在未切换的独立桌面渲染，phonehud 使用 headless；headless 仅跳过截图，保留全部断言。
- 2400 s100 i0 无窗口对照：main `b4226b2` **1666/12**，本轮 **1562/4**。本轮 7 条 ring-home 检查及独立技能行避让检查均通过。双指被 draft 遮住、祝福打开、抽屉自动收起、头像暂停可达四条在 main 同档全部复现，定性为既有红。
- 2340 s150 i0 无窗口首跑 **1472/5**，main 同档 **1577/2**。抽屉自动收起及头像暂停可达同名复现。首跑另有双指遇 draft、天气说明、祝福打开三项，继续复核。U1 关闭签核材料已备，仍以 Muse 验收为准。U3 未开工。
- 2340 无窗口复跑 **1480/3**（`Test/out/fix11-repeat-2340.log`）。天气说明与祝福两项通过，双指仍遇 draft，另两条为 main 同档已复现的 P3 红项。2340 双指问题留在 U1 继续定位。

## U1 第 12 轮
- `3dfd5a1`（Git 已核验）：击杀条按 U1 定稿改奶油底、深墨字和骷髅，保留原几何和目标抽屉入口。宝箱就绪态实拍已刷新 `compare/U1.png`。
- 2340 s150 i0 无窗口批 **1474/3**（`Test/out/fix12-2340.log`）。双指采样前结算迟到的 draft 后，通过了持摇杆旋转和松手检查，dyaw=-0.6。两条 P3 既有红仍在，祝福打开被 draft 遮挡再次出现。最后骷髅眼孔换色后复拍通过，完整批数字来自同轮眼孔换色前。U1 继续对齐并等待 Muse 签核。

## PM 改派与 GitHub 起点核验

- GitHub 交接分支 `wip/u1-fix10-handover-2026-11-11` 起点为 `a0cf74ee5e992f40ebc1d14b47e7858a21fe481a`，已写回 Notion 任务 `414858d406aa81ed9a17e8533ee8484d`。
- 在独立工作树 `E:/DevTools/.codex/worktrees/spritebonk-align/sprite-bonk` 接手，施工分支 `align-muse`。原 U1 工作树的续作和未提交修改保留。
- 最新顺序为 U2 → U1 → U3 → U5 → U4 → U6。用户已允许调整固定横屏策略以实现 S25，方向和青绒命名排在 U2 之后，尚未施工。

## U2 首轮修复与素材接回

- 已推送提交 `2ec425c8cf390fea41d03f4ce980e2b11cd70e94`。此前未推送的本地 `b1f5073` 和 `09ed0e8` 已在本地修订，最终远端 SHA 经 ls-remote 核实。
- 同机起点后台固定 60 步长基线为 2340 s150 **1474/3**、2400 s100 **1564/3**，三类失败为抽屉自动收起、头像暂停可达、祝福被迟到 draft 遮挡。
- 恢复原 home 断言与 1.0 容差，并给槽行增加原 home 下方的缩放约束。保持 130 设计格、12 底距、独立 ring clears 判定。2400 环底恢复 586，七态原 home 全过。首次类型推断解析错误已改显式 float，失败批未计成功。
- 九项施工覆盖两排四卡、长累计自适应、伙伴营文案完整显示、手机角标隐藏、震动入口恢复、短提示条、三伙伴常显和钱包状态同步。完整操作说明保留为 tooltip。文案遵从已批准的萤尘、伙伴营词表。
- 用户指出应直接复用仓库素材后，接回三张 `v2-starter-{stump,coal,shell}.svg`，复用 UiTheme 的 `panel_9patch.png`，使用既有背景、角色、石台、Logo、图标与按钮。没有新增生图。三伙伴卡按 `v2-starter-tray.svg` 原卡位比例排布并显示选中边及勾。已解锁伙伴保留真实头像、名称和入口，空列表引起的滚动条已消除。
- 布局统一依据 1672×941 参考矩形换算。方法已改为固定状态实拍与菜单快速检查迭代，整屏稳定后做双档全程，避免每次局部微调都跑整场。
- 复用修订全程日志 `u2-assets-final-2340.log` 为 **1474/3**、2400 为 **1564/3**，逐名对比起点新增失败为 0。最后卡位、空列表呈现调整由 `u2-clean-slots-fast` 双档 **113/0** 补证。全程与末次呈现快检的时点分别记录。
- 真实后台桌面截图已目检，`compare/U2.png` 为左右对照。累计 400908 完整，钱包绿色已连接来自公开地址内存夹具，未调用授权、查询或保存。震动开关真实信号往返 PASS。
- Windows 引擎仍在退出时发生 free_static 崩溃，DONE 检查结果与正常退出分开记录。U2 尚有现成 Logo 绿下划线与插画图标细节差异，未自报关闭。

## U2 同屏续作

- 上轮不应以定时任务代替当前连续施工。本轮继续 U2，先将菜单中文标题和开始按钮改用仓库已有的粗体字体链，修正与参考的字重差。
- 本轮 `u2-font-fast` 双档菜单 **113/0**，震动往返 PASS，后台实拍已生成。完整游戏规则与摇杆布局未改。
- 前几段新增台账曾因 PowerShell 到 Python 的编码转换损坏为问号，本轮只重建了自己的新增记录，原 `a0cf74e` 之前台账完整保留。

## U2 药丸纹理续作

- 实际加载的仓库按钮原图已导出核对，原图为圆头。定位到 U2 复用的通用九宫格切片在矮按钮上形成尖角，本轮仅对手机菜单钱包与资源药丸直接拉伸同一张 `button_cream.png`，保留点击和聚焦入口。
- 首次并行快检与截图发生内存分配失败，旧截图时间未更新，未计新实拍成功。已改为两档依次执行再单独截图。`u2-pill-serial` 双档菜单均 **113/0**，仍记录 headless 退出时既有 free_static 错误。
- 新后台实拍已生成，图形进程退出 **0**，截图日志无 SCRIPT ERROR，震动往返 PASS。目检钱包与两处资源药丸的尖角已消除。
- 本轮全程复验按 2340 后 2400 逐档执行，`u2-pill-full-2340.log` 为 **1482/2**，`u2-pill-full-2400.log` 为 **1572/2**。两档仅余基线已有的抽屉自动收起、头像暂停可达，新失败为 0，祝福打开本轮通过。2400 七态原 home 与独立 ring clears 检查均通过。U2 关闭状态未改。
- `Test/make_compare_u2.py` 已固定为左右对照并支持当前 Windows 字体路径，后续直接复用同一命令出图，减少手工拼图差异。

## U2 下一轮差异清单

- 继续保留仓库素材优先。现有三张 SVG 伙伴剪影仍比参考多出脸盘、折线和分层头盔，下一轮在同一 SVG 文件中修圆润轮廓、眼睛与旋涡，不改物种 key、玩法与已有 3D 模型。
- 现有位图 Logo 自带绿下划线，参考没有。先核对仓库字形与叶片能否用现成字体和矢量件组成同版 Logo，避免重新生图。
- 本轮预览已验证仓库 Fredoka 字体可以组成无下划线字标。接下来以原有 UiIcon 绘制品牌叶片和震动手机图标，替换与参考不符的紫色徽章，保留按钮尺寸、功能与字体可读下限。

## U2 剪影与字标续作结果

- 三张原 SVG 保持 128×128 与原路径名，已修为圆润木桩、裂纹团与旋涡壳。仓库 Fredoka 字体组成奶油字面、深棕描边字标，去掉原位图中额外下划线；品牌叶片和震动手机复用 UiIcon 的矢量绘制体系，累计图标复用仓库五角星。原位图保留，未修改 3D 模型或玩法。
- 实拍发现普通 `_mk_label` 把字标奶油色映为深墨色，新增一条颜色回归检查并先跑出 **114/1** 红样本，再用已有 raw 参数保留字面色。最终菜单两档均 **114/0**，原 113 项完整保留。
- 冻结代码后按两档逐次全程复验，`u2-graphic-full-2340.log` **1475/3**、`u2-graphic-full-2400.log` **1565/3**，相对同机基线仅增加一条字标颜色检查，新失败为 0。三条既有红仍为抽屉自动收起、头像暂停可达及祝福打开遇迟到 draft。
- 最终后台实拍已目检，白色字标、无下划线、手机图标、五角星与三张剪影均可见。捕获逻辑视口为 **1560×720**、菜单矩形 **(8,4,1542.667,712)**、缩放 **1.582222**，与 2340 phonehud 一致。震动往返 PASS。截图生成后仍遇既有退出崩溃，未将退出记为 0。
- U2 尚未关闭，四入口原位图与参考在玻璃瓶、红白篷、红旗和灰色齿轮的绘制细节仍有差异，继续同屏修正。

## U2 四入口图标施工清单

- 本轮以定稿四卡局部逐项核对，现图的细颈立体药瓶、橙色篷布、橙金旗帜和绿色齿轮轴心与参考不符。
- 在既有菜单素材目录增加透明 SVG 变体，分别还原绿色玻璃瓶、红白篷布、红旗绿叶和灰色齿轮。手机菜单沿用同一卡位及入口信号，原位图留存。新素材配套导入元数据一同提交，先跑菜单两档检查及实拍，再做本轮最终双档全程。

## U2 四入口图标复验

- 四张 SVG 已接入并配套导入元数据，XML 解析全部通过。TextureRect 先设置忽略原图尺寸再赋纹理，避免原始尺寸抬高布局下限。
- `u2-entry-serial` 两档菜单均 **114/0**。独立后台桌面新实拍已目检，绿色玻璃瓶、红白篷布、红旗绿叶与奶油轴心灰齿轮均可见，震动往返 PASS，`compare/U2.png` 已刷新。
- 冻结代码后依次完整复验，`u2-entry-full-2340.log` **1475/3**、`u2-entry-full-2400.log` **1565/3**。与同机起点逐名比较新增失败均为 0，剩余仍为抽屉自动收起、头像暂停可达及祝福遇 draft。2400 原 home 和独立技能行避让检查通过。
- 截图成功保存后图形进程退出码 3221225477，仍有既有退出崩溃。U2 继续同屏核对钱包小图与参考的扁平描边差异，关闭签核待主控验收。

## U2 钱包小图施工清单

- 已逐图核对仓库两张钱包 PNG，均为立体皮革画法。定稿为浅棕平面钱包、深棕描边及奶油扣点，本轮添加同目录 SVG 变体，复用原按钮卡位与连接状态逻辑。
- 已连接胶囊补定稿中的白色状态圆点，沿用实时连接结果，继续以后台已连接夹具核对显示。
- 同屏放大复核发现第三伙伴参考为左右两枚旋涡，当前单旋涡带眼睛仍有造型差。本批一并修回双旋涡低矮轮廓，保持原 SVG 路径与物种 key。

## U2 九处重开项验收索引

1. 四入口恢复 2×2，四入口实点打开与关闭由菜单检查覆盖。
2. 累计根据实际字宽扩展，400908 加号完整可见，实拍与屏内检查均已核对。
3. 第三卡显示批准文案「伙伴营挑战」，五字完整，定稿旧「联盟」按文案替换表执行。
4. 手机菜单商店与挑战角标隐藏。
5. 画面震动行恢复，开关往返实点与设置同步已验证。
6. 左下恢复单行操作提示，全文存于提示信息。
7. 新档三伙伴卡常显，绿色选中态可见，双旋涡剪影已校正。
8. 钱包保留真实未连接与已连接状态，已连接夹具实拍显示绿色胶囊、白点与完整文字，浅棕描边钱包已接入。
9. 无下划线字标、品牌叶片和四入口平面图标已核对。插画背景、英雄位、石台与开始钮沿用仓库素材。

上述为施工方逐项交验索引，主控关闭签核仍待确认。客观差异包括动态数值与批准文案替换，底图及英雄沿用仓库现有插画，未改 3D 模型或游戏场景。

## U2 钱包与双旋涡复验

- 钱包修正后菜单两档快检均 **114/0**，随后校正双旋涡。最终后台实拍已目检，浅棕钱包、已连接白点及双旋涡均可见，震动往返 PASS，左右对照图已更新。
- 最终冻结批 `u2-wallet-shell-full-2340.log` **1475/3**、`u2-wallet-shell-full-2400.log` **1573/2**，逐名比较同机基线新增失败均为 0。2400 本轮祝福通过，只余抽屉自动收起与头像暂停可达。退出崩溃仍与 DONE 检查分别记录。
- 本批提交后连同九项索引提交 U2 关闭签核，关闭状态由主控验收决定。

## U2 双档实拍续核

- 补获 2400×1080、touchScale 1.0 后台实拍，图形进程退出 0，仍有资源释放错误日志。九项内容均可见。
- 放大第三卡发现重复边框，定位为托盘 SVG 内烘焙的三张底卡与运行时可选按钮同时绘制。托盘中第一卡还固定为绿色，切换伙伴会残留假选中。本轮将托盘保留为外壳，卡面与选中标记统一由现有按钮绘制，并把水系未选边框还原为淡紫。
- 补验三卡焦点、实际点击进入配置、返回菜单及右箭头循环，检查选中态与物种一致，继续同屏施工。
- 实际触摸往返三张卡和右箭头均已通过，放大截图时另发现菜单入口在首次打开与返回后横向漂移。原入场动画保存旧布局 x，随后与参考布局重排争写位置。本轮先增加重排位置稳定检查复现，再让手机入场动画只负责淡入，位置交给布局。

## U2 双档实拍续核结果

- 托盘 SVG 已去除三张固定底卡，运行时按钮绘制唯一卡面与选中态。水系未选边框改淡紫，切到火系及水系时原木桩卡恢复未选，重复边框与假选中均已由实拍排除。
- 新增重排稳定检查先得到 `u2-relayout-red-2400` **115/1**，五入口全部漂移。手机入场改为淡入后，`u2-relayout-final` 两档菜单均 **115/0**，原 114 项完整保留。
- 最终完整批 `u2-relayout-full-2340.log` **1476/3**、`u2-relayout-full-2400.log` **1566/3**。新增一条稳定性检查，逐名对比同机起点新增失败均为 0，剩余仍是三类既有红。2400 原 home 与独立避让检查均通过。
- 两档均用独立后台桌面、新建隔离用户目录和 90 个 process_frame 等待后实拍，避免入场中途及夹具沿用已看提示状态。三卡真实触摸进入配置并返回、箭头三次循环、开始进入对应水系配置、菜单位置稳定及震动往返共 **9/9** 项双档全部通过。已目检初始态和异选态，无 SCRIPT ERROR；两次图形进程均在完成保存后发生既有退出崩溃。
- 2340 对照为 `compare/U2.png`，新增 2400 对照 `compare/U2_2400.png`。拼图脚本仅增加可选输出路径，默认路径继续兼容。主控关闭签核材料更新至本批，U2 仍待验收。

## U2 旧存档伙伴列表续核

- 已核验 GitHub main 更新为 `455b231`，新增内容为音效需求文档，未发现 U2 新签核记录。
- 以仓库物种表选择三个真实已解锁家族的内存夹具实拍，发现手机伙伴列表内原 VBox 把横向滚动区撑高，第二、三张解锁卡落到屏幕下方；新卡还默认显示选中标记，导致多选假象。前次仅以滚动区自身高度判可达过于宽松，截图已证伪，改用托盘及屏内范围核对。
- 修法为手机解锁列表改同行 HBox，保留现有横向滚动；所有卡面通过同一选中刷新路径处理，新卡标记按当前物种初始化。桌面继续原有纵列。随后实点每张解锁卡进入对应配置并返回，验证旧存档显示与功能。
- 修后两档后台图均已目检，三个解锁卡各自实际触摸进入正确物种配置并返回全部通过，任一时刻只显示一个选中标记。2400 滚动区域由高度 471.5022 缩回 155.0578 逻辑 px，三卡均在托盘内。
- 新增托盘范围和唯一选中两条回归检查。首跑误用包含未裁切后代的范围聚合，得到 117/1；改为测量 ScrollContainer 自身显示矩形后，`u2-roster-corrected` 两档 **117/0**。检查保留屏内托盘约束，旧 VBox 撑高会失败；原 115 项完整保留。
- 最终完整批 `u2-roster-full-2340.log` **1478/3**、`u2-roster-full-2400.log` **1576/2**，比上一批增加两条旧存档回归检查，逐名对比起点新增失败为 0。2400 本轮祝福通过，仍只余既有抽屉与暂停两红。两档旧存档图形进程在完成三卡往返与保存后均遇既有退出崩溃。
- 新档双档对照继续保存在 `compare/U2.png`、`compare/U2_2400.png`，旧存档第三卡选中实拍补为 `compare/U2_roster_2400.png`。U2 尚待主控关闭签核。

## U2 伙伴切换可见性续核

- 旧存档滚到已解锁伙伴后，箭头仍按原有三个初始伙伴顺序切换，但新选中的初始卡可能留在屏外。保持既有切换顺序，本轮让选中卡随选择滚回可见范围，并排除等待删除的旧卡。
- 先加滚到末端后按箭头的可见性回归检查，再补两档真实触摸实拍。

## U2 用户贴边反馈修正

- 用户指出四入口图标及文字、钱包、震动行与出战配置说明贴到容器边缘。定位到入口卡的图标从 y=1 开始、标题占到底边，钱包图标沿用 40 高，震动开关的触控下限比行高还大，说明底条高度又小于文字行高。
- 本轮按实际字体最小行高布局卡内文字，图标上下留白，钱包图标缩为 32 并居中，震动行按开关高度加 16 留白，说明底条按文字行高加 12 并垂直居中。触控与字体下限继续保持，两档新实拍逐处核对。
- 箭头回归先在 2400 得到 **118/1**，确认选中木桩卡仍在屏外。选择刷新调用滚动区现有可见性接口后，旧存档实际触摸箭头回到首卡并显示选中标记通过。
- 增加图标、标题、钱包、震动行与出战说明共 15 个内容区域的内边距检查，所有区域与容器边缘至少保持 6 个逻辑像素。`u2-padding-gate` 菜单两档均 **119/0**，字体及触控下限检查通过。
- 两档最终真实渲染已逐处目检，四卡图文、钱包和震动行均有留白，出战配置底条完整包住文字。新档操作与震动往返双档通过，旧存档三卡配置往返及箭头回首卡可见通过。两档新档与 2400 旧存档对照均已刷新，图形进程保存完成后的既有退出崩溃继续单列。
- 最终完整批 `u2-padding-full-2340.log` **1480/3**、`u2-padding-full-2400.log` **1570/3**，逐名对比起点新增失败均为 0，内边距与箭头可见性检查在完整批亦通过。三条剩余红仍为既有抽屉自动收起、头像暂停可达及祝福遇 draft。用户本次贴边反馈已完成代码修正与双档实拍核对，U2 总体关闭仍待主控验收。

## U2 左侧组按用户局部定稿续作

- 用户指定先对齐钱包、四入口和震动行。角色造型与落脚项暂存，已通知素材处理停止新流程。
- 定位左组仍跟随超宽视口横向拉伸，四卡比例偏宽，厚纹理边与过大的开关也偏离定稿。本轮左组采用与参考高度相同的横向比例，换为薄金边圆角卡面，重新匹配字体、图标和间距。震动开关用居中的小轨道呈现，保留完整触控区域及现有开关逻辑。
- 用户补充资产位置 `C:/Users/Administrator/SpriteBonk-art-backup`。已找到 batch1 的商店、钱包及震动手机 PNG，以及独立 redflag、graygear 包。五张原图按字节复制至 `assets/menu/u2-art-*.png`，用 AtlasTexture 按 alpha 边界显示，未重采样原文件。tgz 中 `icon-redraw/current-icon-lab.png` 为玻璃药瓶，实验室接回仓库现有 `icon-lab.png`，左组全部采用已有 PNG。
- 前次将搜索范围局限于仓库和 v3 表，漏掉用户备份，已改用上述现成原图。角色素材工作未实际提交 ComfyUI job，保持暂存。
- 五张备份 PNG 均已逐字节核验与 ZIP 原件相同，实验室沿用仓库原 PNG 并按有效 alpha 区域显示。最终双档菜单 **120/0**，全程 `u2-native-full` 2340 **1481/3**、2400 **1571/3**，相对起点新增失败均为 0。最后仅调整药瓶透明区域后再跑菜单双档 **120/0**，重新实拍双档并目检。
- `compare/U2_left.png` 为用户指定左组局部对照，整屏双档对照同步更新。图形进程在保存及操作验证完成后仍有既有退出崩溃。一次中间截图出现场景预构建字典缺键，重拍最终两档无 SCRIPT ERROR，单独保留该中间日志，未把它计作通过。
- 当前备份 PNG 的立体高光与定稿平面图仍有可见差别，左组尚未报 1:1 关闭。Notion 连接器本轮已移除，证据先落仓库台账，待连接恢复回写。
