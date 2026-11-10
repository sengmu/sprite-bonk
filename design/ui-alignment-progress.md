# SpriteBonk 界面对齐台账（1:1 工程）

用户指令（2026-11-11 01:07）：各界面与效果图做 1:1，没 1:1 不要停；唯一豁免 = 3D 模型本体（还没做，占位保持，hero 形象差异不算未对齐）；缺插画素材找 Grok Bot 美术总监拿（经 Projects Manager 会话派单，先喂游戏简介）。

## 基线
- 仓库 main = d7ec090cb98a9eedad64f4571a2582070f274b7a（wiring-company 验收合并，2026-11-11）
- 参考：design/ui-reference/v2/（U1–U6 横屏定稿）、design/ui-reference/v3/（S07–S24 + A01–A18 图版 + INVENTORY.md）
- 验收口径：横屏 2340×1080 phonehud；每屏产出 design/ui-reference/compare/<屏>.png 并排图才算验收物

## 顺序（Notion 对齐单 414858d4 定版）
U1 → U3 → U5 → U4 → U6，然后 S07–S24 按号推进。

## 已知待办（开工前存量）
0. **菜单图块重叠缺陷**（验收遗留）：phonehud 2340 下 P5「menu pieces pairwise disjoint」红——TextureRect(530,390) × TextureRect(593,48) 相交。先定位是哪两个节点（给 clash 打印加节点名或写探针脚本），再修布局。修完 phonehud 2340 应为全绿。
1. U3 三选一卡面密度：接线轮实拍卡身偏空（布局密度差，非素材差）。
2. 非 p5（桌面）布局下 Resources 药丸丢了 sparkle UiBadge（合并 0cac8d1 本意保留）——小修，顺手补回。
3. 台账旧账：M5 换皮单里「2340 档长跑中」一行已过时（实为 1536/0 修复批），回写时一并纠正。

## 轮次记录
（每轮一行：屏 / 状态 / compare 图 / phonehud 数字 / 提交 SHA）
- U2 菜单：公司线已对齐（compare/U2.png 在库）；遗留上面的第 0 项重叠缺陷待修。
