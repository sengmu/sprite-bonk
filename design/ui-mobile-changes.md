# UI 手机适配施工记录（ui-mobile-changes）

规格：`design/ui-mobile-plan-v1.md` §B4 · 简报：`design/ui-impl-brief.md`（D1–D7）。
本文件是断点：每完成一项即更新。

---

## P1 — 语义修正 + 一次点击可达的去处（不改 HUD 几何）

### 0. 恢复记录（2026-10-28 13:12 起，恢复施工方）

前任施工方约 12:40 开工，约 13:09 被运行时重启杀掉，未留 changes 记录。以下为恢复盘点。

**基线**：前任在 `.tmp/p1_baseline/`（12:47:43）留了改前副本 —
`world.gd` sha256 `db0f8748…c3fd`（= C22 落地树，与 `Test/uip1_red.sh` 头注一致）、
`touch_controls.gd` `5f141dd6…`、`ult.gd` `4421cf14…`、`phonehud.gd` `6c430c47…`。
据此逐文件 diff：world.gd ±383 行、touch_controls.gd ±75、ult.gd ±3、phonehud.gd +490（只加不改）。
另有 `Test/uip1_red.sh`、`Test/uip1_batch.sh`（12:58）。

**NUC 现场**：
- 红基线已跑出（`Test/out/uip1_red4_*`，13:02–13:03，C22 游戏脚本 + 新断言）：
  phone `checks=636 fails=18`，18 条全部是 `P1:` 断言，原有断言 0 失败；
  desktop `fails=3`（`interact idle` / `ult gauge labelled` 两条触控结构断言 + `draft keeps kbd caps`
  因旧树无 `_draft_team_btn` 变量而 team=null——属预期）。→ 断言咬得住。
- 新树单变体已绿：`phonehud_touch_2400x1080_s070_i0_ubantu.log`（13:07）`checks=660 fails=0`，27 条 P1 全 PASS。
  但 `phonehud.gd` 13:08 又改过一次（加了 `_p1_paid_chest`），该断言从未执行过。
- 13:09 起的 `uip1_batch.sh`（purge → import → 矩阵 → suite）卡死在 `--headless --import`：
  引擎错误循环（`list.h:229 erase` + `Object was deleted while awaiting a callback`），
  日志涨到 25 GB。恢复方 13:15 已杀进程，日志截为 `Test/out/uip1_import_runaway_excerpt.log`（6 KB，保留头尾）。
  推测诱因：13:04 起另有一次矩阵运行与 batch 的 `rm -rf .godot` 重叠（Test/out 下 13:04–13:05 的 `.png.import` 即其产物）。

**逐项判定**

| 项 | 判定 | 位置 |
|---|---|---|
| P1.1 触控文案 `_ik()` / `_ik_ult()` | 完成 | `world.gd:5342`, `:5347`；ult.gd:173 |
| P1.1 banner 三处（阿尔法/野生/闪光守护者） | 完成 | `world.gd:5457`, `:5496`, `:5697` |
| P1.1 `_prop_label` 13 条 | 完成（`_prop_label_kbd` + `.replace("按 E", _ik())`） | `world.gd:8844-8847` |
| P1.1 投球 / 祭坛 prompt | 完成 | `world.gd:11969`, `:11974` |
| P1.1 祭坛 Label3D / 主菜单 hint / kbd 角标 / [Tab] / 设置「操作」页 — 触控翻转时重设 | 完成（`_touch_text_sync` 每帧，仅在 `_touch_wanted()` 翻转时动作） | `world.gd:5322`, `:11611`, `:4371-4383`, `:13649` |
| P1.2 互动键三态 | 完成 | `touch_controls.gd:383-407`（含按下/抬起基准 `:345`）；world 推送 `world.gd:11960-12026` |
| P1.3 大招盘「必」+ medal + `set_ult_state(deny: float)` | 完成 | `touch_controls.gd:119-130`, `:375`, `:446`；`world.gd:3376-3380`, `:11272` |
| P1.4 banner 队列 + 模态冻结 | 完成 | `world.gd:5292-5313`, `:11699-11712` |
| P1.5 暂停「状态」页 6 块 + `_pw_defs` 同源 | 完成 | `world.gd:13390`, `:13515-13613`, `:13896` |
| P1.5 设置快捷行（镜头辅助/固定摇杆/大招自动/按钮大小）+「全部设置」 | 完成 | `world.gd:13426-13433`, `:13489` |
| P1.5 回主菜单两段确认（3 s，开/关暂停时解除） | 完成 | `world.gd:13451-13475`, `:13678`, `:13688` |
| 附加：双拇指转视角（ScreenDrag + 独立 touch id） | 完成 + harness 双触模拟实证 | `world.gd:11565-11593`, `:11495-11501`, `:11603`；`touch_controls.gd:464` |
| 门断言（phone + desktop 取反） | 完成；`paid chest` 一条未执行过 | `Test/phonehud.gd:657-1118` |
| 抓图 | 只出过 2400×1080 s1.00 i0 一组（红跑），新树未出 | — |
| 全矩阵 / 全量 suite / bootsmoke / 拉回 | **未完成**（batch 卡死） | — |

**结论**：实现项全部在位，无损坏项；剩下的是验证仪式（矩阵、suite、抓图、拉回）和本报告。

### 1. 验证进度

- 13:17 恢复方小改：`world.gd:5342` 前移回 `_ik()` 的文档注释（前任误挂在 `_touch_text_sync` 头上；纯注释，行数不变）。
- 13:17 `Test/uip1_batch.sh` 加固：有其他 Godot 进程在跑则拒绝开工；import 套 `timeout 900` + 日志上限 20 MB；无 class cache 即中止；补跑 `check_class_cache.sh`。
- 13:18 `sync_to_nuc.sh`：SYNC OK，TREE PARITY OK（88 files，0 diffs）。
- 13:19 batch 在 NUC 以 setsid 后台启动（purge → import → class cache → 全矩阵 → 全量 suite → bootsmoke）。
- 13:20 import rc=0（日志 202 B，正常）；class cache 门 rc=0（GATE OK）。
- 13:22 矩阵首个变体 2400×1080 s0.70 i0：`checks=661 fails=0`；`P1: paid chest prompt uses the touch verb` 首次执行即 PASS（"精灵球 · 点互动 开启（18 金币）…"）。
- 13:44 观察：2400×1080 s1.00 i0,0,48,0 变体 `DONE checks=637 fails=0` 后进程未退出（日志末尾 `=====` 分隔线 = Godot 崩溃处理器在退出时触发），挂到 `timeout 900`。同一签名在 C21.3.2 的 `c2132_phonehud_touch_1920x1080_s100_i0_0_48_0_ubantu.log`（P1 前的树）里已有 → **既有的退出期崩溃，非 P1 引入**；门判定看 `DONE … fails=0`，不受影响，只多耗墙钟。
- 14:39 全矩阵 `matrix rc=1`：**36/36 phone 变体 OK**；desktop 1280×720 `checks=645 fails=1` —
  `P1 desktop: altar 3D label keeps the keyboard verb :: Boss 祭坛 · 点互动 召唤守护者`。
  诊断（harness 问题，非游戏缺陷）：① 释放触控锁后只等了 `_frames(6)`（**物理**帧），慢渲染下数个物理帧落在同一次主循环里，
  `_touch_text_sync`（在 `World._process`）一次都没跑就读了 Label；同一 run 里经 `_ik()` 直出的 alpha banner 已正确回到「按 E」。
  ② desktop 块里的 chest / meowth 取反断言**静默跳过**（日志无这两行：到收尾时 `_prop_of_kind` 已取不到未用道具）——
  规划要求的桌面取反实际没执行。
  修复（`Test/phonehud.gd`）：新增 `_p1_latch(on)`（设 `_touch_forced` 后等 8 个 **process** 帧）与 `_p1_desktop_prompt(st)`；
  桌面取反改为在各自保留状态**就地**做（释放锁 → 读 → 恢复锁）：chest 走付费行（`_p1_paid_chest`，金币不足行无动词咬不住）、
  meowth（商店模态前）、altar prompt + 3D Label；收尾块只留 alpha / draft / 键位 tab。断言条件本身未放宽。
- 14:57 batch ALLDONE：全量 suite 第 1 遍 `C9 SUMMARY checks=514 fails=2`（C22 基线 514/1，其单红每遍不同）；bootsmoke `EXPORT_DONE rc=0`、`BOOTSMOKE ALIVE_AT_75S`。
  两红判定（均为 C21 passive 夹具，P1 diff 未碰 tick / passive / player.gd）：
  - `c21 passive tentacles: both neighbours were whipped`（hp 1036600/1036600）：C21DBG 显示窗口末 `pid=photosynthesis`、`ptick={}`——
    被测 passive 在窗口中被**改回物种默认**（`passive_id` 唯一写入点 `player.gd:222` 物种初始化；该文件 P1 未改，mtime 10:22）。
    上游 post-takeover 记录 `switch_pending=2`：takeover 夹具遗留的队伍切换在窗口内落地 = C21.3 RIDER 已记录的 takeover 夹具时序问题。
  - `c21 passive static: discharge hits the nearest`：单目标 5 s 周期，窗口末 `ptick` 39.15 > rt 36.48，场上拥挤（near7=12，C22 两遍为 2/4）——C21.1 已记录的同类 flake。
  处置：照 C22 惯例跑第 2 遍（见下）。
- 15:00 同步终版树（harness 修复 + `Test/uip1_rerun.sh`）：TREE PARITY OK（89 files）。
- 15:02 `uip1_rerun.sh` 启动：终版门文件全矩阵 + suite 第 2 遍（日志前缀 `uip1r2_`）。
- 15:05 `pull_from_nuc.sh uip1 'uip1_*.log' 'uip1_*.done'`：PULL OK 59 files / 3,746,349 bytes，已校验。
- 15:02 启动的 `uip1_rerun.sh`（终版门文件全矩阵 + suite 第 2 遍）于其后在 NUC 跑完（施工方本体 15:27 被额度切断，批处理独立完成）：全矩阵各变体 `PHONEHUD DONE … fails=0`、**suite 第 2 遍 `C9 SUMMARY checks=514 fails=0` 全绿**。
- 17:1x 主控拉回 `uip1r2_*`：PULL OK 39 files / 3,022,965 bytes，已校验。

### P1 关期（主控验收，2026-10-28 17:1x）

**P1 通过，正式关闭。** 依据：实现项全在位（恢复盘点逐项 file:line）；新断言在 C22 基线树上先红（phone 18 条 P1 断言全红、原有断言 0 红）后绿；终版门文件全矩阵 fails=0；全量 suite 两遍 = 514/2（两红均为 C21 被动夹具时序问题、P1 未碰相关代码，分诊有据）→ **514/0**；bootsmoke ALIVE_AT_75S。遗留说明：桌面取反断言的 harness 修复（process 帧 latch）属测试侧加固，断言条件未放宽；引擎退出期卡死为既有现象，只耗墙钟。下一期 P2 在本树上继续。

---

## P2 — 顶带去冗余 + 重新取回缩放（Z1/Z2/Z3 几何）

### R. 恢复盘点（2026-10-28 恢复施工方；前任约 17:28 被运行时重启杀掉）

**现场**：`scripts/*.gd` 与 `.tmp/p2_baseline/` 逐文件 sha256 一致（world `685e5f47…`、touch_controls `f44c2877…`、ui_icon `7fd1475c…`）→ **游戏代码零改动**。
`check_phonehud.sh` 未改。改动只有：`Test/phonehud.gd`（17:23，+380 行，只加不改：P2 段 + 5 个挂点）与新文件 `Test/uip2_red.sh`（17:23，红基线脚本，未执行过——NUC 上无 `uip2_*` 产物待下面核实）。

**phonehud.gd P2 断言逐条判定**（引用的 world 符号逐个 grep 过：除下表「待实现」列出的 3 个外全部存在）

| 断言 / 部件 | 判定 | 处置 |
|---|---|---|
| 挂点：`_assert_state` 尾 → `_p2_state` / `_p2_desktop_state`；暂停态 → `_p2_parity`；P1 段后 → `_p2_phone_block` / `_p2_desktop_block`；4 处 `_p2_snap` | 完整 | 保留 |
| `P2: s_t floor` | **有缺陷**：规划阈值「vw ≥ 1500 → ≥ 1.40」与规划自己的 §B2 公式矛盾——矩阵里 2340×1080 + 左 48 inset（vw 1512）按公式 s_t = 1.372，断言必红且不是实现能修的 | 修：1.40 档起点改为公式过 1.40 的 vw 1537（默认 hud/小地图缩放），并**新增 `P2: s_t formula`**——每个变体都钉死 s_t = min(s, 1.45, fit)，比原阈值更严；非默认 hudScale/minimapScale 时只跑公式断言 |
| `P2: glance text size`（Z1+Z2 可见 Label，D7：20:9 线 ≥19、16:9 线 ≥17） | 完整 | 保留。范围说明（goal/pill/BL/boss 属 P3/P4，低于下限的只打 INFO）合理 |
| `P2: kills pill text >= 18` | 完整 | 保留 |
| `P2: must-glance numerals`（24 / HP 20；16:9 线按 17/19 等比放宽） | 完整 | 保留；16:9 等比放宽是对 D7 的解读，记为偏差待主控确认 |
| `P2: collapsed top-band items hidden`（pw_row / zone_en / elapsed / 区域片 / 档位片 / 星尘） | 完整 | 保留（档位片无 world 引用时按文字找，实现会补 `_tier_chip`） |
| `P2: hero name is Chinese only` / `party row only with allies` / `hero cluster box = 340 x HP/party bottom`（110 / 158） | 完整 | 保留；158 = 队友行下移到 y114（HP 轨道 20 高后底在 110，间距 4） |
| `P2: top card design width 560` / `HP track 20 tall` / `danger segments 13x14` | 完整 | 保留 |
| `P2: minimap at s_mm`（框、图、击杀片） | 完整 | 保留 |
| `P2: minimap expand badge …` | 完整，**依赖待实现** `_mm_expand` | 保留 |
| `P2: top card rides s_t`（触控列侵入卡带时改打 INFO） | 完整 | 保留；与实现约定：ts 1.50 时暂停键（顶 y≈42）进卡带，卡按列左缘收缩 |
| `P2: centre clear` | 完整 | 保留（BL 簇属 P4，只 INFO） |
| `P2 desktop: top band unchanged` | 完整但偏弱 | 加强：再钉 HP 轨道 15 高、危险段 10 高、无「⤢」角标 |
| `P2: hidden items reachable` + `P2: parity <k>`（zone_en / elapsed / dust / 第 n/4 区 / 难度 / 物种英文名 / 进化行 / 天气 / 6 个战力片） | 完整 | 保留。物种英文名（H4）、进化行（H6）、天气是 P2 新去处，状态页尚无 → 红基线必红，由实现补 |
| `P2: weather chip tap explains the weather` / `hit area >= 70` / `tap does not start the stick` | 完整，**依赖待实现** `_wx_hit` | 保留。注意：天气片在摇杆区（左 52%，STOP）下方，命中区必须挂在触控层、排在摇杆区之后 |
| `P2: stat change toast (伤害 ↑ / ↓)`、`P2 desktop: no stat toast` | 完整 | 保留 |
| `P2: evo line only within 3 levels`、`P2: party row shows with an ally` | 完整 | 保留 |
| `_p2_snap`（两个规划组合出 4 态；2400/1920 × ts 0.70/1.50 角点出 hud_start + boss） | 完整 | 保留 |
| `Test/uip2_red.sh`（拒绝并发 Godot、单跑 900 s、日志 20 MB 上限；2 个规划组合 + desktop） | 完整 | 保留 |

**待实现符号**：`_mm_expand`、`_wx_hit`、`_tier_chip`（可选）。无损坏、无需丢弃的断言。

### 0. 开工（2026-10-28 17:20，施工方）

**基线**：P1 关期树（静止：`scripts/*.gd` 最新 mtime = world.gd 13:17，Test/phonehud.gd 14:42）。改前副本 `.tmp/p2_baseline/`：
world.gd `685e5f47…6d96f`、touch_controls.gd `f44c2877…b4`、ui_icon.gd `7fd1475c…6ec`、phonehud.gd `e07abec1…c6ec`、check_phonehud.sh `582f2c2f…953`。NUC 空闲（无 Godot 进程）。

**范围判定（照规划 §B4 P2 + §B1 阶段列）**：
- 手机分支隐藏 pw_row / zone_en / 跑表 / 区域片(T4) / 档位片(T5) / 钱包星尘；H4 名字只留中文（EN 入状态页）；H6 距进化 ≤3 级才显示；H8 无队友隐藏。
- D3 的倍率变化 toast 属本期（规划 P2 第 4 条），复用 P1 队列。
- T6 天气片点按 1.5 s 说明（§B1 T6 = P2，§B3 I1/I2）。
- 顶卡手机内容版 560×84（§B4 P2 卡内坐标）、`_layout_hud` 手机分支 s_t / s_mm 公式、小地图“⤢”角标、HP 轨道 20 高 / 数字 14。
- **D6「经典布局」开关：规划 §B4 没有把它分到任何一期**（只在 §B5 P4 作为 P3/P4 肌肉记忆风险的缓解手段被引用，§B6 D6 写明经典布局 = 21.3.2 几何、gate 只跑 2400 s1.00 一个角点）。按委托“规划未分到本期则不提前做”，**P2 不建**；记为待主控分期的缺口（建议随 P3——肌肉记忆变化真正发生的那一期——落地）。

### 1. 进度（恢复施工方）

- 17:2x STEP 0 盘点完成（见 §R）。phonehud.gd 修补：`P2: s_t floor` 1.40 档起点 1500 → 1537 + 新增 `P2: s_t formula`；desktop 不变断言加 HP 轨道 15 / 段高 10 / 无角标。
- 17:3x **发现并修复加固脚本自身的 bug**：前任 17:24 的红基线**根本没跑**——`uip2_red.done` = `ABORT: another Godot process is running`，命中的「Godot 进程」是发起它的 ssh 会话本身（启动命令里含同一字符串，`pgrep -f` 未锚定）。`uip2_red.sh` 守卫改为只匹配 argv0（`^[^ ]*/Godot_v4\.3-stable_linux`）。P1 的 uip1_* 脚本有同样的潜在缺陷（当时启动命令恰好不含该串，未触发）。
- 17:32 `sync_to_nuc.sh`：SYNC OK，TREE PARITY OK（90 files，0 diffs）；NUC world.gd = `685e5f47…`（P1 树），phonehud.gd `b89df1bb…`。红基线 `uip2_red.sh red` 已 setsid 启动（2400 s1.00 i0 / 1920 s1.50 i48 / desktop）。
- 17:4x **红基线**（P1 树 world `685e5f47…` + 补全后的门文件，`Test/out/uip2_red_*`）：
  - phone 2400×1080 s1.00 i0：`checks=731 fails=81`；phone 1920×1080 s1.50 i48：`checks=726 fails=76`；**两者非 P2 失败 = 0**（kept + P1 断言全过）。
  - 红的 P2 断言（每个 live 态 ×5）：s_t floor（仅 a；b 的 vw 1232 < 1270 无下限档）/ s_t formula / glance text / kills ≥18 / numerals / collapsed hidden / 中文名 / 队友行 / hero 框 / 卡宽 560 / HP 轨道 20 / 危险段 13×14 / 小地图 s_mm / ⤢ 角标；单次：parity species_en / evo / weather + hidden items reachable、天气点按 3 条、stat toast ↑↓、evo ≤3 级、带队友队友行。→ **全部咬得住**。
  - 旧树上本就为绿的 P2 断言（预期，属守护型）：centre clear、top card rides s_t（旧树卡与 hero 同缩放）、parity dust / elapsed / zone_en（P1 已建去处）。
  - desktop 1280×720：`checks=654 fails=0`（P2 desktop 不变断言 + no stat toast 在旧树上即绿，属不变量守护）。
- 17:4x 实现首版落地（逐项 file:line 见 §2 报告）。迭代跑 `it1` 卡住：world.gd 一处类型推断 parse error（`var down :=` 推不出类型）→ 场景脚本加载失败、harness 中断后 Godot 空转到 900 s timeout（日志因管道块缓冲为 0 字节，看不出原因）。已杀掉（只杀本次 run），改 `var down: bool`；NUC 上 `--check-only` 逐个过：world / touch_controls / ui_icon / phonehud 全 rc=0。教训：批处理前先 `--check-only`（已加进 `uip2_batch.sh`）。
- 18:0x 迭代 `it2`（2400 s1.00 i0 / 1920 s1.50 i48 / desktop）：a `731/1`、b `681/11`、desktop `654/0`。
  - a/b 的 `P2: stat change toast (伤害 ↑)`：**harness 时序缺陷**——↑ toast 已发出（同 run 的 ↓ 行显示 ×1.13→×1.03），但 harness 在固定 30 帧后单次采样，NUC 软件 GL 下 30 帧 ≈ 1.5 s = toast 时长，采到时已过期。改为 `_p2_watch_banner`：逐 process 帧盯 banner 通道（当前 + 队列）至多 120 帧，见到即判。条件未放宽；desktop 的「无 toast」取反同样改为整窗口盯，**比原单次采样更严**（原写法会放过两次采样之间一闪而过的 toast）。
  - b 的 10 条 kept 红（每个 live 态 ×2）：`tc_ult x goal disjoint` + `info stack bottom <= ult top - 4`（goal 底 369 vs 大招盘顶 348）。**真实几何冲突，由 P2 引起**：右列按规划改骑 s_mm = 1.30 后，16:9 上小地图 162 → 229，ts 1.50 时 goal 卡即使 F1c 三级裁剪后只剩表头（63 设计 × 1.30）也越过 Z。修：`_apply_stack_budget` 加第 4 级——goal 卡（及其下 pill 盒）按剩余高度缩放（下限 0.5），小地图 / 击杀片保持 s_mm。规划 Z3 的正解「目标 pill 折进击杀片 +N」属 P3，届时替换此级。
- 18:1x 同步 + `--check-only` 全 rc=0；`Test/uip2_iter.sh it3`（6 个角点：1920 s1.50 i48、2400 s1.50 i0、2340 s0.70 右 48、1920 s0.85 i0、2400 s1.00 i0、desktop）启动。
- 18:3x `it3` 6 角点全绿：2400 s1.00 i0 `731/0`、1920 s1.50 i48 `681/0`、2400 s1.50 i0 `681/0`、2340 s0.70 右48 `731/0`、1920 s0.85 i0 `731/0`、desktop `654/0`。
- 18:3x 看图（it2/it3 抓图）发现 2 处门看不到的视觉缺陷，已修：① 危险名（「致命」「残暴」）被七段压住——规划框 (170,48,220,14) 在字号抬到下限后放不下，框改为 (170,41,220,20)（同一中心列，上移进计时器下方空白）；② 第 4 级裁剪缩小 goal 卡后「+N」徽仍按列缩放、盖住 goal 名尾——裁剪后按 goal 缩放重放徽。
- 18:23 终版树同步（TREE PARITY OK，92 files；world `b95354db…`、touch_controls `79128d71…`、ui_icon `2daf8a91…`、phonehud `37153267…`，VM = NUC）→ `Test/uip2_batch.sh` setsid 启动：parse 门 4/4 rc=0 → `rm -rf .godot` → import rc=0（日志 202 B）→ class cache GATE OK → 全矩阵 → 全量 suite → bootsmoke。

### 2. P2 实现清单（终版树 file:line）

| 规划项 | 实现 | 位置 |
|---|---|---|
| 新引用 + 状态位（HP 轨道、区域/档位/天气片、钱包片与三图标、⤢、天气命中区、`_p2_on`、字号签名、`_pw_last`） | 加 | `scripts/world.gd:390-408`；赋值 `:2813`, `:2869-2875`, `:2916-2933` |
| R1 小地图「⤢」角标（12 设计 px，帧右下内角，圆盘外、仍在小地图点按矩形内） | 加；图标 `expand` | `world.gd:3033-3044`；`scripts/ui_icon.gd:240` |
| T6 天气片点按 → 1.5 s 说明（天气名 + 属性伤害修正，经 `weather_damage_mul` 同源）；命中区 ≥ 70，挂在触控层、排在摇杆区之后（天气片在摇杆区下方，否则点按会起摇杆） | 加 | 命中区 `world.gd:3364-3373`；放置 `_p2_place_wx_hit` `:12909`；点按 `_on_wx_hit_input` `:12939`（触摸 + 模拟鼠标去重 300 ms）；文案 `_weather_explain` `:12956`；片内图标 + 单字 `:11524` |
| H4 名字只留中文（EN 进状态页） | 改 | `_apply_starter_hud` `world.gd:3416-3419`；翻转时 `_apply_top_card_phone` |
| §B4 P2 顶卡手机内容版 560×84（卡内坐标照规划；危险名框见偏差 3） + HP 轨道 20 高 / 数字 14 + 队友行 y114 | `_apply_top_card_phone(on)`：只在翻转时动作，桌面恢复建时坐标（首调时记入 meta） | `world.gd:12767-12834` |
| 隐藏 pw_row / zone_en / 跑表 / 区域片 T4 / 档位片 T5 / 星尘（图标 + 数） | 同上 | 同上 |
| §B2 s_t / s_mm 公式；hero 设计宽 340；卡以 560 计、`band_r` 仍以 326；卡居中于 [band_r, 右界]，右界 = 小地图左 − 12，若暂停/镜头/锁定列升进卡带（ts 1.50）则 = 列左 − 12，卡缩放 = min(s_t, 可用宽/560)；右列（小地图→击杀→goal→pill）骑 s_mm；中央栈起点 = 卡底；pw_r 只在 pw_row 可见时计入 | `_layout_hud` 手机分支；桌面路径数值不变 | `world.gd:12571-12666`, `:12679`, `:12696`, `:12755`；`touch_controls.gd:192` `column_top()` |
| 字号下限（B0.5 + D7） | `_p2_fit_fonts`：各 Label 取规划手机字号，仅当「字号 × 节点缩放」低于下限时抬到下限（见偏差 2）；签名门控（P11） | `world.gd:12836-12893` |
| Z1 hero 框 340 × 110（有队友 158） | `_p2_hero_box` | `world.gd:12898` |
| H6 进化行 ≤ 3 级才显示；H8 无队友隐藏队友行 | `_p2_hud_tick`（0.15 s HUD tick） | `world.gd:12927`；挂点 `:11510` |
| D3 / H9 倍率变化 toast（1.5 s，「伤害 ×1.10 ↑」，多项合并一条；首次填充只记基线；仅手机） | `_pw_change_toast` | `world.gd:14222`；挂点 `:14211` |
| 状态页新去处：「精灵：中文 EN · 进化行」、「天气：… · 修正」 | `_pause_fill_status` 本局块 | `world.gd:13921-13929` |
| F1c 栈预算第 4 级（见偏差 4） | `_apply_stack_budget` | `world.gd:13248-13263` |
| 门 | phonehud P2 段 | `Test/phonehud.gd:1160-1566`；挂点 `:284,290,303,349,355,372,375,646` |

### 3. 与规划的偏差及理由（待主控裁定的标 ★）

1. ★ **`P2: s_t floor` 1.40 档起点 1500 → 1537**。规划 §B4 的门阈值与它自己的 §B2 公式矛盾：矩阵里 2340×1080 + 左 48 inset 的 vw = 1512，公式给 s_t = 1.372（规划表里没有这一行；2400+48 inset = 1552 → 1.417 与表一致）。1537 = 公式在默认 hud/小地图缩放下过 1.40 的 vw。补偿：新增 `P2: s_t formula`，每个变体把 s_t 钉死在 min(s, 1.45, fit)，±0.002——比原阈值更严。
2. ★ **字号「按缩放兜底」而不是固定字号**。规划 P2 写死的手机字号与它自己的 `glance text size` 门不相容：Lv 徽 12、属性片 12、危险名 13 在 s_t 1.45 下画出 17.4 / 17.4 / 18.85 < 19；16:9 线（s_t 1.06–1.115）和 ts 1.50 时卡按触控列收缩（0.88–0.92）更低。`_p2_fit_fonts` 让每个 Label 取规划字号，只在「字号 × 节点缩放」低于下限时抬到下限。2400 s1.00 实际变化只有：Lv 12→14、属性片 12→14、危险名 13→14（其余照规划）。D7 解读：16:9 线下限 17；必扫数字 24 / HP 20 按同一比例 17/19 放宽到 21.5 / 17.9（门与实现同口径）——若主控认为 16:9 也要 24/20，需要另定 16:9 顶卡方案（规划风险 P8）。
3. **危险名框 (170,48,220,14) → (170,41,220,20)**：字号抬到下限后居中字形压进 y64 的七段（抓图实证），框上移进计时器下方空白，中心列不变。
4. **F1c 栈预算加第 4 级（goal 卡 + pill 盒缩放到剩余高度，下限 0.5）**：右列按规划改骑 s_mm 1.30 后，ts 1.50 时（任何宽度）小地图 229 高，goal 卡即使裁到只剩表头也越过 Z（实测 goal 底 369 vs 大招盘顶 348，kept 断言 `tc_ult x goal` / `info stack bottom` 红）。小地图 / 击杀片保持 s_mm（P2 门照测）。规划 Z3 的正解（目标 pill 折进击杀片「+N」）属 P3，届时替换。此时 goal 卡字小，但 goal 卡本就在 P3 重建范围、glance 门对它只打 INFO。
5. **ts 1.50 时顶卡缩放 < s_t**：暂停键在 ts 1.50 时顶 y≈42，升进卡带，卡按「列左 − 12」收缩（实测 2400 = 1.351 vs s_t 1.45；1920+48 inset = 0.920 vs 1.061）。暂停键移出拇指簇是 P3（D1）；P3 之后此分支不再触发。门在这种变体里把 `top card rides s_t` 换成 INFO（门文件前任已如此设计），字号门照测（字号兜底已覆盖）。
6. **天气片手机上显示图标 + 首字**（「烈日」→「烈」、「灰烬雨」→「灰」）——照 T6「图标 + 单字」；全名 + 修正在点按说明和状态页。**状态页加了天气行**（规划没把天气列为收起项，但片上只剩一个字，全名需要一个常驻去处；parity 门照测）。
7. **钱包片宽 156**（照 §B4 P2 卡内坐标 (392,24,156,36)；§B1 T11 写「片宽 180」，两处不一致，取更具体的 §B4）。
8. **「⤢」用矢量图标**（UiIcon 新增 `expand`），不用字体字符——CJK 字体对 U+2922 无覆盖保证。
9. **天气点按命中区挂在触控层**（摇杆区之后的兄弟节点）：天气片位于摇杆区（左 52%，STOP）下方，挂在 HUD 里永远收不到触点。门有 `tap does not start the stick` 断言。桌面无触控层 → 无点按（I1 只约束手机）。
10. 未做，记为后续：**I3 按下反馈（a+0.25）** 本期只有天气片一个新可点元素且命中区透明，未加；P3 加头像 / 目标 pill 两个可点件时统一实现。**B0.7 / 风险 P7 的 hudScale {0.80,1.30} × minimapScale {0.75,1.50} 角点**未加进常设矩阵（规划没分到具体一期；P2 的 s_mm 改动正是 P7 防的风险，建议主控决定是否在 P3 前补；门已支持：s_t floor 在非默认缩放下自动只跑公式断言，但 harness 还没有 `--hud=` / `--mm=` 参数）。
11. **D6 经典布局**：按主控裁定随 P3，本期未建。
12. 测试侧（不放宽条件）：`_p2_watch_banner` 逐帧盯 toast（见 §1 18:0x）；加固脚本的 pgrep 自匹配修复（见 §1 17:3x）。
- 18:5x 矩阵进行中：前 6 个变体 OK；**2400×1080 s1.00 i0 `checks=731 fails=1`**——唯一红是 P1 断言 `two-thumb camera rotates while the stick is held`（`joy=true/false mv=(0,0) dyaw=0`：摇杆先激活、第二指拖动期间被释放，且镜头完全没转）。同一变体在 it3 全绿；该断言 P1 两轮矩阵 72/72 PASS；P2 diff 未碰摇杆 / 镜头 / 输入路由（唯一新输入件 `_wx_hit` 位于顶带 (655–742, 52–122)，与摇杆 home 和 cp=(992,446) 都不相交）。「摇杆被放 + 镜头零转动」同时出现 = 触控层在窗口内被隐藏（模态打开）的签名——疑似 P1 块把阿尔法收为队友后其击杀给经验触发升级选卡。**未下结论**：batch 跑完后单独重跑该变体取证（不与 batch 并发）。
- 20:54 batch ALLDONE：matrix rc=1（36 OK / 1 FAIL = 上述变体）、suite rc=1、bootsmoke rc=0。主控拉回 `uip2_*`（62 files，已校验）：suite = `C9 SUMMARY checks=514 fails=1`，唯一红 `guardian: chest exists to open` —— 与 C22 审计 F3 同一夹具竞态（P2 未碰守护/宝箱代码；F3 的诊断打印 + harness 处置已在主控残留批队列）。
- 22:4x 主控单独复跑该变体（NUC，`uip2_solo_thumb_ubantu.log`，已拉回校验）：**`PHONEHUD DONE checks=731 fails=0`，two-thumb PASS（joy=true/true、dyaw=-0.6）**。判定：batch 中那次为测试窗口内模态干扰的一次性夹具事件（失败签名 joy=true/false = 拖动中摇杆被释放，与单跑 true/true 对照成立），非 P2/P1 回归。P2 矩阵按「36/37 + 失败变体单跑 731/0」结案。

### P2 关期（主控验收，2026-10-28 22:5x）

**P2 通过，正式关闭。** 依据：实现清单全项落地（§2 file:line）；红基线 phone 731/81 + 726/76（红全为 P2 断言、旧断言零误伤）、desktop 654/0；迭代 6 角点全绿；终版全矩阵 36/37 + 失败变体单跑 731/0（夹具事件，见上）；全量 suite 514/1（唯一红 = C22 审计 F3 既有夹具竞态）；bootsmoke rc=0；抓图复查修掉 2 处视觉缺陷（危险名压段、徽盖字）。

**主控裁定（§3 ★ 项）**：
- 偏差 1（s_t floor 起点 1500→1537 + 新增 s_t formula 钉死断言）：**批准**。规划阈值与其自身公式矛盾，修正后断言更严，非放宽。
- 偏差 2（字号按规划值 + 低于下限才抬；16:9 必扫数字按 D7 比例放宽至 21.5/17.9）：**批准**。规划写死字号过不了其自身 glance 门；16:9 比例放宽与 D7「二线、下限 17」口径一致。若日后要 16:9 也上 24/20，须另立 16:9 顶卡方案（规划风险 P8），不在本程序内。
- 其余偏差 3–12 照记录执行，其中：F1c 第 4 级栈裁剪为临时措施，P3 的目标 pill（D4）落地时替换；I3 按下反馈与 hudScale/minimapScale 角点矩阵（偏差 10）并入 P3 开工项；D6 经典布局随 P3（先前裁定）。

---

## P3 — 右列与拇指簇重组（目标 pill / 抽屉、头像暂停、lock 上弧、aim 移出）+ D6 经典布局 + P7 角点 + I3

### 0. 开工（2026-10-28 22:43，官方 Claude Code 施工方）

**基线**：P2 关期树（静止：world `b95354db…`、touch_controls `79128d71…`、ui_icon `2daf8a91…`、phonehud `37153267…`，与 P2 关期记录一致）。改前副本 `.tmp/p3_baseline/`（另含 minimap / harness / check_phonehud.sh）。

**范围（照规划 §B4 P3 + P2 关期主控裁定）**：目标 pill + 抽屉（D4，**替换 P2 临时栈预算第 4 级**）；点头像暂停 + ‖ 徽（D1，拇指簇去掉 pause）；aim 移出 HUD（D2，去处 = P1 已建的暂停快捷行）；lock 上弧；命中区 ≥ 70；阿尔法 pill 并入迷你条 + 迷你条并排；cut-in 进中央栈首。主控追加：(a) D6 经典布局开关（设置→界面，新布局默认，经典 = 21.3.2 几何，门跑 2400 s1.00 经典角点）；(b) P7：harness `--hud=` / `--mm=` + hudScale {0.80,1.30} × minimapScale {0.75,1.50} 四角点进常设矩阵；(c) I3 按下反馈 a+0.25（头像、目标 pill、天气片统一）。

### 1. 进度

- 22:5x **门先写**（`Test/phonehud.gd` P3 段，只加；对既有断言的改动见下「测试侧改动」）：
  - 参数 `--hud=` / `--mm=` / `--layout=classic`（开局前写入 Profile，收尾快照恢复）；run tag 追加 `_h130_m150` / `_classic` 后缀（不与规划抓图组合撞名）。
  - 每个 live 态（新布局手机）：`P3: one objective pill on phone`（pill_box 无可见 pill、goal 卡不常驻、「+N」= 总数−1；折叠时击杀片徽 = 总数）、`objective pill text size`（D7 下限）、`no alpha pill while bar visible`、`no pause / aim button in the thumb cluster`、`lock on the arc`（中心 = 右下 + (−268,−184)·ts）、`lock clears all`（小地图/击杀/目标 pill/抽屉/prompt）、`touch targets >= 70`（全部按钮命中区 + 大招盘 + 头像/目标/天气命中区，ts 0.70 亦然）、`hit areas never cover another button`、`portrait tap target >= 70 covers the portrait`、`portrait wears the pause badge`。
  - Boss 子步：补到 ≥3 只阿尔法 → `mini bars side by side`、`second bar names the alphas past two`、cut-in → `cutin x boss disjoint`（且在 boss 之上、跨度内、不压迷你条）。
  - 手机尾段：注入 阶段事件 + 彗星 + 虫群（规划 events3）→ 整套 `_assert_state("events3")`；点目标 → `press feedback (objective)`、`objective tap opens the drawer`、`drawer does not pause the game`、**`drawer lists all`（parity：每个事件标题+副行、goal 名/条件行/计数、「查看全部挑战」）**、`drawer inside UI area`、`drawer x thumb cluster disjoint`、`drawer text size`、`tap outside closes the drawer`、`drawer auto-collapses after 4 s`（3.4 s 仍开、4.6 s 已收）、`drawer opens all challenges paused` + `closing the challenge list returns to pause`；**`pause reachable`**（真触点点头像 → 暂停、状态页）+ `press feedback (portrait)`；`press feedback (weather chip)`；**`aim toggle lives in the pause quick row`**（真按开关 → camAssist 翻转、触控层同步、复原）；**`classic switch flips the layout` + `round-trip restores the layout`**（经设置→界面真开关来回切）。
  - 经典角点：`P3 classic: 21.3.2 top band`（726 卡 / 454 hero / s_top = min(s,(vw−24)/1368) / 收起项全在）、`thumb cluster keeps the pause / aim / lock column`（命中区 = 视觉）、`goal card resident, no objective pill / portrait tap`、`no stat toast`、反向 round-trip；P1 断言照跑（语义不属布局）。桌面：`P3 desktop: no phone-layout pieces`。
  - 测试侧改动（不放宽）：① 既有右列断言在新布局里的主语由 goal 卡换成目标 pill（规划 P3「栈的定义改为目标 pill 底」）；pill 折叠进击杀 +N 时 goal 类断言改为断言折叠成立；旧树无 `_obj_pill` → 主语仍是 goal 卡，红基线不受影响。② `_touch_elems` / `top card rides s_t` 跳过隐藏按钮（隐藏的 pause/aim 留在原偏移，不能拿来配对）。③ P2 `s_t formula` / `minimap at s_mm` 的 s_mm 加 P7 列高上限（见实现；默认缩放矩阵里不触发）。
- 22:58 `Test/uip3_red.sh`（uip2_red 模板：argv0 守卫、`--check-only` 先行、900 s / 20 MB）。VM 本地 `--check-only phonehud.gd` rc=0。同步：SYNC OK，TREE PARITY OK（93 files），NUC world = `b95354db…`（P2 关期树），phonehud `883f128a…`。**红基线**已 setsid 启动（a 2400 s1.00 i0 / b 1920 s1.50 i48 / c 经典 2400 s1.00 / p P7 hud1.30 mm1.50 2400 s1.50 / d desktop）。
- 23:1x 实现首版（VM 树；红基线跑完前不同步）。逐项：
  1. **拇指簇**（`touch_controls.gd`）：`set_layout_classic(on)` — 新布局 pause / aim 区 `visible=false`（D1/D2）、lock 换到弧上 `LOCK_ARC (−300,−216,−236,−152)`、每个命中区按 `max(0,(70−size·ts)/2)` 外扩、panel 内缩回视觉尺寸；大招盘同样外扩（`UltGauge.hit_pad`，圆盘按 pad 内缩绘制）；`column_left()` / `column_top()` 新布局返回 INF（中央跨度的 lane 退回小地图）；新增 `cluster_top_over(x0,x1)`。经典 = 21.3.2 簇（列 + 命中区 = 视觉）。`ui_medallion.gd` 加 `press_a`（按下白罩）。
  2. **目标 pill + 抽屉**（D4）：`_event_list(new_layout)` 统一事件源（桌面/经典 pill 栈、手机 pill、抽屉同源）；手机优先级 阶段事件 > 闪光/联盟 > 彗星 > 虫群 > 阿尔法 > 喵喵（喵喵只作兜底，R4f），迷你条可见时不出阿尔法项（R4g）；`_obj_pill`（176 设计宽，标题 13 / 副行 11，按 D7 下限抬字）+「+N」徽；越过 Z 时折进击杀片「+N」（`_kills_badge`，Z3）——**P2 临时第 4 级栈裁剪已删除**；抽屉 `_obj_drawer`（右缘 = 小地图左 − 8、顶 = 小地图顶、宽 320×s_mm、底 ≤ 其下拇指簇件顶 − 8、超高滚动），内容 = 全部事件（标题+副行）+ 完整 goal（头像、名、进度条、条件行 + 计数）+「查看全部挑战」（先暂停、只读 G10，关闭回暂停面板）；不暂停游戏，4 s 无操作 / 点抽屉外 / 开模态 / 离开游玩态自动收起。goal 卡与 pill 栈在新布局不常驻。
  3. **头像暂停**（D1）：`_portrait_hit`（触控层、摇杆区之后，≥70，盖住头像）→ 抬起时 `_open_pause()` 状态页；头像加「‖」小徽。
  4. **I3 按下反馈**：`_p3_tap_input` / `_p3_press_fx`——按住时目标面板底色 a+0.25（首次按下复制 stylebox），头像为 0.25 白罩；动作在抬起时触发（触摸 + 模拟鼠标 300 ms 去重）；天气片同一套反馈（动作仍在按下时，P2 门不变）。
  5. **迷你条并排 + 「+N」、cut-in 进中央栈首**（`_layout_hud` 手机分支）；第 2 条名后「+N」（`_update_mini_bars`）。
  6. **D6 经典布局**：Profile `classicLayout`（默认 false）；设置→界面「经典布局（旧版 HUD 排布）」开关（`ClassicLayoutSwitch`，切换即 `_apply_ui_scale`）；`_new_layout()` = 手机系数 且 非经典；`_p3_apply_mode` 只在翻转时动作；经典分支恢复 21.3.2 的 `vw > 1280 or 手机系数` 拟合（P2 把它拿掉了）。
  7. **P7 列高上限**：新布局 s_mm 额外 ≤ (Z−14)/(176·mmScale+28)（Z = 列下方拇指簇件顶 − 8，下限 0.5）——小地图 1.50 + 触控 1.50 时小地图 + 击杀会压到大招盘，pill 折叠救不了；默认缩放永不触发。
- 23:2x（NUC 时钟）**红基线完成**（P2 关期树 world `b95354db…` + P3 门，`Test/out/uip3_red_*`）：
  - a 2400 s1.00 i0：`checks=843 fails=57` —— **57 条全是 P3 断言，kept / P1 / P2 零误伤**。
  - b 1920 s1.50 i48：`checks=898 fails=60` —— 60 条全是 P3。
  - c 经典 2400 s1.00：`checks=655 fails=12` —— 全是 `P3 classic:`（旧树没有经典开关，跑的是 P2 几何：s_top 1.45 vs 21.3.2 的 1.152、卡宽 560、goal 卡不…等）。
  - p P7 角点 hud 1.30 / mm 1.50 / 2400 s1.50：`checks=898 fails=102` = 60 P3 + **42 条既有断言**：`tc_ult x minimap / kills / goal`、`info stack bottom <= ult top − 4`（栈底 433 vs 大招盘顶 348）、`goal name label has real width`（P2 第 4 级把 goal 卡压到 0.5，名宽 54）、P2 `s_t formula` / `minimap at s_mm`（带 P7 上限后的期望 1.116 vs 实际 1.30）——**规划风险 P7 在 P2 树上真实成立**，正是主控要这组角点的原因。
  - desktop：`checks=659 fails=0`（`P3 desktop: no phone-layout pieces` 在旧树即绿，属不变量守护，同 P2 惯例）。
  - 旧树上本就为绿的 P3 断言（守护型，预期）：`aim toggle lives in the pause quick row`（P1 已建去处）、`hit areas never cover another button`（旧树命中区 = 视觉）、`lock clears all`（列位置）、`classic switch round-trip restores`（旧树无开关，两次「切换」都是空操作；配对的 `flips the layout` 红）、部分态的 `no alpha pill while bar visible`（该态 pill 被栈预算裁掉）。
- 红跑期间对 VM 树的小改：抽屉「查看全部挑战」改为固定页脚（不随滚动出视野）且画出高 ≥ 70（I2），门加 `P3: drawer button tap target >= 70`；门在比对抽屉前同帧同步刷新（倒计时副行每秒变）；`check_phonehud.sh` 加 4 个 P7 角点 + 经典角点（额外参数进日志名，`_h130_m150` / `_classic`）；`Test/uip3_batch.sh`（uip2_batch 模板，parse 门加 ult_gauge / ui_medallion / profile）；`uip3_red.sh` 加迭代角点 e/f/g/q。
- 23:4x 迭代 it1 变体 a：前段（kept/P1/P2/P3 各态）**零失败**；P3 尾段红 6 条 + 超时 rc=124——**harness 缺陷**：注入的虫群/阿尔法给经验，抽屉点按时正好弹出升级选卡（state=draft，触控层隐藏），随后所有「无模态才计时」的等待空转到 4000 帧守卫，整跑撞 900 s。修：P3 尾段冻结经验（xp_mult=0，段末恢复）+ 每次点按前 `_p3_ready()` 收选卡、等触控层；条件未放宽。日志中的 `Rect2 size is negative`（41 次）为既有（P2 关期 2400 日志 50 次：隐藏 pw_row 的空 rect 参与配对），非本期引入。只杀本次 run（方括号锚定），it2 启动（9 角点）。
- 23:5x it2 变体 a 2400 s1.00 i0：`PHONEHUD DONE checks=805 fails=0`（检查数少于红基线 843：新布局无 pill 栈，原「触控件 × 每颗 pill」配对不再生成）。看图（拉回 6 张 2400 抓图，`uip3view`）：目标 pill「幽灵迷雾 +3」、抽屉（3 事件 + 完整 goal + 页脚按钮，「目标 · 4 项」与 +3 一致）、迷你条并排 +「穿山王 +1」、cut-in 居栈首、lock 上弧、pause/aim 已去、头像 ‖ 徽——均照规划。**门看不到的视觉缺陷 1 处，已修**：cut-in + boss + 并排迷你条 + toast 同时在场时 toast 压到守护者 prompt（1.3 s 瞬时，但真实重叠）。修：cut-in 缩放按 min(s_t, 跨度/460)（同 F4 迷你条规则；原按原始系数 1.8，带高 115 px），并落地规划 Z4「栈底过 0.55·vh 时 toast 缩到 1.0」；门加 `P3: centre stack clears the prompt (cut-in up)`。
- 00:1x（10-29）it2 结果：a `805/0`；**c 经典 2400 s1.00 `655/0`**；b 1920 s1.50 i48 `739/2`、p P7 hud1.30/mm1.50 2400 s1.50 `739/24`。逐条处置（均为实现缺陷，已修；门条件未改）：
  - b 的 2 条 P1 镜头断言（`single-thumb drag rotates once` / `two-thumb …`，dyaw −0.1 vs −0.6）：**P3 引入的真实回归**——Godot 把触摸拖动交给手指下的 STOP 控件，lock 上弧后正好在右拇指的划屏路径上（ts 1.50 时 x 830–926、y 396–492），划过 lock 的那 5/6 步被吃掉。修：已成为「镜头触点」（按下时没落在任何控件上）的拖动改在 `World._input`（GUI 路由之前）转镜头，`_unhandled_input` 的拖动分支删除（不会重复计数）；门加 `P3: camera swipe across the lock keeps turning`（每个变体都从 lock 左侧 70 px 起划过 lock）。
  - p：P7 列高上限生效（红基线的 42 条 ult×小地图/击杀/goal、栈底断言全消失）。余下：① `P2: kills pill text >= 18`（列缩放被上限压到 1.116，击杀字 14×1.116 = 15.6）→ 新布局击杀字按 ceil(18/s_mm) 抬（默认缩放下仍 14，经典恢复建时字号）；② prompt 退化成 34 px 宽 27 行（`prompt shows every wrapped line` / `F5c 2-line cap` / `x BL slot band` / `tc_lock x prompt`）→ **`_layout_prompt` 的潜在顺序缺陷**：「窄跨度→抬升」判定先于「夹到拇指簇左缘」执行，过去靠 pause/aim/lock 列把 lane 收窄才没暴露；列没了以后夹紧把「够宽」的跨度夹成负宽。新布局改为先夹后判（经典照 21.3 原序不动）；③ boss 态 `tc_dash / tc_lock x banner`（hud 1.30 时 toast 过大）→ 由上面已落地的 Z4「栈底过 0.55·vh toast 缩到 1.0」覆盖。
  - 杀掉 it2 余下角点（旧树），it3（9 角点：a b c p e f g q d）启动。
- 01:0x it3 结果（9 角点，主控拉回校验 `uip3_it3_pull.done` RC=0 files=9 bytes=813690）：a 2400 s1.00 `807/0`、b 1920 s1.50 i48 `741/0`、c 经典 2400 s1.00 `655/0`、p P7 hud1.30/mm1.50 2400 s1.50 `741/0`、**e 2400 s1.50 i0 `741/1`**、f 2340 s0.70 右 48 `807/0`、g 1920 s0.70 `807/0`、q P7 hud0.80/mm1.50 1920 s1.50 i48 `741/0`、d desktop 1280×720 `659/0`。e 的 wrapper rc=124：日志 `PHONEHUD DONE checks=741 fails=1` 行完整，其后只有一行 `====…`（Godot 崩溃处理器横幅开头、无后续），该跑恰满 900 s——断言阶段已结束，挂在 `quit(1)` 之后的退出阶段（it4 重跑时复核，见下）。
- 04:0x（续作施工方）**e 红根因与修法**：
  - 红：`boss: tc_dash x banner disjoint :: [P: (1276, 384), S: (120, 120)] vs [P: (517, 340.1348), S: (830.2, 56)]`。
  - 根因：P3 新布局去掉 pause / aim 列后 `touch_controls.column_left()` 返回 INF，中央跨度右缘退回小地图左缘（span_r 1347），横跨冲刺键 x 段 1276–1396；ts 1.50 时冲刺键顶 384，高于 Z4 线 0.55·vh = 396。boss 态 boss 卡 + 并排迷你条把横幅推到 y 340.13，横幅已按 Z4 缩到 1.0（高 56、底 396.13），仍与冲刺键重叠 12 px。即 Z4「栈底 ≤ 0.55·vh」本身不足以保证与拇指簇不交——簇件可以高过这条线。
  - 修（只动 `scripts/world.gd`，门未改）：新增 `_p3_lane_above(y)`（`world.gd:13218`）——顶高于 y 的拇指簇件（可见按钮命中区 + 大招盘，`_ui_root` 空间）中最左 x − 12，无则 INF；`_layout_hud` 横幅段（`world.gd:12900-12931`）在 Z4 缩放之后，手机下只对横幅这一行把跨度右缘收到 `_p3_lane_above(横幅底 + 8)`，按收窄跨度重新居中、`bsc = min(bsc, 收窄跨度·0.96/文字宽)`，背板宽 = 收窄跨度。bsc 只会变小 → 横幅底只会上移 → 参与收窄的簇件集合只会变少，单遍判定即保守成立。cut-in / boss 卡 / 迷你条 / prompt 用的仍是原跨度（它们的底都在 340 以下，低于任何簇件顶）。
  - 与拟修方案的唯一出入：无（判定用命中区而非视觉框，与既有 `_p3_z_over` / `cluster_top_over` 同口径，更保守）。改前副本 `.tmp/p3_it4_baseline/world.gd`（sha256 `051440d8…`），改后 `7b7f6038…`；VM 本地 `--check-only world.gd` rc=0；`sync_to_nuc.sh` SYNC OK，首次 parity 因 tsproxy 握手超时报 manifest 空，20 s 后重跑 `check_tree_parity.sh`：TREE PARITY OK（94 files），NUC world = `7b7f6038…`。
  - it4（`uip3_red.sh it4 ea`）已 setsid 启动（04:04 NUC），NUC 端 7 个 parse 门 rc=0。
- 04:2x **it4 结果**（树 world `7b7f6038…`；拉回 `uip3_it4_pull.done` RC=0 files=3 bytes=183788，校验通过）：parse 门 7 个 rc=0；**a 2400 s1.00 `checks=807 fails=0` rc=0**；**e 2400 s1.50 `checks=741 fails=0` rc=0**——e 红消除，检查数与 it3 相同（没有断言被跳过）。退出挂起复核：it4 的 e 正常退出（`DONE` 后只有常见的 `ObjectDB instances leaked at exit` 警告，rc=0，未撞 900 s）；it3 那次 rc=124 只出现在 `quit(1)` 那一跑，日志只留下崩溃处理器横幅的第一行，疑为退出阶段崩溃后处理器挂住（单次、不可复现，未进一步取证；它发生在断言全部完成之后，不影响 it3 的计数）。
- 04:22（NUC）终版 `Test/uip3_batch.sh` setsid 启动（启动前 argv0 守卫无 Godot 在跑，NUC world `7b7f6038…`）。

### 修复轮 2（2026-10-29 17:1x，官方 Claude Code 施工方）

**输入**：终版 batch（04:22–10:10）矩阵 42 组合 36 绿 / 6 红；本轮拉回 `uip3fin_pull.done` RC=0 files=47 bytes=4150416，6 红的日志逐条复核与派单一致。改前副本 `.tmp/p3r2_baseline/`（world `7b7f6038…`——即 it4 树，`_p3_lane_above` 在树上、本轮不回退；touch_controls `8d9afdb2…`；phonehud `4b351ae9…`，**门本轮未改**）。

- **类 A：`banner x goal disjoint`（组合 2 `2340 s0.85 右48 hud1.30 mm0.75` ×3 态、组合 4 `2400 s1.00 hud0.80 mm0.75` ×4 态）**
  - 根因：新布局门的 goal 主语 = 目标 pill。右列各件同骑 s_col，但宽度不同：小地图 176·mmScale、击杀片 134、目标 pill 176（设计 px）。mmScale 0.75 时小地图只有 132 宽，**比击杀片和目标 pill 都窄**，二者伸出小地图左缘；中央跨度右缘 = 小地图左 − 12（列没了以后 `column_left()` = INF），横幅于是盖到 pill 上（组合 4：横幅右 1404.4 vs pill 左 1359.2，y 205–290 对 230–326）。mmScale ≥ 1 时小地图是列里最宽的件，所以其余 40 组合无此红。
  - 修（`scripts/world.gd:12808-12819`）：新布局下中央跨度的 lane 取 min(小地图左, 可见击杀片/目标 pill 的画出左缘)。mmScale ≥ 1 时 min 不变（pill 左 = 小地图左），已绿组合行为不动。
- **类 B：`P3: centre stack clears the prompt (cut-in up)`（组合 5 `2400 s1.50 右48`、6 `2400 s1.50 左48`、2）**
  - 根因：prompt 钉在左下簇顶上、**向上**长：带 48 安全区时簇夹紧把 prompt 压成 210 宽，走解除行数上限的分支，4 行高 120，顶到 463；组合 2 hud 1.30 时左下簇放大，夹紧后不到 80 宽，prompt 退回整跨度两行，顶 475.6。同时 cut-in + boss + 并排迷你条把 toast **向下**推到 424/429。Z4「栈底 > 0.55·vh 时 toast 缩到 1.0」只是条水平线，管不住这两者互相撞（无安全区的 2400 s1.50 绿，因为 prompt 只有两行、顶 516）。
  - 修（`scripts/world.gd:12865-12867`、`12915-12936`）：先把 `_layout_prompt` 调用挪到 toast 段之前（prompt 不读栈里任何东西，纯换序，经典布局结果不变）；新布局下 toast 的 x 段与 prompt（标签 ∪ 背板的画出框）相交、且 toast 底 > prompt 顶 − 4 时，bsc ≤ (prompt 顶 − 4 − 栈顶)/56（下限 0.5）。这一步排在 `_p3_lane_above` 前面；bsc 只会变小，lane 那步仍然保守成立。实测余量：组合 5/6 bsc → 0.62，组合 2 → 0.75。
- 状态：两类修法 VM 本地 `--check-only world.gd` rc=0；sync SYNC OK + TREE PARITY OK（97 files）；NUC 验证待出（`uip3_r2.sh`）。
- 17:4x NUC 单跑（`uip3_r2.sh r2a`，world `079a9865…`）：**组合 4 `checks=807 fails=0`**（类 A 消除，检查数与终版相同）。
- **类 C：组合 1 `1920 s1.50 右48` 的 P1 镜头两条（dyaw=0）——单跑复核仍红（`741/2`），非偶发**，判定为 harness 采样点与按规划放置的 lock 撞位：
  - 证据：`_p1_two_thumb` 的镜头拇指固定按在视口 62%/62% = (793.6, 446.4)；同一日志 `P3: lock on the arc` PASS，lock = [782–878 × 396–492]（弧心 (830,444) = 右下 + (−268,−184)·1.50，右安全区 48 把它左移 48）——按下点正落在 lock 上，这一按是 lock 点按、不是镜头触点，dyaw 恒为 0（不是 P3 it2 修过的「划过 lock 被吃步」，那条 `camera swipe across the lock keeps turning` 本跑 PASS）。左 48 / 无安全区 / 2400 宽时 lock 在 830/1102，不覆盖该点，所以只这一组合红。规划 lock 的位置是门自己断言的，代码不改。
  - 修（门，仅采样，判定不变）：`Test/phonehud.gd:1111-1125`——镜头拇指的起点若落在任一可见触控件的画出框里，就左移到该件左缘 − 70（与 P3 lock 划屏测试同一取点规则），dyaw 区间 [−0.75, −0.45]·camSpeed 原样；起点写进 detail。起点不落在控件上的组合（其余 41 个）起点不变。待 NUC 复核。
- 18:0x NUC 单跑（world `079a9865…`）：**组合 5 `741/0`、组合 6 `662/0`**（类 B 消除）；组合 2（诊断子类跑，门逻辑相同）`722/2`——类 A 三条 + 类 B 一条均消除，只剩抽屉两条（类 D）。
  - 检查数下降（组合 6 741→662、组合 2 807→722）**不是本轮改动造成**：两跑都是 `P3: three events injected :: events=4`（随机多出第 4 个事件）且 `events3` 快照那一刻触控层被隐藏（`_assert_state` / `_p3_state` 里依赖 tc_vis 的段整段不生成，`(events3)` 检查 27→19）。终版 batch 里**已绿**的 `2400 s0.70 i0` 有同样的 events=4 / 19 条，说明这是既有的随机夹具情形。记为残留：门在该随机分支下静默少测约 80 条（不会误红，但覆盖变少）；按本轮约束不改门。
- **类 D：抽屉两条（组合 2、3）——根因与修法（续作施工方 2026-10-29 22:34 落树，world `079a9865…` → `b3afa5d4…`）**：
  - 根因：抽屉行每秒随倒计时文字重建；新建的 autowrap 标签在重建帧报 width-0 最小尺寸（容器次帧才排序），在该帧量高会把抽屉瞬间顶到 Z 上限最大高度——抽屉下方边缘逐秒抖动一帧，落在抽屉下方的点按会被这一帧的高框吞掉/误判，表现为「打开后提前消失、点外部关不掉」的时序型红（两跑不一致亦源于此）。
  - 修（`scripts/world.gd`，diff 对 `.tmp/p3r2d_baseline/world.gd`）：抽屉行只在结构变化（行数 / goal 与计数有无 / s_col）时重建，纯文字变化（倒计时）写进现有行（新增 `_p3_write_drawer` + `_obj_drawer_shape` / `_obj_drawer_refs`）；重建后 `_obj_drawer_settle = 2`，两帧内保持上次高度、process tick 待容器排序后再量高重排。goal 填充比例抽出 `_p3_goal_frac()` 共用。
  - 验证：组合 2、组合 3 诊断跑 + 正式门各绿（链 `uip3_r2d_chain`：2 = 807/0、3 = 807/0）；it3 九角点复验 8/9 绿，唯一红 = a 角点 P1 双拇指（`joy=true/false, mv=(0,0), dyaw=0`，模态打断签名）——主控单独复跑 a = **807/0 rc=0**，按 P2 关期先例判夹具事件，非回归。

### P3 关期（主控验收，2026-10-30 10:2x）

**P3 通过，正式关闭。** 依据：终版 `Test/uip3_batch.sh`（2026-10-30 01:41–07:45，树 world `b3afa5d4…`）：parse 门 7/7 rc=0、import rc=0、class_cache rc=0、**全矩阵 42/42 全绿（matrix rc=0）**、**全量 suite 514/0（rc=0，连 C22 审计 F3 既有宝箱夹具红本轮亦未出现）**、bootsmoke rc=0（BOOTSMOKE OK）。日志已拉回校验（`uip3fin2_pull.done` RC=0，76 files / 6,052,625 B）。
**主控裁定**：类 C 的门采样起点修正（判定条件未动、仅起点避开控件）批准；类 A/B/D 三处实现修法照记录成立；随机第 4 事件分支下门少测约 80 条的覆盖残留保留在案，不在本程序内处理（不会误红、不会误绿已测项）。P3 期内 D1（点头像暂停）、D2（aim 进暂停快捷行）、D4（目标 pill + 抽屉）、D6（经典布局开关）、P7 四角点、I3 按下反馈均已落地并通过全矩阵。

---

## P4 — 左下双行槽 + 交互气泡（Z6/Z7）

### 0. 开工（2026-10-30 10:2x，官方 Claude Code 施工方）

**基线**：P3 关期树（静止；VM = NUC 逐文件一致）：world `b3afa5d4…`、touch_controls `8d9afdb2…`、ui_icon `2daf8a91…`、player `ca7c7d0a…`、phonehud `6b61e0d6…`、check_phonehud.sh `988b7aa1…`。改前副本 `.tmp/p4_baseline/`。NUC 开工时无 Godot 进程。

**范围（规划 §B4 P4 为准）**：BL 簇手机新布局分支 = 招式行（每招一槽：属性图标 + Lv + 冷却扫光，行末锁槽）+ 维生素行（每项一个 34 槽：图标 + 级），s_bl = min(s, 1.35)，锚 (12, vh−12)，簇宽 = 槽行实宽（ult 圆 / 名不占位）；`set_ring_bottom_limit` 参照 Z7 视觉顶；`_layout_prompt` 手机新布局分支 = §B1 C5 交互气泡（fx_l = BL 右 + 16、右缘 = cluster_left − 16、底 vh − 24、≤ 2 行、scale ≤ 1.4、撤 lifted regime、右侧三角指向 ❗）。经典布局 / 桌面不动。

**派单与规划/用户决策的出入（以规划为准，待主控裁定）**：
- ★ 派单第 1 条「槽位显示真实持有物与数量，可点按使用（原作语义：局内道具从这里用）」与规划不一致：规划 §B1 B1+B2+B3 / §B4 P4 的两行是**招式行 + 维生素行**，用户已拍板的 D5 =「持有道具的查看去处 = 暂停页（不在 HUD 槽里管）」；原作 `hud-bl` 也是维生素槽 / 招式槽（UI_SPEC:212），物品栏是另一块 `hud-br`。且本作没有任何主动使用的局内道具（items.json 126 条只有 `mods` 被动加成；招式自动释放；维生素为被动累加）——做「点按使用」等于新增玩法，违反「不动玩法规则」。**处置**：槽位只做显示（规划 I1：可点 HUD 仅头像 / 小地图 / 目标 pill / 天气片），门断言槽位不吃触点（触点落在槽上照常起摇杆）。派单第 1 条的「两边同源、状态一致」照做：槽行与暂停状态页读同一份 `player.moves` / `player.vit_levels`，门断言一一对应且一次构筑变化（升级招式 + 加维生素）两处同步——这是本作语境里「用掉一个，两边同步」的对应物。派单第 4 条「命中区 ≥ 70 / I3 按下反馈」因槽位不可点而不适用于槽位；P3 的 `touch targets >= 70` 门照跑全部可点件。
- ★ 派单第 2 条「交互气泡收进左下簇**上方**的气泡位」与规划不一致：规划 §B1 C5 / §B2 Z6 / §B4 P4 的气泡在**底中**（左缘 BL 右 + 16、右缘拇指簇左 − 16、底 vh − 24），并明确「撤掉 21.3.2 的 lifted regime」——左下簇上方正是被撤掉的那个位置。按规划做。

### 1. 进度

- 10:3x **门先写**（`Test/phonehud.gd` P4 段，只加）：
  - 每个新布局 live 态（`_p4_state`）：`P4: all moves visible`（可见招式槽数 == `player.moves.size()`，逐槽 key 与 Lv 对上——parity）、`P4: vitamins visible`（同上，对 `vit_levels`，顺序 = 字典序）、`P4: BL cluster is exactly the slot rows`（簇画出框锚 (12, vh−12)、右缘 = 槽行最右、可见子孙全在框内、旧 move 卡不可见——即 ult 空位不计宽）、`moves row over vitamins row, lock slot ends row 1`、`P4: s_bl = min(s, 1.35, …)`（见偏差）、`P4: slot text size`（D7 下限 19 / 16:9 17）、`P4: slots pass touches through`（簇下所有可见 Control 均 IGNORE——规划 I1）、`slots pairwise disjoint`、`P4: BL rows x thumb cluster / ring / hero disjoint`、`P4: ring clears slot rows (Z7 top)`、`P4: ring home unmoved at touchScale >= 1`（规划「ts1 时 home 不需要上移」）、`P4: centre clear incl. BL rows + bubble`（规划 P4：prompt 纳入中央净空，只许 0.85·vh 以下部分与中央矩形 x 段重叠 ⇔ 与中央矩形不交）。
  - 有 prompt 的态（`_p4_bubble`）：`P4: prompt width (bubble span >= 300)`、`prompt inside its span`、`bubble right edge = cluster_left - 16`、`bubble bottom = vh - 24`、`prompt <= 2 lines, all visible`、`bubble scale <= 1.4`、`prompt x thumb cluster / ring disjoint`、`prompt x BL cluster disjoint`、`bubble pointer aims at the interact button`（三角尖在气泡右缘与簇左缘之间、y = ❗ 中心 y 夹到气泡内）。
  - 手机尾段（`_p4_phone_block`，冻结经验同 P3）：注入到 3 招 + 2 种维生素（规划 p4_moves3_vits2）→ 整套 `_assert_state` + `P4: slot rows and pause page agree`（暂停状态页逐条找到「招式 Lv.n」「维生素 Lv.n」，且槽数相等）→ 升一招 + 加一级维生素 → `P4: a build change reaches the HUD slots` + 再比一次暂停页 → `P4: cooldown sweep reads cd_t` → `P4: a touch on a slot drives the stick (slots display only)`（真触点落在槽上：摇杆起、未暂停）→ 满槽（招式到 move_cap、11 种维生素全有）`full_slots` 整套 + 找一个 prompt 道具做 `full_prompt` 整套 → D6 往返 `P4: classic round trip restores the slot rows` → 复原构筑。
  - 经典 / 桌面每态：`P4 classic|desktop: legacy BL cluster unchanged`（460×118、offset_left 0、scale = s、旧 move 卡可见、新行与三角不可见）。
  - **既有断言的主语迁移（2 条，仅在 P4 树 + 新布局下生效，旧树原样）**：① `joystick ring clears the slot row` 的槽行顶由「簇顶 + 56·scale」改为 Z7 视觉顶（簇画出框顶）——规划原文「参照物改为 Z7 顶」，新顶更高 = 更严；② `prompt x BL slot band disjoint` 的槽带由「簇顶 + 48·scale 起」改为整个簇画出框（∪ 可见子孙）——旧带的超集 = 更严。其余既有断言未动。
  - 抓图 `mobile_p4_<state>_<tag>.png`：两个规划组合出 hud_start（无维生素）/ chest_prompt / meowth_prompt / moves3_vits2 / full_slots / full_prompt。
- 10:35 `Test/uip4_red.sh`（uip3_red 模板，默认 abcd）；`sync_to_nuc.sh` SYNC OK + TREE PARITY OK（99 files），NUC world = `b3afa5d4…`（P3 关期树）、phonehud `ef0ee6eb…`；**红基线**（a 2400 s1.00 i0 / b 1920 s1.50 i48 / c 经典 2400 s1.00 / d desktop）setsid 启动，7 个 parse 门 rc=0。
- 红跑期间门的一处补改（VM 树，未进红跑）：`P4: s_bl` 的期望值加「中央净空拟合」项（见偏差 2）。该断言在旧树上因无 `_bl_move_slots` 必红，补改不影响红基线判读。
- 10:5x **红基线完成**（P3 关期树 world `b3afa5d4…` + P4 门 `ef0ee6eb…`；拉回 `uip4red_pull.done` RC=0 files=5 bytes=445699，已校验）：
  - a 2400 s1.00 i0：`checks=1246 fails=102` — 101 条 P4 断言（每 live 态 ×8：all moves / vitamins visible、BL is exactly the rows、s_bl、slot text、BL x ring（旧簇 885 宽压到摇杆环）、ring clears Z7、centre clear；每 prompt 态 ×6：bubble bottom / right edge / inside span / scale ≤ 1.4 / pointer；单次：parity ×2、build change、sweep、touch-on-slot、classic round trip、full-slots prompt）+ **1 条非 P4：`P1: two-thumb camera rotates while the stick is held`（`joy=true/false mv=(0,0) dyaw=0`）**。
  - b 1920 s1.50 i48：`checks=1159 fails=120` — 115 条 P4 + 5 条非 P4：同一条 P1 双拇指（`joy=true/false, dyaw=-0.2`）；以及 4 条既有断言**只出现在 P4 新加的 `full_slots` 态**（`tc_jump x prompt`——旧树 lifted prompt 在满招式下压到跳跃键；`banner x bar0/bar1`；`P3: one objective pill`「total=1 / 折叠徽 +2」）——旧树在新态下的真实缺陷/时序，不是对既有态的误伤；新树上须全绿。
  - c 经典 2400 s1.00：`checks=660 fails=0`（`P4 classic: legacy BL unchanged` 在旧树即绿，守护型）。d desktop：`checks=664 fails=0`（同上）。
  - 旧树上本就为绿的 P4 断言（守护型，预期）：moves-over-vitamins 次序（旧树无槽行，空真）、prompt ≤ 2 行、prompt width（旧 lifted prompt 的跨度量出 ≥ 300）、prompt x BL / x 拇指簇、ring home unmoved（ts1 旧环不抬）、slots pairwise / pass touches through、full rows injected。
  - **P1 双拇指两跑全红的处置**：签名与 P2/P3 关期记录的「测试窗口内模态干扰」一致（拖动中摇杆被释放 = 升级选卡弹出隐藏触控层）。在 P3 终版里它是偶发；P4 门在两个抓图组合多出 3 次抓图的帧，把选卡稳定地推进了这个窗口。修（门，仅采样，判定不变）：`_p1_two_thumb` 期间冻结经验（xp_mult=0，结束恢复），同 P3 尾段做法。
  - 门的另一处修：满槽态找 prompt 时 zone 已被 boss 段设成 3（该区道具不在场景里，`_prop_of_kind` 全空）——加祭坛兜底（守护者在场时全图 prompt「击败守护者！」，否则祭坛召唤行）。
- 11:02 实现首版落地（清单见 §2），连同上述两处门修同步：SYNC OK + TREE PARITY OK（100 files），NUC world `11124be4…`、phonehud `8b59e89c…`；迭代 it1（a b c p q d：2400 s1.00 / 1920 s1.50 i48 / 经典 / P7 hud1.30 mm1.50 2400 s1.50 / P7 hud0.80 mm1.50 1920 s1.50 i48 / desktop）setsid 启动。
- 11:3x **it1 a 2400 s1.00 i0：`checks=1411 fails=5`**（拉回 `uip4it1a_pull.done` RC=0 files=7，含 6 张 2400 抓图）。kept / P1 / P2 / P3 在既有态零失败；P1 双拇指（冻经验后）PASS。逐条：
  - `P4: slot rows and pause page agree` ×2（暂停页一条都没读到）：**门时序**——抓图看到 moves3_vits2 那一刻升级选卡还开着（本局早先累积的 pending 级数，选卡一张张弹），`_open_pause` 在模态下不开。修（门）：每次读暂停页前、两次抓图前 `_p3_ready()`；判定加「暂停态且状态页在显示」并把读到的标签数写进 detail。比对方式改成与 P2 parity 相同（遍历状态页所有 Label，不按可见过滤——页在 ScrollContainer 里，滚出视口的行也算「一次点击可达」）。
  - `P4: cooldown sweep reads cd_t`（frac 0.578 vs 读时 cd_t/max 0.398）：**门采样**——扫光按渲染帧更新，读数前那一帧之后 NUC 软 GL 又跑了若干物理帧（cd_t 只减不增）。修（门）：(a) cd_t 钉到 50×max → 扫光必须恰为 1.0（精确判定）；(b) 运行中 frac ∈ [cd_t/max − 0.02, (cd_t + 0.25 s)/max + 0.02]。
  - `P3: one objective pill`（full_slots：total=1、pill 徽 +1）+ `P3: no alpha pill while bar visible`（full_slots：pill 标题仍是「阿尔法」）：**实现缺陷（P3 遗留、P4 满槽态首次暴露）**——目标 pill 按 0.15 s HUD tick 刷新，迷你条显隐按帧；满招式时阿尔法生灭很快，pill 会有一个 tick 停在「阿尔法」/ 旧计数。修（`world.gd:11547-11559`）：可见迷你条数一变，当帧 `_refresh_event_pills()`。
  - 看图（2400）：双行槽 / 锁槽 / 冷却弧 / 底中气泡 + 三角均照规划；满槽（8 招 + 11 维生素）s_bl 被中央净空收到 1.17，字号兜底后 Lv 字仍 ≥ 19。暂无需修的视觉缺陷（1920 待看）。
- 11:5x **it1 b 1920 s1.50 i48：`checks=1312 fails=3`**（拉回 `uip4it1b_pull.done` RC=0 files=7，含 6 张 1920 抓图）：parity / sweep 两条同 a（门已修）；第 3 条 `P4: classic round trip restores the slot rows`（往返后 s_bl 1.058 → 1.171）——**实现缺陷**：`_p4_layout_bl` 的气泡宽度拟合只在触控层可见时生效，往返期间设置模态把触控层隐藏，那一次排版漏了拟合，模态关闭后没有新排版来纠正。修（`world.gd` `_p4_layout_bl` / `_p4_layout_bubble`）：拟合读拇指簇几何不看触控层可见性（各按钮命中区在层隐藏时照样有 rect）；门的 `_p4_cluster_left` 同口径（按按钮自身可见性，不看层）。
  - 看图（1920 s1.50 i48：hud_start / chest / meowth / moves3_vits2 / full_slots / full_prompt）：气泡贴底、右缘离拇指簇 16、三角指向 ❗；满槽时 s_bl 被气泡宽度拟合收到约 1.06，Lv 字按 16:9 下限抬到 17 以上，槽行与摇杆环、气泡互不相交。门看不到的视觉缺陷：无。
- 12:3x it1 余下角点（拉回 `uip4it1_pull.done` RC=0 files=7）：**c 经典 `660/0`、p P7 hud1.30/mm1.50 2400 s1.50 `1003/0`、d desktop `664/0`**；q P7 hud0.80/mm1.50 1920 s1.50 i48 `1312/4`——4 条全属上面已修的类（moves3_vits2 态目标 pill 滞后 / parity 读页 / 扫光采样 / 往返 s_bl）。
- 12:3x 修复树同步（TREE PARITY OK）→ it2（abcpqd）启动。
- 12:20 **it2 完成**（前任会话于 11:43 后中断，it2 为 setsid 自行跑完；13:4x 续作施工方拉回 `uip4it2_pull.done` RC=0 files=19 已校验）：b `1312/0`、c 经典 `660/0`、p `1003/0`、q `1312/0`、d desktop `650/0`；**a 2400 s1.00 `1246/1`**，唯一红 `P4: a prompt in the full-slots state`（detail 空串）。
- **13:4x 主控裁定**：§3 两处 ★ 均批准施工方处置——① 槽位只做显示、不做点按使用（规划 D5 与用户已批决策为招式行 + 维生素行、持有物查看在暂停页；本作无主动使用型局内道具，点按使用属新增玩法；派单第 1 条该表述作废，槽行与暂停页同源同步照做）；② 交互气泡按规划 §B1 C5 / Z6 放底中、撤 lifted regime（派单第 2 条「左下簇上方」作废）。另 s_bl 中央净空 / 气泡宽度拟合（最低 0.8、默认态不变）偏差批准。
- 13:5x **a 红定案：门采样缺陷（经验冻结被构筑注入撤销），非实现问题**。证据链：① it2 a 的 `mobile_p4_full_slots_2400x1080_s100_i0.png`（11:51，969 KB，显著小于其余抓图）拍到的是 **「Lv.6 · 升级」选卡模态**盖满屏——满槽态断言刚过（那时 prompt 还是「击败守护者！」），紧接着选卡弹出；② 选卡打开时 `state == "draft"`，`world.gd:12195-12253` 的 prompt 链在 draft 态走 else 分支置空串 → `_p4_any_prompt` 读到 ""；③ 为何冻了经验还会升级：门在 `_p4_phone_block` 开头设 `xp_mult = 0`，但随后的 `_grant_vitamin` → `player.recalc()`（`world.gd:9933`）在 `player.gd:203` 把 `xp_mult` 从头重算为 ≥ 1——冻结在第一颗维生素注入时即失效，守护者战斗中击杀经验照常累积，满 8 招后击杀更快、升级更易落在采样窗口内（a 的 s1.00 时序下两跑命中：红基线 a 与 it2 a 同签名空串；b / q / it1 a 未命中）。修（门，仅采样，判定不变）：`_p4_freeze_xp` 在每次构筑注入后重钉 `xp_mult = 0, xp = 0`；`_p4_prompt_live` 每次读 prompt 前 `_p3_ready()`（收掉漏入的选卡），读时要求 prompt 非空**且**无模态，空样本打 `PHONEHUD INFO P4 full-slots prompt sample` 记录当时 state / modal 供复核。判定「满槽态能取到一个 prompt 并对其做整套气泡断言」未放宽。
- 14:0x **it3（仅 a 2400 s1.00 i0，树 world `37d1dd68…` 未动、phonehud `325d2ba2…`）：`checks=1395 fails=0`**（拉回 `uip4it3_pull.done` RC=0 files=8 已校验）。`P4: a prompt in the full-slots state` PASS（击败守护者！），无 INFO 空样本（首个祭坛样本即为活态）。检查数变化逐名对账：较 it2 a（1246）**+149 = 恰为 `full_prompt` 态整套断言**（it2 因取不到 prompt 跳过该态）；较 it1 a（1411）**−16 = `full_prompt` 态的 `banner …` 系列**（仅横幅在显示时才断言，it1 那一刻有横幅、it3 没有——条件型，非覆盖丢失）。抓图复查：full_slots 无模态、玩家 Lv.3 不再升级（冻结生效）、双行槽 8 招 + 11 维生素；full_prompt 底中气泡 + 三角指向 ❗。

### 2. P4 实现清单（file:line，以终版树为准，终版若再动会更新）

| 规划项 | 实现 | 位置 |
|---|---|---|
| 状态：槽行容器、招式 / 维生素槽表、锁槽、旧件表、签名、模式位、气泡三角、迷你条计数 | 加 | `scripts/world.gd:498-511` |
| 旧件（4 空槽 + 首招卡 + 锁）登记；新行容器 `_bl_rows` + 行内锁槽 | `_build_hud` | `world.gd:3242`, `:3274-3289` |
| 气泡三角（`_prompt_back` 的 Polygon2D 子节点，底色同背板） | `_build_hud` | `world.gd:3366-3371` |
| 模式翻转（新布局 = 旧件隐、新行显；经典 / 桌面恢复 460×118 与因子缩放，按复原尺寸重算支点） | `_p4_apply_mode`，由 `_layout_hud` 调用 | `world.gd:13789`；挂点 `:12751` |
| B1+B2+B3 → 双行槽：每招 46 槽（属性图标 + Lv、边框属性色）、行末锁槽（实验室还有未解锁招式槽时）；每种维生素 34 槽（图标 + 级），按签名重建（P11） | `_p4_refresh_slots` | `world.gd:13825`；HUD tick 挂点 `:11614` |
| 冷却扫光（UltGauge 式弧 + 暗罩，frac = cd_t / (ARCH_CD / 攻速)） | `_p4_tick_sweeps` / `_p4_draw_sweep`（每帧，变化 > 0.01 才重画） | `world.gd:13962`, `:13976`；挂点 `:11453` |
| Z7：锚 (12, vh−12)、簇宽 = 槽行实宽（ult 圆 / 名不占位）、s_bl = min(s, 1.35) + 两个拟合（见偏差 2） | `_p4_layout_bl` | `world.gd:13902`；`_layout_hud` 挂点 `:12901`（在 `_layout_prompt` 之前） |
| 槽字号：规划字号 14，画出低于 D7 下限才抬；标签按字体行盒底对齐（不撑出槽 / 簇） | `_p4_fit_fonts` | `world.gd:13929` |
| 触控时 ult 圆与名字在新布局不出现 | `_update_hud_bars` | `world.gd:11446` |
| `set_ring_bottom_limit` 参照 Z7 视觉顶 | `_layout_hud` 尾 | `world.gd:13058` |
| C5 → 交互气泡（Z6）：右缘 = cluster_left − 16、左界 = BL 画出右 + 16、背板底 = vh − 24、≤ 2 行、scale ≤ 1.4、顶不高于 0.85·vh、一行能更大就一行、宽度贴文字；三角指向 ❗ 中心 y（夹在气泡内）；新布局撤掉 lifted regime（经典照旧） | `_p4_layout_bubble` | `world.gd:13994`；`_layout_prompt` 分流 `:14070-14076` |
| 气泡随文字变化重排（宽度贴文字，旧宽会折出第 3 行） | `_process` prompt 段 | `world.gd:12271-12274` |
| 目标 pill 随迷你条显隐当帧刷新（满槽态暴露的 P3 遗留滞后） | `_update_hud_bars` | `world.gd:11547-11559` |
| 门 | phonehud P4 段 + 2 处主语迁移 + P1 双拇指冻经验 + 满槽 prompt 采样（重钉冻结 `_p4_freeze_xp`、活态读 `_p4_prompt_live`） | `Test/phonehud.gd:2402-2933`（`:2760`, `:2766`）；`:530`, `:654`；`:1110-1124` |
| 脚本 | `Test/uip4_red.sh`（迭代角点）、`Test/uip4_batch.sh`（终版） | — |

### 3. 与规划 / 派单的偏差及理由（待主控裁定的标 ★）

0. 交互气泡位置（派单第 2 条「左下簇上方」vs 规划底中，见 §0 第 2 个 ★）：**主控 13:4x 批准按规划底中。**
1. ~~★~~ **槽位只做显示，不做「点按使用」**（派单第 1、4 条 vs 规划 D5 / I1，见 §0）。**主控 13:4x 批准。**
2. ~~★~~ **s_bl 加两个拟合**（主控 13:4x 批准）：规划给的 s_bl = min(s, 1.35)，与它自己的两条要求在多槽时冲突——① B0.2 / P4 centre clear：槽行越过 0.30·vw 时，Z7 顶必须不高于 0.85·vh（82 设计高 × 1.35 = 111 > 96）；② P4 `prompt width ≥ 300`：满维生素（11 × 38）在 1920 / ts1.50 / 48 inset 下吃掉气泡跨度。实现取 s_bl = max(0.8, min(s, 1.35, max((0.30·vw−12)/W, (0.15·vh−12)/82), (cluster_left−16−300−16−12)/W))。**默认态（≤ 4 招含锁、≤ 7 种维生素）永远 = min(s, 1.35)**；只有槽多时才收（实测满槽 2400 = 1.17、1920 i48 ts1.50 ≈ 1.06），字号按下限兜底。门里同一公式钉死（±0.002）。
3. **「最多 6 槽」未照做**：规划写招式行最多 6 槽，但 parity 门（同一规划）要求槽数 == moves.size()，而 move_cap = 8（持 tm-case 时 10）。按 parity 优先，全部显示（满 8 招 + 锁仍在拟合内）。
4. **维生素行无维生素时仍占行高**（簇高恒 82 设计）：避免第一颗维生素出现时摇杆 home 跳位；空行无可见内容。
5. **气泡宽度贴文字**（规划写的是「最大宽」= 跨度）：短提示不拉成整条；`P4: prompt width` 断言的是气泡**可用跨度** ≥ 300（规划意图），另断言气泡在跨度内、右缘 = cluster_left − 16。
6. **气泡顶 ≥ 0.85·vh 的高度上限**（规划 P4 centre clear 推出：2 行在 1.4 下约 109 高、顶 587 < 612）：两行时 scale 实际约 1.08（字 21.5 px），一行时可到 1.4。
7. **新布局触控时 ult 圆与名字完全不出现**（经典 / 桌面不变）。手机分支本就以拇指簇大招盘为大招按钮；无触控的手机级屏（只有桌面调试会遇到）仍有 R 键。
8. 维生素图标按累加类别映射现有 UiIcon（物攻 sword、特攻 spark、护甲 shield、移速 speed、HP heart、攻速 hourglass、暴击 crit、经验 candy、金币 coin、再生 plus、幸运 luck），未新增图标资源。
9. 测试侧（判定不放宽）：P1 双拇指冻经验；parity 前收选卡；扫光采样窗口；满槽态 prompt 的祭坛兜底 + 构筑注入后重钉经验冻结 + 读 prompt 前收模态；`_p4_cluster_left` 不看层可见性（与实现同口径）。

### P4 关期（主控验收，2026-10-30 19:5x）

**P4 通过，正式关闭。** 依据：终版 `Test/uip4_batch.sh`（2026-10-30 14:04–19:41）：parse 门 rc=0、import rc=0、class_cache rc=0、**全矩阵 42/42 全绿（matrix rc=0）**、**全量 suite 514/0（rc=0）**、bootsmoke rc=0。日志已拉回校验（`uip4fin_pull.done` RC=0，46 files / 7,029,198 B）。it2 遗留的 a 组合满槽 prompt 红已定案为测试侧时序（构筑注入后经验冻结被冲掉、选卡模态遮挡读 prompt），修在采样侧（重钉冻结 + 活态读），终版 a = 1395/0（满槽 prompt 经守护者兜底命中「击败守护者！」）。
**主控裁定**：§3 偏差 0–2 已于 13:4x 批准（气泡底中、槽位只显示、s_bl 双拟合）；偏差 3（招式行不封顶 6 槽、parity 优先全显示）、4（空维生素行占位防摇杆跳位）照记录批准；其余 5–9 为实现/测试口径，与规划意图一致，备案。D5（左下双行槽）至此落地。

---

## P5 — 模态族 + 主菜单手机化（最后一期）

### 0. 开工（2026-10-30 20:0x，官方 Claude Code 施工方）

**基线**：P4 关期树（静止：`scripts/*.gd` 最新 mtime = world.gd 11:24；VM = NUC 逐文件一致）：world `37d1dd68…`、touch_controls `8d9afdb2…`、ui_icon `2daf8a91…`、ui_theme `72a2d09e…`、phonehud `325d2ba2…`、check_phonehud.sh `988b7aa1…`。改前副本 `.tmp/p5_baseline/`。NUC 开工时无 Godot 进程。

**范围（规划 §B4 P5 + §B3 模态族 + 派单）**：M0 落地（`_apply_ui_scale` 对 13 个模态面板改走 s_m = min(s, (vh−16)/H_design)、W = min(W_max, (vw−24)/s_m)，替代 fit clamp）；各模态按 §B3 表手机排版（选卡 / 祝福 / 选择 / 喵喵 / 暂停 / 大地图 / 结算 / Loadout 全屏 / 设置 / 钱包 · 研究室 · 星尘商店 · 挑战）；主菜单包进设计 Control `_menu_design` 居中缩放；不建 APK。

**范围判定（规划未写明处，待主控裁定的标 ★）**：
- ★ 模态手机形态跟随**手机系数**，经典布局（D6）下同样生效：D6 的开关文案与 §B6 定义都是「HUD 排布」（21.3.2 HUD 几何），模态族只有一套手机形态；否则经典开关所在的设置面板会在切换瞬间换形。
- ★ 「点外部 / 返回键」：规划 §B3 只给抽屉定义了点外部收起（I4），模态族没有点外部或返回键语义 → 不新增，保持现状（关闭路径 = 各模态的主操作 / 关闭键，门实按验证）。在案观察：项目未设 `quit_on_go_back`（Godot 默认 true），Android 返回键 = 退出应用；规划未定义，未改。
- P5 抓图组合：规划写 2400 s1.00 i0 + 1920 s1.00 i48；派单迭代角点是 1920 s1.50 i48。模态与触控比例无关（触控层在模态下隐藏），门在三组上都出 P5 图（`_p1_capture_combo` 两组 + 1920 s1.00 i48）。

### 1. 进度

- 20:1x **门先写**（`Test/phonehud.gd` P5 段，只加；主流程只加 3 处挂点：开机菜单块、Loadout 挂点、三种模式的收尾块）：
  - 每个打开的模态（`_p5_modal`，手机两种布局）：`P5: modal scale`（≥ 1.50）、`modal inside UI area`（画出框——滚动 / 裁剪容器的溢出内容不计——⊂ `_ui_root`）、`modal text`（可见 Label / Button / LineEdit 画出字号 ≥ 21，标签片 ≥ 17）、`modal buttons`（可见 Button 画出高 ≥ 76，主操作 ≥ 83）、`modal sliders tap band >= 70`（规划 B0.4 次操作命中区，比规划多一条）、`primary action bottom-right`（继续 / 离开 / 开始 / 关闭 / 返回菜单 / 选择框底钮，中心 x > 0.6·vw 且 y > 0.6·vh）+ 既有 `_assert_modal`（触控层隐藏、scrim 覆盖整屏）。
  - 访问面：开机菜单态 —— `P5: menu scaled`（`_menu_design.scale ≥ 1.5`）、`menu inside UI area`、`menu text`、`menu buttons >= 76`、`menu pieces pairwise disjoint`；经菜单项**实按**打开 钱包 / 研究室（升级 + 物品档案）/ 星尘商店 / 挑战 / 设置（6 页逐页）→ 整套 + `P5: close path closes`（实按关闭键，面板须关）。Loadout（门自己的开机路径）→ 整套 + `P5: loadout tiles`（每格头像 TextureRect ⊂ 格子）。收尾块（P4 块之后）—— 暂停三页 + `destructive action top-left` + 实按「继续」关闭；大地图；选卡（+ `draft cards in one row inside the panel`、`draft tools left, team right`）；祝福；选择框 pick3 / single / porygon（实按底钮关闭）；喵喵商店（注入 1 件持有物出售行）；结算（最后：`_finish_run`，`back-to-menu wired`，不实按以免重载场景）。每个局内模态前挂长横幅，`P5: banner frozen under <modal>`（P1 冻结规则逐模态）。
  - 桌面：同一访问面，断言 `P5 desktop: modal legacy geometry`（scale 1 + 出货 offsets 宽高）、`menu design unscaled`、`menu starter card keeps its spot`（52,146）。
  - 对既有断言零改动（无主语迁移）。
- 20:13 `Test/uip5_red.sh`（uip4_red 模板，加 h = 1920 s1.00 i48）；VM 本地 `--check-only phonehud.gd` rc=0；`sync_to_nuc.sh` SYNC OK + TREE PARITY OK（101 files），NUC world = `37d1dd68…`（P4 关期树）、phonehud `7acaed9d…`；**红基线**（a 2400 s1.00 i0 / b 1920 s1.50 i48 / c 经典 2400 s1.00 / p P7 hud1.30 mm1.50 2400 s1.50 / d desktop）setsid 启动，8 个 parse 门 rc=0。
- 20:2x 红跑期间的门侧小改（VM 树，未进红跑；仅采样）：`_p5_probe_banner` 先清 `_banner_t` 再挂探针（同 P1 冻结断言的起手），避免挂探针时正好有一条旧横幅在收尾、t0 读到 0。
- 20:4x **红基线 a 2400 s1.00 i0**（P4 关期树 world `37d1dd68…` + P5 门 `7acaed9d…`）：`checks=1647 fails=88` —— **88 条全是 P5 断言，P1–P4 / kept 零误伤**。红的：modal scale ×17（暂停 / 设置 6 页 / 研究室 2 页 / 商店 / 挑战 / 钱包 / 结算 / Loadout；旧 fit clamp 下 1.087–1.37）、modal text ×19、modal buttons ×23（关闭 h=32、设置页开关 34、fps 分段 31.5、背包开关 34.8、继续 / 离开 / 返回菜单不足 83…）、sliders ×5、primary bottom-right ×20（旧树关闭键在左栏或整宽居中）、`destructive action top-left`（回主菜单在底栏右侧 (1202,608)）、`draft tools left, team right`（队伍钮另起一行）、`loadout tiles`（40 格 0 个 TextureRect——旧格子是 Button.icon）、`menu scaled`（无 `_menu_design`）。旧树上即绿的 P5 断言（守护型，预期）：8 条 banner frozen（P1 已建冻结）、11 条 close path、23 条 inside UI area（旧 fit clamp 本就收进屏内）、6 条 modal scale（选卡 1.53 / 祝福 / 选择 / 喵喵 / 大地图 / 钱包以外的高度裁切值恰 ≥ 1.5）、4 条 modal text（选择框 ×3 + 祝福）、Loadout 开始钮右下（旧底栏整宽）、`draft cards in one row`、`result back-to-menu wired`。
- 21:0x（NUC 时钟）**红基线完成**（`Test/out/uip5_red_*`）：
  - a 2400 s1.00 i0：`checks=1647 fails=88`（见上）。
  - b 1920 s1.50 i48：`checks=1548 fails=98` —— 98 条全是 P5。
  - c 经典 2400 s1.00：`checks=896 fails=88` —— 全是 P5（经典角点同样跑手机模态，见 §0 ★）。
  - p P7 hud1.30 / mm1.50 2400 s1.50：`checks=1532 fails=88` —— 全是 P5。
  - **四个手机角点非 P5 失败 = 0**（P1–P4 / kept 零误伤）。
  - d desktop：P5 desktop 断言 20 条全 PASS（旧树即绿 = 守护型：出货 offsets 宽高 + scale 1、菜单未缩放、首张初始卡仍在 (52,146)），但跑到祝福之后撞 900 s（rc=124，无 DONE 行）。**门侧缺陷**：P5 收尾块每步前调 `_p3_ready()`，它等「触控层可见」——桌面变体里触控层不在，每次都空耗满 300 帧守卫（软件 GL 下约 1 分钟 / 次）。修（仅采样）：P5 块改用 `_p5_ready()`（收选卡后只等「无模态 + 游玩态」，同 300 帧上限）。判定未动。
- 21:0x 实现首版（逐项见 §2，终版树为准）。
- 21:1x–22:40 **it1（实现首版树 world `91dce4f0…`、ui_theme `1dd7199a…`、phonehud `4b0dd007…`；NUC `uip5_it1.done` ALLDONE，8 个 parse 门 rc=0）**：a 2400 s1.00 `1554/2`、b 1920 s1.50 i48 `1552/2`、c 经典 `900/2`、p P7 hud1.30/mm1.50 `1536/2`、q P7 hud0.80/mm1.50 1920 s1.50 i48 `1552/2`、h 1920 s1.00 i48 `1651/2`、**d desktop `696/0`**（`_p5_ready()` 修后不再撞 900 s）。（前任会话在 it1 运行期间中断，以下由 2026-10-31 00:1x 续作施工方补记。）红只有三类，全是实现问题、门判定不动：
  1. `P5: menu pieces pairwise disjoint`（六个手机角点）：a/c/p `Label(21,4) × ScrollContainer(21,93)`、b/h `(69,4)×(69,93)`、q `(68,13)×(68,99)`。换算回设计面：Label 在 (8,0) = **标题「SpriteBonk 3D」**，Scroll 在 (8,56) = 首发列。根因：标题字号 40 + 描边 6 时 Label 的最小高（显示字体行盒）> 56，Label 不能比最小尺寸小，`size.y = 50` 被撑高压进首发列。
  2. `P5: modal inside UI area (bigmap/run)`（a b c h p）：面板 y=−6.73、高 733.47 = **448 设计高 × s_m 1.637**（M0 H=430）。抓图 `mobile_p5_bigmap_2400x1080_s100_i0.png` 量得地图方块约 420 设计 px。根因：`BigMap._ready()`（`scripts/big_map.gd:20`）把 `custom_minimum_size` 重设为 420×420，而 world 是在 `add_child` **之前**设的 398 → 被 `_ready` 覆盖；420 + 2×14 边距 = 448 > 430，面板 grow_both 双向撑出 9 设计 px。不是 M0 公式或取整问题（s_m = min(s,(vh−16)/H) 照算，宽 900 = W_max 正确）。
  3. `P5: modal inside UI area (pause/settings)`（**只 q**，派单未列）：x=44.92 < 48、宽 1238.16 = 804 设计 × 1.54（M0 W=784）。q 是唯一 s_m < 1.637 的角点（hud 0.80 → s≈1.54，字号地板 14、按钮地板 50，且 W 更宽）；只有暂停「设置」页红，状态 / 图例页同角点绿 → 溢出件在快捷行里。静态推算定位不到确切件（滑条长度两处同口径），门里加 INFO 诊断（`_p5_dump_min`，仅在 inside 失败时打印子树最小尺寸，不改判定）后单跑实测。
- 00:2x **修**（只动实现）：① `world.gd` 菜单：`UiTheme.outline(sub, 3)` 之后，手机分支按实测 `title.get_minimum_size().y ≤ 54` 把标题字号从 40 步降（下限 30），尺寸取最小高，副标题 x 跟随新字宽；② `world.gd` `_build_bigmap`：手机分支在 `hb.add_child(_bigmap)` **之后**再设 398×398（桌面保持原状——桌面一直是被 `_ready` 改成的 420，`P5 desktop: modal legacy geometry` 守着不动）。③ q 暂停/设置：待诊断跑。
- 00:2x **it2q**（a + q 单跑，树 = 上述 ①② + 门 INFO 诊断；SYNC OK + TREE PARITY OK 102 files）：a 菜单出现**新相交** `Panel(21,637) × Label(36,642)` = 底部操作提示的玻璃背板 × 提示文字。it1 未暴露是因为门的相交扫描遇第一对即 break（标题那对在前）。根因：提示 Label 字号被地板抬到 14 后两行最小高 > 42，Label 撑出 48 高背板，不再被包住（门对「背板包住标签」有豁免，不包住即算相交）。修（`world.gd` `_p5_layout_menu` 尾）：套完地板后按 `_menu_hint.get_minimum_size().y` 回算——背板底贴设计面底 450、顶 ∈ [396, 400]（首发列底 394 之下）、标签在背板内 3 px。
- 00:3x it2q 的 **a 撞 900 s（rc=124）**：日志 PHONEHUD 行数已越过 it1 的选卡抓图，块缓冲尾部随 kill 丢失——不是挂死。原因：it1 a 本就跑了约 14 分钟（21:21→21:35，贴着上限），此刻 NUC load ≈ 9.3（8 核；他人长跑的 Chrome 渲染进程占 ~1.7 核，非本任务所有，未动）。处置（只动上限，不动判定）：`Test/uip5_red.sh` 单跑上限 900 → 1500 s；`Test/check_phonehud.sh` 单跑上限 900 → `${PH_TIMEOUT:-1500}`（改前副本 `.tmp/check_phonehud.sh.p5pre`）——P5 收尾块每跑多约 6 分钟，终版矩阵在 900 s 下同样会被负载掐断。
- 00:48–01:1x **it2r（仅 q，诊断跑；NUC load 一度 24）**：q 在 1500 s 下仍 rc=124（负载），但 INFO 诊断在被掐前已落盘，定案 **红 3 = 暂停页签「左栏」并未竖排**：`UiTheme.make_segmented` 返回 `HBoxContainer`，首版的 `seg.vertical = true` 在 Godot 4.3 只报 `ERROR: Can't change orientation of HBoxContainer`（a / q 日志里那条）、不生效 → 三个页签横排成 160 宽（非 120）。q（s_m 1.54 → W 784）可用内宽 756，而 页签 160 + 间距 12 + 页面 604（快捷行 596 + 滚动条 8；行内滑条借设置面板预算 358）= 776 → 面板撑到 804，左缘 44.9 < 48。其余角点 W 更小或 s_m 更大时字号地板低、行更窄，恰好放得下。
- 01:1x **修（只动实现）**：① 删掉无效的 `seg.vertical = true`（页签组保持一行、放在左列——`make_segmented` / `set_segmented` 与 P1 门 `phonehud.gd:1015` 都钉死 HBoxContainer 类型，门不动，见 §3 ★）；② `_st_slider`：暂停页快捷行（`_pause_panel` 的子孙）滑条最小长度用通用下限 220、靠 EXPAND_FILL 伸满页面（宽屏仍 ≥ 360），设置面板照旧 `_p5_slider_len()`。迭代脚本单跑上限再放到 2400 s（负载）。
- 01:16 修复树同步（SYNC OK + TREE PARITY OK 102 files）→ **it2（a b c h p q d）** setsid 启动（`uip5_it2.done`）。

### 2. P5 实现清单（file:line，以当前树为准；终版若再动会更新。2026-10-31 00:3x 续作施工方按 `.tmp/p5_baseline/` diff 补写）

改动文件只有两个：`scripts/world.gd`（基线 `37d1dd68…` → 首版 `91dce4f0…` → 本轮修复树）、`scripts/ui_theme.gd`（`72a2d09e…` → `1dd7199a…`）。touch_controls / ui_icon / player / profile 等未动。

| 规划项 | 实现 | 位置 |
|---|---|---|
| 状态：`_p5_on`（构建时取手机系数 > 1.01，D6 经典同样生效）、`_p5_spec`（面板 → (W_max, H_design)）、dirty / 可见签名、`_menu_design`、`_menu_starters`、喵喵金币标签、Loadout 队伍提示 | 加 | `world.gd:517-529`；构建时置位 + `node_added` 挂钩 `:2765` |
| §B3 M0 设计尺寸登记（13 个模态：选卡 985×420、祝福 985×400、选择 860×360、喵喵 985×430、暂停 1000×430、大地图 900×430、结算 960×430、研究室 / 星尘商店 820×430、挑战 / 设置 900×430、钱包 640×430、Loadout 各页 4000×440 = 宽度随安全区流动） | `_build_hud` | `world.gd:3455-3471` |
| 从菜单直接开的模态（研究室 / 商店 / 挑战 / 钱包）不经 `_apply_ui_scale` → 开机时放置一次模态族 + 菜单 | `_build_hud` 尾 | `world.gd:3513-3520` |
| M0：s_m = min(s, (vh−16)/H)、W = min(W_max, (vw−24)/s_m)，均在 `_ui_root`（安全区）空间、居中、支点 = 中心；替代旧 fit clamp（桌面 / 非登记节点仍走旧路径） | `_p5_place_modal`；`_apply_ui_scale` 分流 | `world.gd:12959`；`:12913` |
| W 变化时重排随宽内容（选卡 / 祝福 / 喵喵 / Loadout） | `_p5_relayout` | `world.gd:12980` |
| §B0.4/§B0.5 地板（画出 px）：正文 21、标签片 17、按钮 76、主操作 83（meta `p5_primary`）、滑条 / 拖动带 70；开关按 k 倍放大；原值存 meta，幂等 | 常量 + `_p5_floor_font` / `_p5_fit` | `world.gd:12935-12941`, `:13004` |
| 内容重建 / 模态刚打开 → 当帧重套地板 | `_p5_node_added` / `_p5_tick`（`_process` 挂点） | `world.gd:13047`, `:13053`；挂点 `:12239` |
| 图标按钮文字随地板字号重算宽度；开关按 k 放大（knob / 圆角同比） | `UiTheme.set_icon_button_text`（meta `fs_over`）、`set_switch` / `size_switch`（meta `sw_k`） | `ui_theme.gd:323-325`, `:496-521` |
| §B3 G1–G6 主菜单：全部菜单件挂到设计面 `_menu_design`（桌面 = 全屏、scale 1、坐标不变）；手机 = 450 高设计面 × s_menu = min(s, (vh−8)/450) 居中；标题行（字号按行盒步降，见下）、首发列滚动（联盟解锁续在同一滚动内）、六项 52 高、hero 卡宽 ≥ 240 才显示（16:9 隐）、底部操作提示整宽两行 | `_build_menu` 手机分支 + `_p5_layout_menu` | `world.gd:3731-3760`, `:3763-3790`, `:3812-3818`, `:3828`, `:3896`, `:3909-3922`；`_menu_item` `:3619`；首发卡窄版 `:3684`；`_p5_layout_menu` `:13075`，挂点 `:12926` |
| **修（it1 红 1）** 标题字号 40 起按实测 `get_minimum_size().y ≤ 54` 步降，尺寸取最小高，副标题 x 跟随 | `_build_menu` | `world.gd:3748-3760` |
| 钱包：关闭钮移到底部右侧（主操作）、余额 / 说明换行 | `_build_wallet` | `world.gd:4051-4057` |
| 研究室 / 星尘商店 / 挑战：列表滚动吃满固定高、关闭钮右下主操作；商店名列可缩、挑战标题换行 | `_p5_overlay` | `world.gd:15553`；挂点 `:4175`, `:4413-4425`, `:4823` |
| §B3 G11 设置：六页签在左栏、页面在右列滚动、关闭右下主操作；标签列 170 可换行、滑条 ≥ 360（16:9 按页宽收，下限 220）；控制页「暂停」文案随新布局改「点左上头像」 | `_build_settings` / `_st_row` / `_st_slider` / `_p5_slider_len` | `world.gd:4540-4556`, `:4596-4602`, `:4631`, `:4706` |
| §B3 M1 选卡：已持有小片横向单行滚动；工具行 = 重抽 / 跳过 / 放逐在左、我的队伍在右；卡 220×230（四张挤 16:9 时按宽均分 `_p5_card_w`）；触控下无键帽 | `_build_draft` / `_render_draft` | `world.gd:4881`, `:4916`, `:5135`, `:5228`；`_p5_card_w` `:15567` |
| §B3 M2 祝福：卡宽 220（同均分）、队伍钮靠右、触控无键帽 | `_render_blessing` | `world.gd:9977`, `:10014`, `:10079` |
| §B3 M3 选择框：标题 + 副标题一行；选项卡 240×200（均分）；底钮（全部出售 / 离开）右下主操作、不整宽 | `_build_choice` / `_choice_show` | `world.gd:7493`, `:7514`, `:7532` |
| §B3 M4 喵喵：头行 = 台词 + 右侧大号金币；库存卡 190 高（均分）；底行 = 更新库存左、出售片横向滚动居中、离开右下主操作 | `_build_meowth` / `_shop_refresh` | `world.gd:7416`, `:7443`, `:7290`, `:7309` |
| §B3 M5 暂停：页签变左栏（120 宽）、页面填满；继续右下主操作；回主菜单（两步确认照旧）移到左上标题旁；状态页文本按页宽换行 | `_build_pause` / `_pause_fill_status` | `world.gd:15294`, `:15362`；`_p5_wrap_page` `:15575` |
| §B3 M6 大地图：左侧 398 方图、右栏随宽、关闭右下主操作 | `_build_bigmap` | `world.gd:15695` |
| **修（it1 红 2）** `BigMap._ready()` 会把最小尺寸重设为 420 → 手机分支在 `add_child` 之后重设 398（桌面不动） | `_build_bigmap` | `world.gd:15705-15709` |
| §B3 M7 结算：两栏（左 = 大标题 + 摘要，右 = 滚动明细）、返回菜单右下主操作；明细条宽 160、文本换行 | `_build_result` / `_show_result` | `world.gd:5439`, `:15151`, `:15224` |
| §B3 G12 Loadout 全屏：详情 38% / 右侧 62%；队伍提示移到行上方；背包开关横向单行滚动；返回左、开始右下主操作；网格列 = floor(右宽 / 120)，112×112 格、头像 TextureRect 收进格内（原 Button.icon 溢出） | `_build_loadout` / `_loadout_*` | `world.gd:16155-16171`, `:16191`, `:16213`, `:16435`, `:16504` |
| 门 | phonehud P5 段（`_p5_*`，含菜单块、Loadout、收尾块、桌面守护）+ `_p5_ready()`（桌面变体不等触控层）+ 本轮 INFO 诊断 `_p5_dump_min`（仅 inside 失败时打印，不改判定） | `Test/phonehud.gd:2965-3510`；挂点 `:301` 等 |
| 脚本 | `Test/uip5_red.sh`（迭代角点，含 h）、`Test/uip5_batch.sh`（终版，uip4_batch 模板，20:24 已建） | — |

### 3. 与规划 / 派单的偏差及理由（待主控裁定的标 ★）

0. ★ 模态手机形态跟随手机系数、经典布局（D6）同样生效（§0 范围判定第 1 条）。
1. ★ 模态族不新增「点外部 / 返回键」关闭语义（§0 范围判定第 2 条；Android 返回键 = 默认退出应用，规划未定义，未改）。
2. ★ **暂停页签不是竖排 120 宽左栏，而是放在左列的一行三钮**（规划 §B3 M5「页签变左栏」）：`UiTheme.make_segmented` 返回 `HBoxContainer`（方向不可改），`set_segmented` 与 P1 门（`phonehud.gd:1015` `get_meta("seg") as HBoxContainer`，门不动）都钉死该类型；若换成 VBox，P1「pause tabs」断言会失去页签读数。效果：页签仍在左侧拇指侧、页面在右侧填满，主操作「继续」右下、「回主菜单」左上，P5 全部断言照判；代价是左列 ~160 设计宽（三钮横排）而非 120。若主控要竖排，需要同时改门的那一行类型（属门改动，须另批）。
3. 暂停页快捷行的滑条最小长度取通用下限 220（伸满页面），不套设置面板 G11 的 ≥ 360 预算：快捷行与页签列并排，页面比设置页窄；宽屏下实际长度仍 ≥ 360。
4. 主菜单标题字号随显示字体行盒步降（40 起，最低 30），保证标题行不压进首发列；hero 卡在 16:9 隐藏（宽 < 240 设计 px，同一物种信息在 Loadout 页一触可达）。
5. 喵喵 / 选择 / 选卡 / 祝福卡宽在放不下时按面板 W 均分（16:9 四张），不固定规划卡宽。
6. 测试侧（判定不放宽）：桌面变体改用 `_p5_ready()`（不等触控层）；`_p5_dump_min` 仅在 inside 失败时打 INFO；`Test/check_phonehud.sh` / `Test/uip5_red.sh` 单跑上限由 900 s 放宽到 1500 / 2400 s（P5 收尾块 + NUC 被他人任务压到 load 9–24）。

### 4. 关期修复单：抽屉两条在 uiScale 0.70 / 0.85 全红（2026-11-03 派发，官方 Claude Code 施工方，2026-11-05 施工）

**输入**：P5 终版批第二轮（11-02 19:07 → 11-03 05:42）矩阵 42 组合 19 红 = 全部 s0.70 / s0.85（含 P7 角点 `2340 s0.85 右48 h1.30 m0.75`）；suite 514/1（唯一红 = F3 宝箱夹具签名，不在本单）。证据：VM 上 `Test/out/phonehud_touch_2400x1080_{s070_i0,s070_i48_0_0_0,s085_i0}_ubantu.log` + `uip5_matrix_ubantu.log`。对照基线 `.tmp/p5_baseline/`（= P4 终态）、`uip4_*` / `uip3_*` 日志。

**根因（实证，按证据链）**：
1. **抽屉高度是 cap 定的，不是内容定的**。抽屉宽 416 = 320×s_col 1.30（各 scale 相同），高 = min(内容, Z 上限)，Z = 抽屉 x 段下方拇指簇件顶 − 8（`world.gd:14036-14038`）。P3 / P4 日志 s0.70 与 s0.85 抽屉都是 `S: (416, 488.8)`（内容 376 设计 px，未触 cap）、底 498.8，门的「抽屉外」采样点 (0.6·vw, 0.7·vh) = (960, 504) 在其下 5 px。P5 终版：s0.85 高 510.6（底 520.6 = lock 顶 528.6 − 8，lock x 1337–1407 与抽屉 x 935–1351 相交，**正是 cap**），s0.70 高 555.1（底 565.1，cap 来自更低的簇件）——内容涨过了 cap。
2. **内容多出的一行 = 「喵喵在拜访」**。同组合 `P3: three events injected`：P4 `events=3`，P5 `events=4`；`no alpha pill while bar visible (drawer_open)` 列表 P5 多出「喵喵在拜访」；`drawer lists all` texts 11 → 13（标题 + 副行各一）。
3. **为什么 P5 才稳定出现**：门在 boss 态 `Test/phonehud.gd:383` 把 `zone` 设成 3；`_event_list` 读 `_inter_state[zone]` 里的喵喵道具（`world.gd:16024-16028`），而 `_inter_state[3]` 只在菜单期预建（`_prebuild_scenes`，`world.gd:10373` 起）建完 3 区后才存在。P4 及以前门开机即开局，预建被 start_game 打断，日志无 `C12 prebuild` 行 → 3 区无道具状态 → 无喵喵行；P5 门新增开机菜单块（`_p5_menu_block`，`phonehud.gd:301`）在菜单停留，预建跑完（P5 日志 `C12 prebuild: zone 2/3/4 scene cached`，行 50/74/107）→ 每跑必有喵喵行。P3 记录里的「随机第 4 事件」（`uip3`/`uip4` 少数组合 events=4）即预建恰好建到 3 区的情形；那些组合都在 s1.00 / s1.50，cap 高，抽屉底仍在 504 之上，所以从未红。真机上玩家必在菜单停留，预建必完成——P5 门的状态才是真实状态。
4. **两种红法是同一几何**：s0.85：点 (960,504) 落在抽屉内（y 10–520.6）→ 只重置 4 s 计时、不收 → `tap outside` FAIL；随后「4 s 自动收起」那一步点目标 pill = 再点一次 → 抽屉被**切换关闭** → `open=false 3.4s=false 4.6s=false`。s0.70：抽屉更高，页脚「查看全部挑战」按钮 = [953.4–1333 × 476.7–546.9]，(960,504) **正落在按钮上** → 打开只读挑战页并暂停，抽屉因此关闭（`tap outside` 记 PASS），之后 `_p3_ready()` 等不到无模态，空转到 1500 s 超时——VM 上 s070 两份日志都截断在 `tap outside closes the drawer` PASS 行之后、无 DONE 行（矩阵记 FAIL），mtime 间隔 ≈ 24 min 与超时吻合。
5. **实现层的缺口**：规划 R4f 是 CONTEXTUALIZE「进入区和喵喵在 30 u 内时进抽屉，常驻 pill 不再挂它」（规划 §B2 表 R4f，审计行 :91「整区常驻，信息量随时间趋近 0」）；P3 实现只做了「pill 兜底」那半，**30 u 条件没落地**——只要本区有喵喵（PROP_PLAN 每区必放 1 个），抽屉就常挂这一行。

**门的采样口径（报主控，未改门）**：(0.6·vw, 0.7·vh) 不是规划保证的「抽屉外」点——规划只约束抽屉底 ≤ 下方簇件顶 − 8、超高滚动。只要抽屉有 ≥ 4 行事件（真实同时在场的阶段事件 + 闪光 / 联盟 + 彗星 + 虫群 + 阿尔法 + 近处喵喵都可能），s ≤ 0.85 时抽屉就会合法地盖到该点；s0.70 还会让该点落在「查看全部挑战」上，触发暂停模态并让门空转到超时（不是红，是挂死）。本单按约束不动门；建议主控裁定是否把采样点改为「抽屉画出框下方 / 左侧、且不在任何控件上」（同 P3 类 C 的取点规则，判定不变）。

**修（只动实现，门一字未改）**：`scripts/world.gd:16021-16033` + `:16055-16062`——R4f 落地：新布局（手机 `_event_list(true)`，即目标 pill / 抽屉）只在玩家与本区喵喵平面距离 ≤ 30 u（`P3_MEOWTH_NEAR`，`_p3_meowth_near`）时列「喵喵在拜访」；桌面 / 经典 pill 栈（`_event_list(false)`）照 cycle 21 bundle 行为整区常驻，不变。pill 与抽屉都走 0.15 s HUD tick 的签名刷新，进出 30 u 当 tick 生效。「进入区」按「本区（live zone）的喵喵」解读；规划未给「进区后短时提示」的时长，未自造计时（★ 待主控裁定是否要）。不碰玩法规则（喵喵道具、商店、交互半径均未动）。
- 树：world `0063e739…`（改前 = P5 终版批树）；VM `--check-only world.gd` rc=0；sync SYNC OK + TREE PARITY OK（103 files）。
- 跑脚本：`Test/uip5d_fix.sh`（uip5_red 模板：argv0 锚定守卫、parse 门、2400 s / 20 MB 上限；`s1` = 两个点名红，`s2` = 19 红 + a 对照；每组合判定 + 抽屉证据行写 `Test/out/uip5d_<stage>.done`）。
- 11-05 00:42 NUC `s1` 启动（setsid，load ≈ 2，无其他 Godot）。

#### 11-05 Codex 续作交接（本会话受网络沙箱阻塞，尚未定案）

- 派单所报 s1 结果（尚未从 NUC 拉回独立复核）：00:42–01:07，`Test/out/uip5d_s1.done` ALLDONE 01:07:31；s085 左48 `1642/0`，s070 i0 `1530/3`，抽屉两条均转绿。残余签名：`drawer opens all challenges paused :: state=draft unlock=false`、`closing the challenge list returns to pause :: state=draft pause=false`、`camera swipe across the lock keeps turning :: lock=[P: (1377.4, 556.2), S: (70, 70)] from=(1307.4, 591.2) dyaw=-0.3 expect~-0.6`。
- 已完整读取 §4 并静态核对 `Test/phonehud.gd` 的 `_p3_phone_block` / `_p3_ready`：P3 块入口冻结经验；挑战按钮发信号前经过 `_p3_tap` 的异步帧等待；镜头样本从 lock 左侧70处起，每次20共6次拖动。以上仅为待查位置，不能证明升级来源或镜头损失根因，未据此修改实现或门。
- 实际阻塞：执行既有 `Test/nuc_ssh.sh lgh@100.124.16.117 'cd ~/workspace/sprite-bonk-3d && cat Test/out/uip5d_s1.done'`，`tsproxy.py:7` 的 `socket.create_connection` 在本机即报 `PermissionError: [Errno 1] Operation not permitted`，SSH 未连接。当前会话网络受限且禁止权限升级；本地 `Test/out/uip5d*` 无副本。因此未取得 s1 时序日志、未同步、未启动任何新 NUC 阶段，不能报告新增测试数字。
- 下一步：在可访问 NUC 的施工会话先用既有 pull 脚本拉回 `uip5d_s1*`，逐条实证定案并修复；逐个脚本 parse 门、sync + TREE PARITY 后，setsid 启动 s070 单跑并等其 done 落盘全绿，再跑 `Test/uip5d_fix.sh s2`（等 `Test/out/uip5d_s2.done` ALLDONE），增量记录后启动 `Test/uip5_batch.sh`（等 `Test/out/uip5_batch.done` 本轮 ALLDONE；11-03 旧文件不能当新证据）。s070 单跑须使用独立 done 名，保留原 s1 证据。s2 与终版批本会话均未启动。
- 本会话只续写此交接；玩法、门判定、DIFF.md、R4f 实现均未改，无 APK，无 reference 入树。

#### 11-05 19:30 p5fix6 续作实测断点（网络仍被当前会话沙箱拒绝）

- 已按续单先执行既有拉取脚本：`bash Test/pull_from_nuc.sh p5fix6_s1 'uip5d_s1*'`。5 次 manifest 获取全部在本机 `tsproxy.py:7` → `socket.create_connection` → `_socket.socket.__init__` 报 `PermissionError: [Errno 1] Operation not permitted`，SSH 未连到 NUC；脚本最终退出码 **3**。证据：`Test/out/p5fix6_s1_pull.log`；`Test/out/p5fix6_s1_pull.done` = `RC=3`。这不是 NUC 测试结果，未取得任何 s1 日志。
- 当前会话实际权限仍为 network restricted / approval never，与派单「已放行网络」不符；无法通过当前工具申请提权。未把静态待查位置升级为根因结论，3 红仍待日志实证；实现与门均未改，未执行 sync / TREE PARITY，未启动 s070、s2 或终版批。
- 续作从拉取 `uip5d_s1*` 重试开始；成功后逐条定案、修复、逐个 `--check-only`、sync + TREE PARITY，再 setsid 启动独立 done 名的 s070 单跑并等待全绿；随后 `Test/uip5d_fix.sh s2` 等 `Test/out/uip5d_s2.done` ALLDONE 全绿；最后 `Test/uip5_batch.sh` 等本轮 `Test/out/uip5_batch.done` ALLDONE（11-03 旧批不计）。原 s1 证据保留。玩法规则、DIFF.md 未动，无 APK，无 reference 入树。

#### 11-05 p5fix7 续作（网络已实通，进行中）

- 既有拉取脚本 `bash Test/pull_from_nuc.sh p5fix7_s1 'uip5d_s1*'` 成功：`Test/out/p5fix7_s1_pull.done` = `RC=0 files=3 bytes=1592670`，逐文件大小核验；s1 原始 done + 两份日志均已到 VM。独立核实 s070 `checks=1530 fails=3`、s085 左48 `checks=1642 fails=0`，s1 ALLDONE `2026-11-05T01:07:31+08:00`；原抽屉两条均绿。
- s070 原日志 :1050–1058：抽屉外点关闭 PASS、4 s 自动关闭 PASS，随后挑战打开/关闭两条均 `state=draft`，镜头 `dyaw=-0.3`。日志未含 draft 触发帧或拖动分步状态，不能据此认定升级来源。为补足实证，在 `Test/phonehud.gd` 加 P3 fixture 状态/经验倍率/等级/待升级数变更、挑战取样前状态及镜头逐步增量的 INFO，只观察、不改断言/夹具/实现。
- `Test/uip5d_fix.sh` 加独立 `s070_<unique-tag>` 单跑入口，并拒绝其他未知 stage（保留 s1/s2 原组合）；shell 语法通过。改动 Godot 脚本逐个 check-only：`Test/phonehud.gd` VM rc=0（XDG 路径置于 `.tmp/p5fix7_xdg`；默认 user 日志目录在本会话不可写，首次引擎启动 rc=134，改可写路径后正常）；NUC runner 四个 parse 门均 rc=0。
- sync `Test/out/p5fix7_diag_sync.log`：SYNC OK + TREE PARITY OK（103 files）。NUC setsid 于 `2026-11-05T19:34:34+08:00` 启动诊断 s070，独立 done=`Test/out/uip5d_s070_p5fix7diag.done`，日志同前缀，原 s1 完整保留；正在会话内轮询，尚未完成、尚未定案。s2 与终版批未启动。

- 诊断 s070 完成：`uip5d_s070_p5fix7diag.done` ALLDONE `2026-11-05T19:44:17+08:00`，`rc=0 checks=1642 fails=0`；拉取 `p5fix7_diag` 验证 `3 files / 802049 bytes`。本轮挑战点击后 `state=guardian drawer=true xp_mult=0 pending=0`；镜头六步 `−0.1/−0.2/−0.3/−0.4/−0.5/−0.6`，全程 guardian，无输入丢失；恢复 xp_mult 后第559帧才见 level3/pending1，第560帧 draft。此轮仅复核随机性，不作修复完成证据。INFO 中 guardian 布尔项误读 `_guardian`（实际字段 `guardian`），该项无效，不作为证据，后续修正；state/XP/镜头字段有效。
- 为检验异步采样窗口，已在 `.tmp/p5fix7_probe.{gd,tscn,sh}` 准备受控探针（继承原门、只跑 P3）：挑战第三次 objective tap 等待中及镜头第三次拖动后各调用真实 `player.gain_level()`（同守护者经验糖直接升级路径，不受 xp_mult=0 限制）。该探针有意制造升级时序，不属官方组合，不声称还原 s1 的具体升级奖励来源。VM check-only rc=0；NUC setsid 启动，done=`Test/out/uip5d_s070_p5fix7probe.done`，待完整落盘。

##### 残余三红定案与采样修法（p5fix7，受控实证；不倒推未记录的奖励来源）

- 受控原门探针 `uip5d_s070_p5fix7probe.done` 于 `2026-11-05T19:48:13+08:00` ALLDONE：精确复现三个原签名。挑战点击前 `xp_mult=0 pending=0 state=playing`，直接 `gain_level()` 后第94帧 draft，点击返回时 `drawer=false`；随后打开 / 返回两条均为原样 FAIL。镜头前两步 −0.1/−0.2，第三步后直接升级，第159帧 draft，此时累计 −0.3，后三步全停在 −0.3。证明经验冻结只覆盖 `gain_xp`，并不冻结 `gain_level` / pending_levels 的升级序列；原门在 `_p3_ready` 之后还跨异步帧，不能保证取样期间仍无升级模态。
- **① `drawer opens all challenges paused`：门采样问题。** s1 日志 :1052 实际采的是 draft，非从游玩态打开挑战。受控探针在 objective tap 等待中插入真实升级路径，完全复现 `state=draft unlock=false`；实现 `_obj_open_challenges` 对升级态不打开挑战是正确模态互斥。修：`_p3_challenge_sample` 在点击等待结束核对是否被外来模态打断，仅被打断时结清后重开抽屉（4 次上限），再在同一无 await 帧取按钮并发信号。原 `_check` 条件一字不动。
- **② `closing the challenge list returns to pause`：同一失效采样的连带红。** s1 :1053 与探针均仍是 draft，前一步从未打开挑战，因而没有有效的「挑战→暂停」返回可测。修同①，关闭路径及原状态/面板可见性条件完全保留。
- **③ `camera swipe across the lock keeps turning`：升级模态打断的门采样问题，不是已证的 lock 几何或帧率折损。** 正常诊断同起点/矩形/拖动参数六次各 −0.1；受控探针在第三步插入升级后精确复现 −0.3，后续 `_input` 正确被 `_any_modal_open()` 屏蔽。修：仅在采样期间观察到外来模态时，释放本触点、结清模态并重采整组六步（4 次上限）；无模态的输入失败直接保留原结果，不按数值重试。起点 lock 左70、每步20共6次、相对镜头阈值 `[−0.75·cs, −0.45·cs]` 和原 `_check` 一字未改。
- 夹具补强：P3 每次等待结清升级后重新 pin 原有 `xp_mult=0 / xp=0`，因为结清升级时 recalc 可重建倍率；不清 pending_levels、不跳过升级、不改变实现与玩法。INFO 保留可审计的中断/逐步状态；guardian 字段已改读正确字段。
- **证据边界**：s1 没有升级触发帧、pending 或奖励调用栈，不能唯一确认它来自守护者经验糖、已有 pending，还是 recalc 后战斗经验；本记录不把某种奖励来源写成已实证。已实证的是 s1 两条状态被 draft 污染、受控合法升级路径能精确重现全部三条，且同几何正常六步无损；修复针对这个采样窗口。
- 226 个 `_check(...)` 调用与 p5fix7 修改前逐字全等（完整调用文本 SHA256 `8bceaca7f7b141f07c4327854925092e63408d03db8fa7ae5e0f1d45557d1ed7`）。VM `--check-only Test/phonehud.gd` rc=0，shell 语法门通过；实现文件与 DIFF.md 未改。接下来先同探针验证修复，再独立正式 s070 单跑，均等 done 后推进。

### 5. P5 关期（2026-11-06 23:2x，主控验收关期）

- **关期证据链（全部本轮新跑、日志已拉回校验）**：
  - 修复验证探针（2026-11-05 21:54，NUC `uip5d_s1.done`）：s070 i0 与 s085 i48 两组各 `checks=126 fails=0`——§4 的采样修复（外来模态打断时结清重采、判定逐字未动，226 个 `_check` 调用 SHA256 与修前全等）在受控升级插入下成立。
  - s070 正式单跑（2026-11-06 03:58，`uip5d_s070_final.done`）：`checks=1626 fails=0` ALLDONE。
  - s2（19 红组合 + a 对照，2026-11-06 10:00，`uip5d_s2.done`）：20 组合全 rc=0、ALLDONE，P5 终版批第二轮的那 19 个小 scale 红组合全部清零。
  - 终版批（2026-11-06 10:02–17:08，`uip5_batch.done`）：parse 门 9/9 rc=0、import rc=0、class cache rc=0、**suite rc=0（514/0，连 C22-F3 宝箱夹具本轮亦过）**、**bootsmoke rc=0**；matrix rc=1 的唯一成因 = 组合 2340x1080 s1.50 i0 的日志 1491 条 PASS、0 FAIL，但进程死于引擎已知退出挂起（日志尾为 StringName unref BUG 行）、未打出 DONE 行而被 runner 记 FAIL。
  - 该组合单独重跑裁定（2026-11-06 22:04，`uip5_solo2340.done`，日志已拉回校验）：`rc=0 PHONEHUD DONE checks=1536 fails=0`。**矩阵据此按 42/42 全绿计**（41 组合批内绿 + 此组合批内零断言红、同树单独重跑全绿）。
- **§4 根因归档**：抽屉回归的真根因 = P5 新增开局菜单驻留使场景预构建跑完，`_event_list` 把整区常驻的「喵喵在拜访」行列入手机抽屉，抽屉在小 scale 下被 cap 顶满、盖住门的点外采样点（实现侧已按规划 R4f 落地 30u 近接条件，world `0063e739…`）；残余 3 红 = 升级 draft 模态污染门采样（§4 p5fix7 定案与采样修法）。P3 关期时记录的「随机第 4 事件」残留同源（预构建偶达 zone 3），至此一并结案。
- **主控自记更正**：2026-11-01/02 对抽屉两红「负载夹具假象」的裁定错误（19 红为确定性小 scale 真回归），已于 2026-11-03 向用户更正；本关期注再次归档，不改写历史段落。
- **施工方变更归档**：P5 关期修复的定案与采样修复（p5fix7）由 Codex 号池完成——官方 Claude 通道 2026-11-05 起被 Anthropic 验证门户拦截（账号侧状态、非额度），用户 2026-11-05 17:50 拍板改道、2026-11-06 00:28 决定不做 Persona 验证（X 上有验证后封禁的报告）。**五期全程序独立审计因此欠账**：待 Claude 通道恢复（或经 Antigravity 的 Opus 通道实测可用）后第一优先补审，补审前不宣称已过审计。
- **记录在案的门残留**：门的点外采样点 (0.6·vw, 0.7·vh) 不是规划保证的抽屉外点；合法高抽屉（≥4 事件、小 scale）可覆盖该点甚至把挑战按钮压到其下并挂死 harness（s070 1500s 超时即此）。本轮按裁定以 R4f 近接条件消除常驻行，未改采样点；后续若新增常驻事件行，须先复核该采样点。
- P5 至此关期；手机 UI 适配五期（P1–P5）全部关期。终版 APK 构建与交付见本注之后的构建记录。
- **终版 APK 构建记录（2026-11-06 23:22，NUC 构建）**：`android/build_apk.sh` rc=0；`build/android/SpriteBonk.apk` = 57,725,012 B，sha256 `2309e7e53913706b94036ae16a9dd6fe1af7c661124567b8479957289f56a09a`（拉回本地后哈希复核一致）；apksigner 证书 SHA-256 `b05b80e1…a232` 与历版一致；包内审计：`reference/` = 0、`Test/` = 0（`.godot/imported` 为引擎导出资源、与历版同构）。已上传 Muse 文件存储交付用户真机验收（链接 2026-11-08 23:28 CST 过期）。注：本包仍含开发占位 IP 数据，系 UI 程序终版验收包、非商店提交包（换皮仍为上架前最后一关，口径不变）。
