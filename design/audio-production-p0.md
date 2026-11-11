# 音频生产记录 — P0 合成音效批（2026-11-11）

- 分支：`audio/p0-sfx`（基线 main `455b231`）
- 依据：`design/audio-requirements.md`（83 条清单 + 主控裁定）
- 用户指示（2026-11-11）：先做 P0 免费合成音效，按清单备注风格；**BGM 与伙伴声留待用户定方向，本批未动**。

## 生产方式与格式

- 自制参数合成：`assets/audio/generate_sfx.py`（numpy/scipy）。每条配方按清单的风格备注原创设计（木质轻敲、萤尘荧光、钟声泛音列等），**不含原作挖出的参数**；胜利/失败/结伴乐句为原创旋律。
- 格式（按主控裁定）：WAV 16-bit / 44.1 kHz / 单声道，峰值 −1 dBFS；35 个文件共 1.2 MB。
- 数值 QA 全过：采样率/位深/直流偏移/静音检查无异常；频谱质心与设计相符（boom 410 Hz 深沉、slash 12.2 kHz 明亮、hit 四档质心单调递升 798→2396 Hz）；shot_fire 顶层噼啪初版过亮，已回调增益重渲染。

## 文件 ↔ 需求行

| 文件（assets/audio/sfx/） | 需求行 |
| --- | --- |
| click.wav | UI-01（并供 UI-03、UI-06 接线复用） |
| deny.wav | UI-02 |
| xp.wav | EC-01（连拾升调仍由引擎 pitch 实现） |
| coin.wav | EC-02（并覆盖 EC-05 等既有 coin 播放点） |
| sparkle.wav | EC-06（新增，见代码改动 2、3） |
| heal.wav | EC-03 |
| chest.wav | EC-04 |
| charge.wav | EC-10 |
| bell.wav | EC-11 |
| whoosh.wav | EC-12（兼 CB-09 冲刺） |
| shot_default / shot_grass / shot_fire / shot_water.wav | SK-01 |
| slash.wav | SK-04 |
| ult_grass / ult_fire / ult_water.wav | SK-08（新增，见代码改动 2、6） |
| hit_weak / hit_neutral / hit_super / hit_crit.wav | CB-01 |
| mega.wav | CB-02 |
| pop.wav | CB-03 |
| hurt.wav | CB-05 |
| jump.wav | CB-07（二段跳升调仍由引擎 pitch 实现） |
| alarm.wav | CB-12 |
| boom.wav | CB-13（兼 CB-17 守护者击败，既有播放点） |
| boss_start.wav | CB-14 |
| level_up.wav | LV-01 |
| power.wav | LV-02 |
| victory.wav / defeat.wav | LV-07 / LV-08（原创乐句） |
| ball_click.wav / caught.wav | CH-04（木匣扣合 + 原创成功乐句；非伙伴叫声） |

接线复用、无新增文件的 P0 行：UI-03（click 接线）、UI-06（click 接线）、EC-05（coin/deny/click 换声）、LV-03（click/deny 换声）、LV-04（coin）、LV-05（click/deny）、UI-07（click 换声，伙伴声部分留待 CH-01）。

## 游戏代码改动（逐条，与资产/文档改动分开列）

1. `scripts/audio.gd`：`stream_for()` 改为**文件优先**——`assets/audio/sfx/<key>.wav` 存在则播放文件，否则回退旧合成配方（新增 `SFX_DIR` 常量与 `_file_stream()`）。回退仅供 P1/P2 未生产 key 在开发期出声，**首发前必须清零并删除配方渲染**（M5 门禁）。
2. `scripts/audio.gd`：新增 `sparkle()`（EC-06）与 `ult_cast(fam)`（SK-08，fam 1/4/7 → ult_grass/ult_fire/ult_water）。
3. `scripts/world.gd`：实验室升级购买成功 `audio.coin()` → `audio.sparkle()`（EC-06：萤尘与金币声必须区分）。
4. `scripts/world.gd`：U6 钱包「连接/断开」「复制地址」「关闭」三个按钮的 pressed 处理各加一行 `audio.click()`（UI-03，补原缺声 G1–G3）。
5. `scripts/world.gd`：U5 结算「再次出发」「返回菜单」两个按钮各加一行 `audio.click()`（UI-06，补原缺声 G5/G6）。
6. `scripts/ult.gd`：`_cast()` 的音频段由借用的 shot/boom 组合改为 `GameAudio.instance.ult_cast(fam)`（SK-08）；duck 逻辑未动。

未动：`cry()` 伙伴声、BGM 渲染与其余全部播放点、全部游戏数值。

## 仍为合成占位（后续生产范围）

P1/P2 的 key 仍走旧合成回退：hover、shot_electric / shot_ice / shot_psychic / shot_ghost、beam、beam_ice、cone_fire / cone_other、nova、nova_ground、dodge、land、dive、slam、encounter、throw_ball、ball_open、ball_shake、slot_tick / slot_stop / slot_lever / slot_coins / slot_curse、zap、evolve_done、streak 等。随 P1/P2 生产单逐批替换；BGM（BGM-01…05）与伙伴声（CH-01/02）等用户定方向后另行生产。
