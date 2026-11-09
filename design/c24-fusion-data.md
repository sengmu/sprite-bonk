# C24 Bill 融合数据（2026-11-09）

结论：**PROVEN 静态数据就绪**。本批仅提取表与规则；无融合引擎、无 UI、无招式注册、无战斗调用。

依据完整读取 `c23-mining-pack.md` §4，及 `c23-mining-addendum.md` 的原料位置/哈希/字符偏移口径。补证单不新增融合规则。只读 main 镜像 SHA-256 为 `4b4a76ddd47d60167f4a330250cee58f036dc68d2efa692aaecd9638249d2d7e`，与补证单一致；不复制 bundle，不新增 reference 内容。

## 数据文件与约定

- `assets/data/fusions.json`：按实际 SC 顺序提取 **106 条**。每行 `id=50000+index`；79 signature 带 member 物种编号、现游戏数据中的 `member_key` 与双亲 moves；18 type、8 reaction（含完整双向类型集合）、1 glitch。保留西语原始 name/desc，不凭描述翻造战斗逻辑。
- 每行保留原始标量与数组（types、class、hits、range、status、preload 等存在时才保留），`raw` 留原始 cd/power、yC 覆盖值、原始 repeats；顶层 power/cd 为应用 yC、bC=.85、xC repeats 与 power>4 联合缩放后的值。`runtime` 是 US 的静态部分：dmg=17×最终 power、arch=fusion、area=5 等。未把 `hits` 当作实际命中数，也未把 range 的缺省值伪造为显式源表字段。
- `assets/data/fusion_rules.json`：父招最低8级；排除 weather/buff/fusion；签名→反应→同类型→glitch；就绪优先及 kind 排序；10项 mods 默认值及 RS 合并；结果1级、timer1.2、父链与槽位语义；伤害、冷却、联合归一化公式。Bill 每区一次仅记录为规则数据。
- 表没有接入 `GameData` 的招式/装备读取器，避免后续引擎尚未实现时出现可选择但不能施放的招式。JSON 属于游戏资源目录，Python 提取/核验脚本不属于运行时。

## pack 摘要与原文的计数差异

pack §4.4 报“82 signature”，但相同已核 SHA 的完整声明段 `var WS=` @1085512 至 `,CC=new Map` 前，经原始 WS/KS/YS/rC/lC/vC 展开得到 **79 signature +18 type +8 reaction +1 glitch =106**；yC 正好也有106键，与 SC 键集合一致。保留原文真实顺序与ID，**不补造3个签名，不把109条当成验收预期**。摘要中的额外3条在此原料中 **UNPROVEN**。

## 复现与证据

`python3 tools/extract_c24_fusions.py [--source /path/to/main.js]` 从只读原料生成表；先校验完整源哈希。仅在 Node 的隔离上下文求值声明/工厂对象，c 为原文字符串恒等函数；不调用任何 cast/sfx/effect。JSON 序列化明确丢弃函数。`--check` 对已提交 JSON 做完整源表一致性比较（不写文件）。源码方法不落游戏树。

核心位置：RS @1083580，zS @1083841，BS @1083906，US @1085174，SC 归一化循环 @1228059；基础 fusion.dmg=17 @753572。偏移为 UTF-8 解码后的 Unicode 字符，从0算。JSON 的 source 元数据由提取器动态定位，避免把 pack 的邻近锚点当成精确起点。

先建立数据契约检查，再生成数据：`Test/out/c24_fusion_red.log` rc1（fusions.json 缺失）。生成后 `Test/out/c24_fusion_final.log`：契约 PASS（106条），8个 mutation killed /0 missed；两份 JSON 的 SOURCE PARITY PASS。检查物种与 moves 都能解析到现游戏数据；mutation 覆盖漏行、ID错位、伤害错误、物种错误、reaction集合丢失、等级门槛错误、cd合并错误、结果timer错误。

命令：

```sh
python3 Test/c24_fusion_data.py
python3 tools/extract_c24_fusions.py --check
```

## 后续周期边界

82/109 的摘要计数差异已明确留案，其余本批静态行数据由同哈希原文复现。79 个 bespoke cast 与27个工厂/随机 cast 的执行体及其内部特效/逐段伤害参数**未移植**；未来执行引擎需另行提取/核对，不能宣称本表已包含完整战斗行为。所有动态施放、mods应用、父招遗忘、Bill交互、电影镜头和UI都没有施工。本批不建APK。
