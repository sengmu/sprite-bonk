# 图标第一单验收记录（主控 Muse，2026-11-12）

单据：Notion「SpriteBonk：接入新图标（一）应用图标、错误映射与 fallback」
`415858d4-06aa-81e1-a537-cfe47b5dcf34`（Due 2026-11-14）。
执行分支 `wip/icons-wire-a`（自对齐线 tip 76836a1 拉出；单据字面基线
b4226b2 已被对齐线超越，顺延口径已在单据 Note 注明）。

## 落地提交（wip/icons-wire-a）

- `afaef87` 素材落位：icon.png / store 三件（含新增 icon-1024 主图）覆盖、
  菜单 icon-wallet / icon-shop 覆盖、icon-league（红旗包）/ icon-settings
  （灰齿轮包）覆盖、icon-vibrate 只落文件；tiles ×4、glyphs ×7、vit_* ×12、
  coin-double.png。
- `50c7d2e` 接线：ui_badge 增 FULL_FILES（成品图整幅绘制）与 GLYPH_FILES
  （白单色字形 62% 叠色盘）两张覆盖表，先于 badge 文件路径咨询；五个错误
  别名（bag/sound/coin/banish/skip）自别名字典删除；结算四行改
  tile_clock/tile_sword/tile_star/tile_coin；维生素抽卡图标字典改 vit_* 键；
  ui_icon 新增 magnet 矢量字形（马蹄磁铁，消灭兜底圆环）。
- `.import` 提交（25 个侧车文件）：NUC 生成后回拉入库。**教训在案**：
  sync_to_nuc 默认 --delete，新素材的 .import 若不先回拉入库，下一次同步
  即被删，load() 返回 null、徽章静默空白——s100 证据截图当场抓到
  （结算四 tile 与金块卡曾整幅空白），补齐侧车后复跑才全绿。

## 验收（数字均为 NUC 实跑）

- import rc=0；三文件 parse 门 rc=0（world / ui_badge / ui_icon）。
- suite：首跑 651/2（c21 passive static + c22 lapras，均活夹具时序红），
  同树复跑 **651/0**——两红判定间歇性环境红，首跑记录保留在案。
- phonehud：2340 **1459/0**、2400 **1474/0**、s100 **1549/0**；
  bootsmoke rc=0；neutral rc=0。

## 截图证据（主控逐张亲检，s100 2400 捕获）

- 应用图标：PIL 验 512/512/1024 全不透明、新吉祥物满版 ✓（门户侧换图在
  提交准备期做）。
- 菜单四封面：钱包 ✓、商店遮阳棚 ✓、交叉红旗＋月桂 ✓、灰齿轮 ✓。
- 结算四行：秒表 tile / 橙剑 tile / 金星 tile / 双环金币 tile（非钱包）✓。
- 升级卡工具行：跳过＝双三角 ✓、放逐＝禁止符号 ✓（UiIcon 矢量原有正确）；
  维生素：金块卡实拍为 vit_nugget 成品图 ✓，其余 10 个代码映射＋文件在盘。
- fallback：clock 同 tile ✓；candy（出战配置成长糖筹码）✓、wind（实验室
  速度节点）✓ 实拍；bolt 代码接线（本夹具无电系招式上场，截图不可得，
  如实记录）；magnet 矢量字形已消兜底环（代码）；商店/档案无任何铃铛
  残留 ✓。
- 附带生效（设计内）：实验室 gold 节点显示双环金币 tile、archive 的 bag
  字形、skip/banish 字形均已经新表渲染；实验室正式映射与物品全量接线
  仍属第二单。

## 合并

验收通过后 `wip/icons-wire-a` 快进合并入 `align-fix13`（其分支点即
76836a1），经 NUC 推送并以 ls-remote 核验。
