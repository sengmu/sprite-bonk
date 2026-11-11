# 音频生产记录 · P1/P2 批（audio/p0-sfx 分支，2026-11-11）

需求口径：`design/audio-requirements.md`（83 条：P0 36 / P1 35 / P2 12）。
P0 批见 `design/audio-production-p0.md`。本批经用户 2026-11-11 17:26 拍板：
「P1/P2 也用免费合成做完」。BGM（BGM-01…05）与伙伴声（CH-01/CH-02）按用户
先前裁定继续留空——本批一行未动，等用户定方向。

## 生产方式

与 P0 同路：`assets/audio/generate_sfx.py` 参数合成（numpy/scipy），每条配方
按清单备注的风格从零设计；旋律（jackpot / evolve_done / revive / boss_down /
confirm 等）为原创乐句。单声道 WAV 16-bit / 44.1 kHz、峰值 −1 dBFS；
环境循环按格式裁定走 OGG Vorbis q6 / 立体声。

本批新增：
- 单发音效 43 个（`assets/audio/sfx/*.wav`）：hover、shot_electric、shot_ice、
  shot_psychic、shot_ghost、beam、beam_ice、cone_fire、cone_other、nova、
  nova_ground、dodge、land、dive、slam、encounter、throw_ball、ball_open、
  ball_shake、slot_tick、slot_lever、slot_stop、slot_coins、slot_curse、
  jackpot、zap、evolve_done、streak（以上为引擎既有 key 换原创声）；
  confirm、start、panel_open、panel_close、buff、chest_gold、mimic、
  ult_ready、revive、rage、boss_down、banish、shiny_spawn、terminal、greet
  （新 key，配套新方法）。
- 环境循环 3 个（OGG）：amb_forest 24s（EN-01 森林底噪：落叶床 + 稀疏鸟鸣）、
  amb_rain 20s（EN-02 雨）、amb_wind 22s（EN-02 风/雾）。循环用头段交叉淡入
  续流法拼接，实测接缝步阶低于文件自身最大步阶（比值 0.08–0.62），无咔哒。
- 顺带修正：finish() 加 12 Hz 高通居中波形，hit_weak / hit_neutral / land /
  slam 四个低频文件的直流偏移（原为峰值的 0.7–2.1%，低频能量不对称）归零，
  听感不变。

生产后核查：引擎 `_render_sfx` 的 59 个配方 key 与全部 `_sfx(...)` 调用 key
**已 100% 有原创文件兜底**——旧合成配方从此只剩「未知 key 静音兜底」的保险
职能；BGM 渲染器与 cry 哈希合成未动（用户留定两项）。

## 接线（游戏代码改动，逐项列明）

scripts/audio.gd：
- 新增环境层：_ready 建 2 个 Music 总线播放器（底床 −19 dB / 天气层 −16 dB）；
  `ambience(kind)` / `ambience_weather(w)`；`_amb_stream()` 载入 OGG 并在
  代码内设 loop=true（4.3 的 OggVorbis 是布尔 loop + begin/end，不依赖
  .import 的 loop=false 默认。注：首版误用 4.4 的 LOOP_FORWARD 枚举，
  解析门当场拦下、已改。）
- 新增单发方法：confirm / start / panel_open / panel_close / buff /
  chest_gold / mimic / ult_ready / revive / rage / boss_down / banish /
  shiny_spawn / terminal / greet。
- `shot(type, vol_db := 0.0)`：加可选音量参数（SK-10 队友施放降 6 dB 用），
  既有调用签名不变。

scripts/world.gd：
- UI-04 钱包连接成功：地址直连成功 → confirm；MWA 授权发起置位
  `_wallet_ok_armed`，余额读到后在 `_refresh_wallet_ui` 里 confirm 一次。
- UI-05 授权失败/地址无效：地址无效、授权即时被拒、auth_failed 三处 → deny。
- UI-08 出发确认：出战配置「开始」与 U5「再次出发」由 click 改 start。
- UI-09 弹窗打开：panel_open 接入 _choice_show（通用弹窗）、_open_settings、
  _open_draft（面板真正显示处）、_open_loadout。
- UI-10 暂停：_open_pause 与队伍查看 peek 打开时 duck(0.45, 3600)，
  _close_pause 时 duck(1.0, 0.05) 恢复（走 §六裁定的 duck 路线，不用
  stop_music）。
- EC-07 萤尘商店购买：power → sparkle（复用 EC-06 口径）。
- EC-13 老虎机：slot_lever 后补一记 slot_tick 棘轮声（本移植的老虎机是
  即时出结果、无转轮动画，tick 作拉杆机械尾音，不改任何时序）。
- EC-17 机关匣：打开重编译三选一前 → terminal。
- EC-18 獾掌柜：_open_shop 在 click 后加 greet（门铃声，无叫声无口癖）。
- EC-16 复制物品点：_open_ditto 两处 cry("ditto") → mimic（机关+魔法音）。
- CB-11 复活：_on_player_died 两条复活路径 heal → revive。
- CB-16 守护者狂怒：_boss_enrage 的 cry → rage（低频咆哮涌起，非物种叫声）。
- CB-17 变体：守护者击败 boom 后加 boss_down 小乐句。
- CH-07 流光伙伴：_spawn_shiny 在 cry 旁加 shiny_spawn 闪烁提示。
- LV-05 放逐：_banish_option 实际放逐时 → banish（撕纸感）。
- LV-09 结算入账：_finish_run 里萤尘到账（dust > 0）→ sparkle。
- EN-01/02：start_game 起 ambience("forest") + ambience_weather(weather)；
  天气三个设定点（区域进入 / set_base_weather / set_weather）在
  apply_weather_look 后同步 ambience_weather；_finish_run 停两层。

scripts/ult.gd：SK-09（G7）—— add() 里充能跨过 1.0 的那一刻 → ult_ready，
与既有的金环 + 横幅同点触发。

scripts/pickups.gd：EC-09（G8）—— collect() kind 3–12 补声：磁吸/驱散/钥匙/
增益卷轴（8,9,10,12）→ buff；清屏（4）→ boom 后 nuke；直升一级（6）→
level_up；雷霆群晕（11）→ zap。

scripts/ui_theme.gd：UI-12 —— make_button 工厂统一接 mouse_entered →
hover（引擎内 0.04s 节流；触屏不触发）。

未动：cry()、全部 BGM 渲染、150 个既有播放点的其余部分、一切游戏数值。

## 不接线的裁定（文件已产、不硬接，理由在案）

- SK-07 锥形喷射（cone_fire / cone_other）：本移植的招式数据只有
  strike / projectile / nova / beam 四种形态，没有 cone 形态的数据位；
  几何上是锥形的 strike 已由 slash 覆盖。硬造分发等于给不存在的形态
  配音，故只产文件、方法保留（cone() 现为文件发声），待数据层真有
  cone 形态时再接。
- EC-04 金纹宝箱变体（chest_gold）：金纹宝箱在代码里与藤纹宝箱共用
  开箱路径、宝箱字典上没有可区分标记；产文件备用，接线等代码层先有
  区分（属玩法侧改动，不在本单范围硬造）。
- UI-14 竖屏提示页：按 §六裁定不配音效（只有 duck 规则），页面本身是
  公司线在建的 S25，本树无此页，无可接之点。
- LV-09 数字滚动：结算面板是整表直填、没有逐项滚动动画，无可挂 tick
  的时序点；改为「入账 chime」（见上）。
- UI-11 开关 / UI-13 插旗 / EC-08 预设：清单本就写明复用 click/coin，
  P0 已换文件，天然覆盖。
- CB-18 金鼹鼠出场、CB-14 登场、LV-06 成长等处的 cry 调用：属伙伴声
  范畴，按用户裁定原样保留，等 CH 方向定后再换。
- stop_music / hover 的旧「未接线」结论更新：hover 已接（UI-12）；
  stop_music 按 §六裁定保持不接（暂停走 duck）。

## 验收

验收在 NUC 上执行（2026-11-11 晚，分支 audio/p0-sfx）。批次脚本
Test/audio_p12_batch.sh（解析门 → P0/P12 双检查 → c23b 全批）。

批次过程（如实记录，含失败轮）：
- 第 1 轮：解析门拦下——首版误用 Godot 4.4 的 LOOP_FORWARD 枚举，
  4.3 的 OggVorbis 只有布尔 loop，已改。
- 第 2 轮：解析全过、P0 检查 rc=0，P12 检查挂死——loop_begin 赋值
  在 4.3 不存在，运行时错误使 _amb_stream 提前返回 null，检查解引用
  空流后中止、未及 quit。已改纯布尔 loop + 检查侧空值防护后重跑。
- 第 3 轮（定版）：全批 ALLDONE，数字如下。

定版数字：
- 解析门 7/7 rc=0（audio/world/ult/pickups/ui_theme + 双检查脚本）。
- audio_p0_check rc=0（143 项）；audio_p12_check 211/0 rc=0
  （43 个新键文件背书/44.1k/时长、新 API 播放计数、cone 分发、
  shot 音量参数、环境层加载/循环/启停/天气切换全过）。
- 定向批：damage / pickups / pickup_stats / pickup_mutations 全 rc=0；
  bootsmoke rc=0（0 脚本错误）；neutral rc=0。
- phonehud s070_i0（竖屏档）：1635/0。
- phonehud a（2400×1080）：1644/7——7 红全部是同一项
  `P4: ring home unmoved`（ring_bottom 580.73 vs 原 home 586），
  即 U1 轮已裁定的摇杆避让新 home（主控 2026-11-11 裁定接受偏移、
  断言改向钉新 home 属 U1 线几何活），与本批无关，非本批引入。
- suite：首轮 650/1、单独复跑 651/1，两轮唯一红均为
  `C9 FAIL c21 passive tentacles: both neighbours were whipped`
  （hp 值两轮不同：-1/281720.47 与 -1/-1）。
  裁定 = 既有间歇 flake 家族，非本批回归，依据三条：
  ① 本批 diff 零玩法/伤害/被动代码（仅音频接线，逐项在上文列明）；
  ② 同一断言在无音频改动的树上已有两次同签名失败记录
  （design/ui-mobile-changes.md:74 的 C21DBG 诊断＝拥挤夹具里
  环境目标吸收被动 tick；design/ui-reskin-changes.md:113 接线检查点
  批 suite 658/1 唯一红也是它；C24 的 c21 passive static 为同族）；
  ③ 两轮失败值不一致，符合环境吸收签名、不符合确定性破坏。
  两轮首红均留档，不抹。

里程碑复核（脚本实测）：audio.gd 全部 59 个 _render_sfx 分发臂与
全部 _sfx 键均有原创文件背书——单发音效键空间 100% 文件化，
旧合成回退仅剩未知键静默保护。仍为占位渲染的只剩 BGM 曲目与
伙伴叫声（cry），按用户裁定等方向，本批未动。
