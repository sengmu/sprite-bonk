# C24 施工记录（2026-11-09）

基线 dd0ae45（C23B2，suite 658/0）。先完整读取 pack 闪光 §3（派单称 §4）、融合 §4、化石 §6及 addendum；addendum没有新增这三系统规则。DIFF.md不改，reference/不入树，不建APK。

## 证据、边界与规格差异

- 使用 addendum 所列只读 main/news 镜像；融合提取器校验 main SHA256 `4b4a76ddd47d60167f4a330250cee58f036dc68d2efa692aaecd9638249d2d7e`。原料不复制进项目。
- Classic池：main @1051478 `classicPool()`对现有classics扩展家族集合，然后筛 `Ae(e.id,t).some(e=>!n.has(e))`，没有“必须已拥有Classic的家族”正向条件。pack §3b文字该处反向；按连续原文施工，已有家族Classic排除，未有者可进池。传奇/幻兽排除。
- 原文要求animated sprite；3D端以ModelRig支持的现有模型作为能力门。Classic的PMD atlas无3D资产，选用既有apply_shiny色相变换是**移植表现选择**，不宣称还原Classic调色板。没有co-op模式，未新增co-op玩法。
- Dome的pool×1.5：原文祝福生成器 Xx 的 `pe[tier]*r`，乘祝福效果，不乘候选数量；数量仍3，minTier4，picks1。
- 融合原料SC实际106条（79签名、18类型、8反应、1 glitch）；pack称82签名的额外3条 **UNPROVEN**，不补造。详见 c24-fusion-data.md。
- amber只有142/25%/色值等元数据，模型未定版，buildable=false，无选项、无节点、无招募执行；不借其他模型。
- helix/dome遗迹使用两件化石道具石刻；不是Omanyte/Kabuto生物替身模型。原文选中后升起旋转、.5s叫声、.6s隐藏其他、.8s奖励。

## ① 游戏代码 / 数据变更（与检查分列）

- scripts/profile.gd：版本4，旧档classics数组/skins字典容错；shinies/classics记录推导家族皮肤可用性；按家族存选择，只可选择已进Liga且可用皮肤；Classic Ae按roster成员/非member家族展开（106/107隔离），新+200重复0，立即存档。闪光原有120/50支付保留。
- scripts/player.gd：创建/进化模型时应用已选家族皮肤；Classic使用已声明的3D色相替代。
- scripts/enemy.gd：Classic独立标识、ally_slot；闪光队友伤害独立×1.2；保持原阈值计数增长（取现有bond与跨过阈值数较大值），初始2不叠加成7。
- scripts/world.gd：闪光收服转队友（初始羁绊0/2、slot10+serial%100）；已有闪光时选择保留/放生新队友，仅一只。Classic分区roll与60–420秒调度、Cx加权/HP×2.5/独立捕获记录/seen、逃跑时钟、不加入Liga或队友；统一闪光→Classic→Liga调度与忙时保留时点，两种直接生成入口也互斥；普通捕获/孵蛋容量排除闪光；化石每区一处、交互、新局视觉重置、结算计数及祝福强度参数/队列传递。
- scripts/fossils.gd：helix/dome/amber数据、两个可用报价、取消无消耗、单次献祭、实际最大HP乘.85/.8、延迟奖励、两件道具视觉与动画；amber强制拒绝执行。
- assets/data/fusions.json、assets/data/fusion_rules.json：已证融合表与参数/规则数据；无融合引擎、无UI、无cast执行。

## ② 检查 / 工具 / 记录变更

- Test/harness.gd：C20忙时等待和收服后swap结清fixture；props精确55/17含化石1；联盟池Magikarp单候选窗口，保存恢复原league，保留25真实局与原生成断言。
- Test/c24_batch.sh：逐脚本解析、定向/突变/既有全量/冒烟/HUD一体门禁，独立prefix日志与存档目录，嵌套.done rc核验；仅ALLDONE表示正常结束，中断轮另标ABORTED。
- Test/c24_shiny.gd：伤害倍率、Profile门/家族记录、Classic200/0、真实存档读写往返、Classic池/概率、闪光队友初始值。
- Test/c24_live.gd：真实场景化石交互取消、祝福强度、实际捕获/替换/放生、唯一闪光队友、Classic独立结算。
- Test/c24_fossils.gd、Test/c24_fossils_mutations.py：化石参数、单次/取消/amber门、实际Player.recalc成本与mutation。
- Test/c24_fusion_data.py：表契约及8种mutation；tools/extract_c24_fusions.py：哈希原料可复现提取和--check，不执行cast。
- design/c24-fusion-data.md：数据说明/来源/UNPROVEN边界。本文件为施工与验收记录。

## 红基线与当前检查

- 闪光改前 c24_shiny_red.log：9项/9红（倍率和8个缺失API），非解析失败；改后首轮29/0。
- 化石改前c24_fossils_red.log：1/1实现缺失；实现后25/0，10个行为mutation全命中、missed0。
- 融合改前缺表rc1；改后契约PASS、8个mutation全命中、两表SOURCE PARITY PASS。
- 本地首次Godot默认user目录不可写导致启动崩溃，未计行为证据；改为工程.tmp内XDG_DATA_HOME/XDG_CACHE_HOME隔离，避免接触用户真实档。

## 验收断点

游戏接线与定向集成检查进行中；全量suite、bootsmoke、中立冒烟、phonehud两档、NUC同步和TREE PARITY尚未完成，不提前宣称交付。

- 首轮NUC同步 c24_final_sync.log：TREE PARITY OK 120文件，diffs0。`setsid -f bash Test/c24_batch.sh` 已启动，c24_final.done记录8个check-only0、shiny0、fossils0；继续等待live及全量，不把部分日志计为完成。
- 真实场景首次本地headless23/0，但退出时地形worker未结束导致script errors/rc134，**不作为整轮绿证据**；测试加等待worker完成，改Xvfb复跑。
- 接续本地补正（尚未覆盖正在运行的NUC树）：`_throw_ball`拒绝已收服的ally再投球；harness C20旧fixture用“节点释放”作为已捕获条件，现在闪光节点保留成队友，应按 `_shiny_e != se3` 判定完成并通过既有选择入口结清swap。保留原50星尘/图鉴不变硬断言。最终需重新同步与全量。
- 最终接续修正：Classic到点时若仍有活动捕获遭遇，保留时间待idle再出（main tick原文的idle/done门）；与闪光同时到点仍先闪光。Classic加权只用现有ModelRig能力门，不误套可选Liga roster门。捕获尾文注明家族已解锁或入盟后可用。
- Test/c24_live.gd追加真实director闪光优先、Classic忙时等待/idle生成、Classic实际HP×2.5及已收服队友不可重复投球；Test/c24_batch.sh追加harness逐脚本解析及可选独立日志前缀，保留首轮证据。

- 独立源码复核纠正pack羁绊增长摘要：main @528200附近 `kills++; n=Eh.filter(e=>kills>=e).length; n>bond&&(bond=n)`；初始2在25/75击杀仍2，150变3，500变5。恢复基线阈值算法，C24仅新增初始羁绊种子；live独立覆盖四边界。先前中间“阈值累加”实现/检查被本条取代，不作为最终规则。
- 同次独立复核补齐：main @519492 `team=list.filter(e=>!e.shiny)`，普通捕获与孵蛋容量改用排闪光后的数量；闪光是额外独立位。live真实master-ball捕获要求1闪光+2普通同时成立。
- main @1047800附近 update 的idle/done门在消费shinyAt之前，且顺序shiny→Classic→Liga。C20 N15旧夹具/注释“忙时丢掉闪光”被原文反证，本批修正游戏与检查为保留时点，DIFF历史结论不改；live追加两向busy以及三者同时到点，harness保留同一真实场景断言并改为已证等待口径。
- Classic Ae边界：news wr @142041，对roster member直接返回[id]，否则同family roster成员。106/107共享family236，不能捕获106就开放107。Profile新增成员覆盖读取器用于Classic；闪光按派单仍按家族。新增106/107回归检查。
- 本地保存首轮NUC world到.tmp只读对照，追加真实场景红检查已直接打出“闪光挤普通位、Classic忙时消费时点”等红。首轮negative control在后续假设Classic已生成处遇Nil，故不计完整红检查完成；已补仅负对照恢复fixture的guard，待该轮timeout.done后重跑，保留错误日志。
- 首轮NUC suite658/3：全局联盟池8次抽样没抽中magikarp；props硬编码54/16（新增化石后55/17）；C20未结swap挡住guardian。全部保留首轮日志，不当作既有非本批签名豁免。
- harness补正：props精确新增fossil=1、总55/17；联盟池测试仍跑25真实局和原Magikarp断言，只在抽样窗口将其他family置为已入盟、结束恢复原league/存档，令目标唯一可选而不改游戏池（zone-filter错误仍无法生成它）。C20按真实swap结清。
- 独立复核红对照 c24_review_red.done已ALLDONE：38项/6红、rc1，无SCRIPT ERROR；命中普通位被挤、Classic时点丢弃、反向忙时/后续时序。为让“三者同帧”fixture真正跨过既有tier_timeline_time的60秒地板，后续将elapsed61、league_at60，不以.01冒充有效联盟到点。
- 修正有效联盟到点fixture后红对照再次完整结束：c24_review_red.done **38/6，rc1，ALLDONE**；包含三者同帧真实优先序红，无SCRIPT ERROR。源冻结哈希存 c24_review_red_source.sha256。修后本地真实场景复验正在跑。
- 所有5个游戏脚本及harness/三个C24 GDScript检查逐个本地check-only均0；source parity再次通过，DIFF哈希未变。
- NUC首轮bootsmoke rc0（隔离存档目录已链接只读既有4.3模板）；中立冒烟和两档HUD未结束前不覆盖树。最终batch会同时检查嵌套.done各阶段rc，不能用末尾echo的rc0掩盖suite失败。
- 最终本地真实场景 `c24_live_final_local.done` **38/0，rc0，ALLDONE**，无SCRIPT ERROR；与38/6红对照同一检查脚本（仅world脚本切到保存的改前树）。最终Profile/闪光检查 **33/0**；化石26/0与11/0missed，融合契约106/8killed。
- 游戏/检查/融合数据与提取器共15文件冻结SHA见 Test/out/c24_final_code.sha256；文档仅追加证据。独立复核已确认容量、时序、Ae和bond修复正确；这是同池只读代码审查，不冒充官方Claude审计。动态边界：孵蛋容量调用点通过共享helper静态核验，额外闪光位由真实普通捕获覆盖；106/107当前无模型，成员隔离由Profile断言验证，池仍严格拒无模型。

## 旧树门禁中断断点（先记录，后中断）

首轮旧树 suite658/3已确认且最终修复树本地38/0；bootsmoke rc0、中立rc0。phonehud a仍运行，s070尚未开始。为避免继续验证已过期树，计划仅结束`bash Test/c24_batch.sh`所属独立进程组，将首轮.done明确追加ABORTED；该轮HUD不计通过。中断后同步冻结树，以c24_v2独立前缀重新完整运行suite/bootsmoke/中立/HUD a+s070，全部等待.done后再收口。首轮核心证据已拉回18文件153846B。
- 已按上述断点仅终止NUC旧树独立进程组1275019，首轮 c24_final.done 末尾为ALLDONE_ABORTED；未声称该轮HUD完成。之后接冻结树完整新轮。原料补核精确起点存c24_bundle_queries.log：team519492、onAllyKill528148、capture tick1047809、classicPool1051728、fossil863402、news Ae142041。

## 冻结树最终门禁 c24_v2

- c24_v2_sync.done **rc0/ALLDONE**；既有同步脚本 TREE PARITY **120文件、local120/nuc120/diffs0**（20:46:45 CST）。冻结15文件与NUC逐个SHA完全一致（含两份JSON与提取器），不只依赖scripts/Test的parity。
- NUC以 `C24_PREFIX=c24_v2 setsid -f bash Test/c24_batch.sh` 启动最终全套；等待c24_v2.done及c24_v2_full_batch.done。期间不改游戏/检查/数据文件。
- 旧树close首次拉回因刚被终止的phonehud尾部刷新，manifest116650B/本地116785B，脚本正确报RC5，**未计成功**；保留c24_initialclose_pull.log，另前缀retry待核验。核心18文件已先核验通过。

## 进程残留复核断点（先记录，后处理）

旧phonehud输出仍增长，close重试再次RC5；父batch进程组终止不代表timeout创建的子组已退出，先前“仅父组结束”不能当作完整停机。c24_v2虽已启动，其隔离存档目录与旧轮相同，存在交叉写档风险，**该轮不作为最终验收**。将按/proc fd1精确识别旧HUD及v2进程，全部终止并留ALLDONE_ABORTED；batch再改为每前缀独立XDG目录，重新冻结该检查脚本，v3全套重新跑。游戏代码与数据不变。
- /proc fd1复核定位旧HUD timeout组1293249、v2父组1301182及suite子组1303127；逐组终止后再扫输出文件 **REMAINING []**，确认无残留读写。v2.done已ALLDONE_ABORTED，v2 suite未完成，不计验收。
- `Test/c24_batch.sh`改为按prefix独立XDG_DATA_HOME/XDG_CACHE_HOME；唯一检查脚本变更重新冻结SHA，游戏/数据14项不变。最终用c24_v3；v3存档目录从空目录启动，不与任何旧轮共享。
- v3启动前最后入口复核：eclipse事件会直接调_spawn_shiny，不能只在时钟director加busy门。按main spawnShiny/spawnClassic原文开头的roaming/weakened/throwing门，为两种直接生成入口也加三遭遇互斥检查；live新增两向直接调用检查。v3尚未启动，不覆盖运行中树；这一游戏入口补正重新冻结world/live两项，再同步后才启动。
- 最后直接入口补正后完整对照结束：c24_live_compare.done **red rc1 / green rc0 / ALLDONE**；同一40项检查在保存的改前world **40/8红**，最终world **40/0**，两份均无SCRIPT ERROR。8红包含额外普通位、三方优先、两向时钟busy门、两向直接调用busy门及后续时序。最终15项SHA重新冻结。
- 清理后中断证据拉回成功 c24_aborted_close_pull.done **RC0、5文件177660B**，前两次RC5保留，不回写成成功。

- 最终 c24_v3_final_sync.done **rc0/ALLDONE**，TREE PARITY120/diffs0（20:52:38 CST）；15文件逐SHA再核全同。`C24_PREFIX=c24_v3 setsid -f bash Test/c24_batch.sh`已启动，使用独立`.tmp/c24_v3_data`与cache。等待完整.done；未完成前不计交付。
- v3定向已完成：9个脚本check-only0；shiny **33/0**、fossils **26/0**、live **40/0**，全部rc0且无SCRIPT ERROR；化石mutation11/missed0、融合106条契约及8killed/0missed。既有damage/pickups/stats/mutation也均rc0。
- 定向核验拉回 c24_v3_target_pull.done **RC0、14文件14871B**。全量suite运行中，尚不预填SUMMARY。

## C24 验收关账（2026-11-10，主控）

- 最终批 c24_v3.done 为 ALLDONE_FAILED：内层 full_batch rc=0，但全量 suite 首轮 **658/1**，唯一红 = `C9 FAIL c21 passive static: discharge hits the nearest`（C22 已立案的环境目标吸收签名，B2 glare 轮间歇出现、夹具加固后四轮全绿）。
- 主控定性重跑：同树同命令 suite2 **658/0、rc=0**（c24_v3_suite2.log/.done）。判定为间歇性环境抖动，非 C24 引入（闪光/化石/融合与该被动实验室夹具无因果路径）；首轮红保留在案、不抹除。
- 其余最终证据：定向 shiny 33/0、fossils 26/0、live 40/0（改前对照 40/8 红）、化石 mutation 11/11、融合数据契约 106 条 + mutation 8/8、既有 damage/pickups/stats/mutation 均 rc0；bootsmoke OK；phonehud a 1635/0、s070_i0 1642/0；TREE PARITY 120 文件 diffs=0。C24 五项全落地：闪光队友/Classic/皮肤记录、化石 helix·dome 可建造（amber 数据占位）、融合仅数据提取（assets/data/fusions.json + fusion_rules.json + design/c24-fusion-data.md），引擎未写。
- 本关账提交同时入仓：起始三线转折版设计（design/art-concepts/board-v7、starter-transform-design、grammar）与 UI 定版效果图（design/art-concepts/ui-approved）。
