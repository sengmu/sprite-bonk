# Android 版 UI 对齐台账

2026-11-20：Android 基线 `d38a7ce`，分支 `codex/android-baseline`。源码来自 AI Studio 导出包。已知 SpriteBonk GitHub 分支为 Godot 工程，未找到 Android Compose 的对应分支。Godot `origin/main` 为 `7dcc9f2`，`origin/align-fix13` 为 `a386b03`，后者已经记录 U5 第六轮。这些验收记录只对应 Godot。

## U1 战斗 HUD

对比图 [U1.png](ui-reference/compare/U1.png) 左侧为 Godot 仓库 v2 规格 U1_final.jpg（横屏守护者态），右侧为 Android 基线在 Seeker 上的开局实拍（竖屏）。原始实拍为 [U1-seeker.png](ui-reference/compare/U1-seeker.png)。两侧方向和战斗状态不同，这张仅记录基线差异，不能用于 1:1 签核。

可见差异：顶栏分散为多个独立面板，参考图为居中一条；左上头像、等级与血条的底板结构不同；技能槽是方形而非带银边的圆形；触屏按钮的排列、边框与字形不同。守护者条与击杀计数需补同状态横屏实拍再判。

下一轮先获取横屏守护者态、目标折叠态与交互就绪态，再按已有裁定处理可比项。U1 尚未签核，U3 未开工。Godot phonehud 不适用于 Android Compose。
