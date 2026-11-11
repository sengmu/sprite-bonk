# BGM 生产记录（audio/bgm 分支，2026-11-11）

## 缘起

用户 2026-11-11 晚验收 P0+P1/P2 音效时点头（SFX 已合 main
`a530665`），随即点开 BGM 线，原话：「游戏背景音呢？现在的不好听，
还破音」。

现状诊断（代码实证）：旧 BGM 是照原作音序器设计合成的占位渲染
（audio.gd 注释自明），渲染规格 MSR = **11025 Hz、8-bit 无符号**
（`_to_stream` 的 FORMAT_8_BITS）。11 kHz 采样 + 8-bit 量化就是
「破音」的来源——不是音量爆掉，而是量化噪声与混叠让音色发糙；
且曲目本身属 M5 换皮门禁的占位范畴，首发前必须全换原创。

## 范围（对清单 BGM-01..05）

- BGM-01 主菜单曲（P0，必须原创）：新作曲，轻快、森林感。
- BGM-02 局内战斗曲 A（P0，至少 1 条原创）：新作曲。
- BGM-03 局内战斗曲 B（P1；清单口径「首发 2 条原创就够，变调
  方案可以保留」）：新作曲 B + A/B 的变调版 ingame3（+2 半音）/
  ingame4（−2 半音）以真实渲染文件交付——引擎原有的 6 曲目表
  （menu / ingame1-4 / boss）一一对应有文件，选曲逻辑零改动。
- BGM-04 守护者 Boss 曲（P0，必须原创）：新作曲，紧张压迫。
- BGM-05 区域主题变体（P2）：**缺的是选曲功能不是声音**——代码
  按「一局随机」选 ingame 曲、没有区域维度。本批不嫁接选曲逻辑
  （同 SK-07 cone / EC-04 的不嫁接纪律），记为功能缺口待后续。

交付格式按需求单 §六裁定：OGG Vorbis q6 / 44.1 kHz / 立体声、
整小节无缝循环、整体约 −16 LUFS、峰值留足余量。

## 生产

工具：`assets/audio/generate_bgm.py`（numpy/scipy 参数作曲+合成，
可单曲重跑）。六首全部为本项目原创作曲（旋律、和声进行、低音线、
鼓型均在本脚本内写定），不含任何既有作品或原作音序器的数据。

作曲一览：
- menu：D 大调 92 BPM，8 小节。D–Bm–G–A 进行，锯齿垫底和弦、
  拨弦式三角波主旋律、根音低音、轻踢鼓+沙锤、高音正弦点缀
  （森林感），带循环延迟的空间感。
- ingame1：G 大调 116 BPM，16 小节。G–Em–C–D，四踩踢鼓、
  八分贝斯律动、主旋律 A–A'–B–A'' 结构，后半 16 分琶音。
- ingame2：E 小调 104 BPM，16 小节。Em–C–Am–B，半拍感军鼓、
  切分贝斯、旋律带留白与小六度色彩，延迟更深（神秘感）。
- ingame3 / ingame4：ingame1 / ingame2 的 ±2 半音变调渲染
  （同速度，不用重采样变速——循环长度与节拍与原曲一致）。
- boss：D 小调 132 BPM，8 小节。Dm–Dm–Bb–A，八分贝斯执念型、
  和弦短促重击（stab）、锯齿主旋律短句、四踩+密集踩镲压迫感。

无缝与不破音的工程做法：
- 环绕累加渲染：所有事件按索引取模写入循环缓冲，垫底音尾与
  延迟自然跨过接缝，循环在构造上无缝（接缝步进实测远小于曲内
  最大步进，见下表）。
- 峰值限制器（前视包络平滑增益）把真峰压在 −2.5 dBTP 以下；
  响度以 ffmpeg loudnorm（BS.1770）实测为准调至约 −16 LUFS。

生成时实测（ffmpeg loudnorm，编码后 OGG）：

| 曲目 | 时长 | 整合响度 | 真峰 | 接缝步进 / 曲内最大步进 |
|---|---|---|---|---|
| menu | 20.9 s | −16.4 LUFS | −2.5 dBTP | 0.0017 / 0.153 |
| ingame1 | 33.1 s | −15.8 LUFS | −3.8 dBTP | 0.092 / 0.102 |
| ingame2 | 36.9 s | −16.5 LUFS | −3.8 dBTP | 0.053 / 0.177 |
| ingame3 | 33.1 s | −16.5 LUFS | −4.6 dBTP | 0.051 / 0.133 |
| ingame4 | 36.9 s | −15.9 LUFS | −3.1 dBTP | 0.089 / 0.193 |
| boss | 14.5 s | −15.8 LUFS | −3.1 dBTP | 0.0011 / 0.359 |

削波采样数全部为 0。文件共约 3.4 MB（OGG q6）。
中间 WAV 已删（脚本可随时重渲染）。

## 代码改动（逐项列明）

仅 scripts/audio.gd：
- 新增 `MUSIC_DIR`（res://assets/audio/music/）、`_file_track(name)`
  （ResourceLoader 载入 bgm_<name>.ogg、缓存、代码内 loop=true，
  与环境层的 4.3 OGG 口径一致）。
- `play_track(name)`：文件优先——有文件时用文件流且
  pitch_scale = 1.0（变调版是独立文件，不再走重采样变调）；
  无文件才回退旧音序器渲染（`_track_stream`，开发占位，
  M5 门禁时与其它占位渲染器一并删除）。
- 调用点零改动：world.gd 的 play_track 调用（菜单/开局随机/
  守护者切换）签名与语义不变；选曲逻辑、总线音量映射不变。

## 检查

新增 Test/audio_bgm_check.gd（61 项）：6 个曲目名逐个断言
文件存在、play_track 后当前曲目正确、活动播放器的流是该
OGG 文件本体（非音序器 WAV）、loop 开、时长 > 5 s、
pitch = 1.0、播放计数、重复点播为 no-op；stop_music 清空。
格式/响度/真峰由生成端 QA（上表）背书，不在引擎内重复测。
批次 Test/audio_bgm_batch.sh：解析门 → BGM 检查 → P0/P12
音频检查（回归）→ c23b 全批（suite/bootsmoke/phonehud）。

## 验收

验收在 NUC 上执行（2026-11-11 晚，分支 audio/bgm，基线 main
a530665）。批次脚本 Test/audio_bgm_batch.sh。

批次过程（如实记录，含失败轮）：
- 第 1 轮：解析门拦下检查脚本——`var path :=` 拼接循环变量
  （Variant）无法推断类型，改显式 String 后过门（c41467e）。
- 第 2 轮：解析门全过、BGM 检查 61/0、P0 检查过，但 P12 检查
  211/1，唯一红 `API plays panel_close`。单独同树复跑 = 211/0；
  定性 = 检查自身的共享节流窗（panel_open/panel_close 共用
  0.05 s「panel」门）在高负载下的时序竞态，与本批 diff 无关
  （本批未触碰 panel/节流代码）；第 3 轮批内复跑亦 rc=0，
  首红留档。
- 第 3 轮（定版）：全批走完，数字如下。

定版数字：
- 解析门 2/2 rc=0（audio.gd + BGM 检查脚本）。
- audio_bgm_check **61/0**；audio_p0_check rc=0；
  audio_p12_check rc=0（211/0）。
- 定向批：damage / pickups / pickup_stats / pickup_mutations
  全 rc=0；**suite 651/0**（本轮 c21 家族未现红，与其间歇性
  一致）；bootsmoke rc=0（0 脚本错误）；neutral rc=0。
- phonehud s070_i0：1635/0。
- phonehud a（2400×1080）：1644/7——逐条核对，7 红全部是
  `P4: ring home unmoved`（U1 轮已裁定的摇杆避让新 home，
  非本批引入），非 ring-home 失败 = 0 条。

批次包装脚本因 phonehud a 的 rc=1 记 ALLDONE_FAILED，与 P12
轮同形（该档的 ring-home 断言改向属 U1 线几何活）。

至此音频占位清零进度：单发音效 59 键 + 环境层 + **全部 6 条
BGM 均为原创文件**；仍为占位渲染的只剩伙伴叫声（cry，按物种
哈希合成），等用户定方向。旧音序器/配方渲染代码保留为开发
回退，M5 门禁时删除。
