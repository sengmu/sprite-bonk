# 定版 UI 落地记录 · 2026-11-10

基线：`9e8f613`（C24，suite 658/0）。目标：`design/art-concepts/ui-approved/INDEX.md` 及 U1–U6。

## 实现范围

UiTheme 共用奶油白面板、草绿主色、天蓝辅色、暖橙强调和深棕灰正文；面板改不透明，统一柔影、白色顶边、高圆角、胶囊底边厚度。UiBadge 用原有 UiIcon 绘制圆形光泽徽章，无生成文字，无新增外部素材。原字体链继续使用。

游戏数值与玩法逻辑零变更：没有修改成长、伤害、掉落、购买成本、资格条件、刷怪、计时、钱包 RPC、签名/交易能力等。实验室选择节点只保存界面选中项，升级继续调用原 `Profile.lab_buy`；菜单开始、结算再次出发复用既有配装入口，返回菜单继续复用重载入口。Ult 只修改 `display_name` 的显示语言，定义键、施放和计算保持原样。

法律资源来自仓库外 `spritebonk-site/worker.js`：替换网站模板常量、解码 HTML 实体、移除标签、按 `<hr>` 分开中英文，保留所有正文文字；来源与四份正文哈希见 `assets/legal/provenance.json`。`Test/check_legal.py --source ../spritebonk-site/worker.js` 对照源文件逐字检查。网站条款实际编号为第 7 节，保留编号；该节中英原文都包含政策 §10.6 的“非协议当事方”及“保护程度不低于政策 §§13/14”两条要求。内置普通 Resource 随 PCK 导出，阅读不需要联网。

## 逐屏目标 vs 实拍

截图沿用真实场景 `Test/uishot.gd` 的 `_snap`/帧等待方法（`Test/reskin_shot.tscn`），由 `Test/reskin_shots.sh` 生成，使用独立 XDG 数据目录。图中数据为截图夹具，不修改玩家存档。手机矩阵另由原 `Test/phonehud.tscn` 驱动全部场景。

| 项 | 变更 | 实拍（相对工程根目录） | 目标图 vs 实拍自评 |
| --- | --- | --- | --- |
| U1 HUD | 保留 D1–D7 的 HUD/安全区/触控结构；奶油面板、圆小地图边框、目标胶囊、手机双排圆技能槽；Boss 条由 70 高减至 46 高，固定顶部信息带下沿，必杀横幅不再把它向下推。逐个投影 Boss 可见 Mesh AABB；与条相交时仅将条透明，避免覆盖本体。 | `Test/out/ui_hud_reskin_release.png`、`ui_boss_reskin_release.png`；手机矩阵截图见验收日志 | 主题/圆形语言落地；仍是现有 3D 场景，非概念图生物与地形。保留既定顶部时间/区域卡，Boss 条位于它下方；极端近镜头情况下条会透明，位置不移动。桌面经典槽位保留结构并圆化；手机采用既有双排槽。 |
| U3 三选一 | 高圆角竖卡、大圆徽、标题/说明分层、重抽放工具行右端；保留稀有度、跳过、放逐、队伍、输入保护。 | `Test/out/ui_draft_reskin_release.png` | 没有给中卡增加推荐或默认获选语义；与目标的中心金色“推荐感”刻意不绑定。图标为现有代码图标，未替换为插画；说明为真实属性而非占位条。 |
| U4 实验室 | 左侧 4 列节点网格、背景连线、已购绿/未购灰、小锁，选中橙；右侧大圆徽、标题、三行等级/成本和橙升级钮。节点可滚动，物品档案保留。 | `Test/out/ui_lab_reskin_release.png`、`ui_labitems_reskin_final.png`（附加旧夹具截图，档案逻辑未改） | 原系统有 24 项且无前置依赖，故连线只作视觉组织，不新增科技树门槛；灰/锁表示尚未升级。节点数多于目标 3×3；保留所有真实升级项。 |
| U6 钱包 | 头像圆徽与地址胶囊在上，大余额/状态居中，连接（连接后断开）/复制地址/关闭三胶囊一行；失败与重试单层显示。 | `Test/out/ui_wallet_reskin_release.png` | 比目标背景更简；未连接时如实显示“尚未连接”，不展示虚构余额。地址错误和读取失败单独显示，不叠字。仍为手动公开地址只读连接。 |
| U2 主菜单 | 空白 Logo 位、左侧图标标签胶囊列、放大现有占位生物、橙色开始、右上双资源胶囊与“+”；初始伙伴收为小卡。 | `Test/out/ui_menu_reskin_release.png` | 不生成 Logo 文字；定版角色后补。现有游戏仅有星尘，没有宝石经济，因此双胶囊使用当前/累计星尘真实数据，不虚构第二货币。额外保留钱包、联盟、震动入口。 |
| U5 结算 | 三星装饰行、绿缎带标题、四行图标徽章+数字槽、绿再次出发/奶油返回菜单、边缘彩点；原详细统计继续滚动展示。 | `Test/out/ui_result_reskin_release.png` | 三星仅作装饰，不引入评分规则；真实失败/通关标题保留。吉祥物探头留空。手机沿用既定两栏容器，因此与目标中心单栏构图有差别。 |
| 内置法律 | 设置→账户→隐私政策与服务条款，应用内切换两份文档与两种语言；每份底部保留在线版。 | `Test/out/ui_legal_privacy_zh_reskin_release.png`、`ui_legal_privacy_en_reskin_release.png`、`ui_legal_terms_zh_reskin_release.png`、`ui_legal_terms_en_reskin_release.png`；条款末段另拍 `ui_legal_terms_zh_end_reskin_release.png`、`ui_legal_terms_en_end_reskin_release.png` | 已核对完整正文；末段实拍可直接看到第 7 节两条要求。文档按语言分开阅读，保留原文中的组织名称、协议/技术名词。 |

## 验收

施工中，最终结果以本节收尾更新为准。每次源码变更后重新同步，使用既有 `Test/sync_to_nuc.sh` 与 TREE PARITY。长跑使用 setsid，必须在会话内看到 `.done` 完结；不构建 APK。`reference/` 仍在忽略规则及导出排除项中。

- 法律源码逐字核对：4/4 通过，四份正文哈希已固定。
- 改动脚本逐个 `--check-only`：待最终批次记录。
- suite、bootsmoke、中立冒烟、phonehud 指定 a / s070_i0 / 2340x1080_s150 三档：待最终批次记录。
- 手机测试仅更新已批准的呈现契约：菜单小卡位置、实验室中文标签、等级中文标签、Boss 固定在必杀横幅上方；原可见性、相交、安全区、触控尺寸和按钮连线检查保留。

## 如实保留项

概念图的插画图标、精细材质/装饰、定版角色和 Logo 本地排字不在本批素材中；本批采用代码绘制与既有占位生物。无新宝石货币、无研究依赖门槛、无三星评分系统。Boss 在极端投影相交时透明避让属于当前呈现策略，需主控验收确认是否接受这一视觉差异。

## 修复轮 · 2026-11-10

范围仅为三项验收修复及 Boss 狂暴态补证，不改玩法数值，不改弱 phonehud 契约，不建 APK。

### 首轮红（保留）

NUC 原批次 `ALLDONE 2026-11-10T01:31:28+08:00`：suite rc=1，phonehud a / s070_i0 / 2340x1080_s150 各 rc=1；legal、bootsmoke、neutral rc=0。原始日志另存 `Test/out/reskin_suite_first_red.log`、`reskin_phonehud_{a,s070_i0,2340x1080_s150}_first_red.log`、`reskin_batch_first_red.done`，NUC 与本机均保留。回拉见 `reskin_first_red_pull.done`（5 文件、2596533 bytes）。

- suite：`C9 FAIL c21 boss: bar tag shows the rage state`。
- 三档 phonehud 均为同四条：P2 hidden items reachable、zone_en / species_en parity（缺 Rock Desert / Bulbasaur）；P5 result/dead 返回菜单中心 (892,647)。

### 修复

1. Boss：46 高悬顶条保留；狂怒标签放右端原有 128×22 槽，显示短标签“狂怒！”而不再把招式名挤入该槽；招式播报仍由既有横幅承载。狂怒切换同步刷新标签，逐帧 HUD 更新复用同一显示函数，避免状态切换后标签晚一帧。透明避让及 Boss 投影检测保留。
2. P2：暂停状态页从 `_hud_info_for()["en"]` 与 `ZONES[]["en"]` 恢复物种/地带英文名，与原中文同列显示；桌面完整名称和英文地带副标签也恢复数据串，手机紧凑 HUD 继续显示中文。中文状态信息保留。
3. P5：结算双钮行 `ALIGNMENT_END` 整体右锚，主操作“返回菜单”仍接原重载入口；不改检查阈值、契约或玩法。

### 补证与本轮验证

专用批次 `Test/reskin_fix_batch.sh`，独立 `reskin_fix_*` 日志和隔离数据目录；原红日志不覆盖。15 个 GDScript（含截图与法律夹具）逐个 `--check-only` 均 rc=0；同步 TREE PARITY OK（131 文件）。

法律：本机 `Test/out/reskin_fix_legal_source.log` 对照 `../spritebonk-site/worker.js` 四份正文逐字 4/4 通过。首个修复批次在 NUC 携带 `--source` 时因 NUC 无该仓库外文件而 rc=1，保留 `reskin_fix_legal.log`；NUC 已补跑无外部源参数的内置哈希/条款检查，`reskin_fix_legal_recheck.log` 4/4 通过。专用批次脚本已修正为 NUC 可复跑方式。

Boss 狂暴态实拍：`Test/out/ui_boss_rage_reskin_fix.png`，真实场景与 Boss 模型、夹具 HP=49%，调用真实狂怒入口；`reskin_fix_boss.log` 记录 `tag=狂怒！`、header=(410,102,460,46)、body_overlap=false、alpha=1。强制投影相交对照图 `ui_boss_guard_reskin_fix.png`，同一悬顶位置、alpha=0；独立断言验证位置不移动。截图供主控裁定透明避让策略。

已回拉验证的阶段结果（其余两档完成后补齐）：

| 检查 | 本轮结果 | 证据（`Test/out/`） |
| --- | --- | --- |
| GDScript 逐个解析 | 15/15，均 rc=0 | `reskin_fix_check_*.log`、`reskin_fix_batch.done` |
| suite | 658 checks / 0 fails，rc=0；原狂怒标签断言 PASS | `reskin_fix_suite.log` |
| phonehud a | 1635 checks / 0 fails，rc=0 | `reskin_fix_phonehud_a.log` |
| phonehud s070_i0 | 1626 checks / 0 fails，rc=0；主操作中心 (1366,647) | `reskin_fix_phonehud_s070_i0.log` |
| phonehud 2340x1080_s150 | 长跑中 | `reskin_fix_phonehud_2340x1080_s150.log` |
| legal | 本机对照源码 4/4；NUC 补跑 4/4 通过 | `reskin_fix_legal_source.log`、`reskin_fix_legal_recheck.log` |
| bootsmoke | rc=0，EXPORT_DONE rc=0，ALIVE_AT_75S，0 SCRIPT ERROR | `bootsmoke_ubantu.log`、`reskin_fix_bootsmoke_wrap.log` |
| neutral | rc=0，alive=1，script_errors=0 | `c23_neutral_smoke.log`、`c23_neutral_smoke.done` |
| Boss 补证 | 狂怒态无遮挡 + 相交透明避让断言通过，rc=0 | `reskin_fix_boss.log`、两张 `ui_boss_*_reskin_fix.png` |

P5 a 档主操作实测中心 **(1366,647)**（首轮为 (892,647)），原 `c.x > 0.6 * vp.x`、`c.y > 0.6 * vp.y` 检查 PASS。实拍 `Test/out/mobile_p5_result_2400x1080_s100_i0.png`，已目视确认双钮行右锚。本轮未修改 `Test/phonehud.gd` / `Test/harness.gd`。
