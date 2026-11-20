# Sprite Bonk 钱包修复与 Seeker 验收

日期：2026-11-20。验收包：`com.example.spritebonk.preview`。

APK SHA-256：`202b65935d9998d3e85ba3c4d93194be70bf15b42bff30c99687853b637e2d99`。本地 APK 和 Seeker 已安装的 base.apk 哈希相同。

| 场景 | 结果 |
| --- | --- |
| 连接钱包与地址 | 通过 MWA 授权，地址为钱包返回的只读文本，界面提供复制按钮，实机无可编辑地址输入框。 |
| 主网余额 | 授权后显示 0.0019 SOL。 |
| 战斗往返 | 当前包进入战斗、结算、回主菜单后仍显示「钱包已授权」和 0.0019 SOL。 |
| 冷启动与离线恢复 | 当前包离线冷启动后显示「已保存地址」，给出失败提示和「重试」。恢复 Wi-Fi 后重试，恢复显示 0.0019 SOL。 |
| 撤销授权 | 当前包撤销后，游戏显示「尚未连接」。用户在 Seeker 钱包的已连接应用列表确认 Sprite Bonk 已移除。 |
| 拒绝授权与游客玩法 | 先前预览包已分别验证拒绝后可重试，以及断开后可直接开始战斗。 |

实现包含 MWA 2.0.3、相对授权图标路径、公开地址保留、只读余额与 PublicNode 主网备用 RPC。AGP 9.1.1 构建保留 Java AAR，从 KTX AAR 提取 classes.jar，避开重复清单命名空间。

## 重建

使用 JDK 17、Gradle 9.7.1、Android SDK 36.1 和已接受的 SDK 许可，执行 `gradle :app:assembleDebug`。此前实际构建使用本机 Gradle 9.7.1，源码包仅带 wrapper 配置，无 wrapper 启动脚本。

调试签名配置读取项目根的 `debug.keystore`。归档不含签名密钥；复刻预览包的更新签名要在本机使用原调试密钥。用新调试密钥构建时，已有同包名预览不能直接覆盖安装。

本归档来自 Android 新版解压目录，该目录无 Git 元数据。已知 Sprite Bonk GitHub 工作树是 Godot 工程，本次未将 Android 源码混入该工作树。
