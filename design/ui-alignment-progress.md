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

## 下一轮：U1（局内 HUD）——差异清单已列（2026-11-11 02:05）
现状取自 phonehud hudstart 实拍 Test/out/phone_hud_touch_2340x1080_s150_i0_hudstart.png，对照 design/ui-reference/v2/U1_final.jpg：
1. 顶栏配色：参考深色药丸，现奶油卡片（顶左＋顶中）——先查 ui-reskin-changes.md / UI_SPEC.md 确认 HUD 主题方向再动（奶油换皮是否只管菜单）。
2. 顶左簇：参考紧凑一体（头像＋等级徽＋血条）；现为大卡（名＋双属性签，血条分离在下方）。名字／头像占位种属属下一轮，不列入本次。
3. 顶中：缺「区域 1/4」「普通」签；右侧资源计数图标为空白方块（疑图标未加载），且只有 2 项（参考 3 项：萤尘／金币／宝箱）。
4. Boss 血条：本截图无 Boss，未比对——下一轮取 boss 态截图。
5. 小地图：现深黑绿、看不清地形；参考明亮地形图。击杀 pill 多 "+1" 后缀。
6. 左下技能栏：参考 5 格一排（4 锁＋1 叶 1级）；现仅左下角两枚小圆钮（星 1级 ＋ 锁），与摇杆挤在一起。
7. 右下按钮组：大招钮现为橙星（参考紫底「必」字）；布局近似，字形／配色差；右下角另有一 faint 圆圈（右摇杆？）参考无。
8. 观察项：菜单 Resources pill 长数字（累计 400908）疑超 pill 宽——U1 轮复核（测试档数字偏大，真机档再看）。
断点：差异清单已列完；未动代码；未跑批次。下一轮从第 1 项（主题方向确认）起工。
