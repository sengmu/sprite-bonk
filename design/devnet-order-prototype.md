# Devnet 商店订单原型

`tools/devnet_orders.py` 是仅供本地操作的订单工具，使用 Python 标准库和 SQLite。RPC 固定在 Devnet。收款配置由运行方提供，工具不保存或读取密钥。

设置 `SPRITEBONK_DEVNET_MINT`（测试 SPL mint）、`SPRITEBONK_DEVNET_TOKEN_ACCOUNT`（预先创建的收款代币账户）、`SPRITEBONK_DEVNET_AMOUNT`（整数最小单位金额）。数据库放在仓库外。

下单前会到 Devnet 查询收款代币账户，要求它已初始化且 mint 与配置相同。当前原型只接受标准 SPL Token 程序的收款账户。配置缺失或校验失败时不写订单。

- `python tools/devnet_orders.py --db <db> create <payer>` 生成唯一订单号及 15 分钟报价。
- 钱包交易应包含以订单号为内容的 SPL Memo，以及付款钱包授权的 TransferChecked 指令。
- `python tools/devnet_orders.py --db <db> settle <order-id> <signature>` 校验 Devnet 最终确认的交易。重复提交同一签名和订单返回同一结果。只有交易通过后才在一个数据库事务中写入付款与库存。
- `python tools/devnet_orders.py --db <db> inventory <payer>` 本地查看权益。

## 本地 HTTP API

安装 `tools/devnet-requirements.txt` 的 Python 依赖后，运行 `python tools/devnet_api.py --db <db>`。仅监听 127.0.0.1:8765，供本机开发。正式部署需要 HTTPS、独立鉴权限流及运维方案。

| POST 路由 | JSON 请求 |
| --- | --- |
| /auth/challenge | `{"wallet":"<base58 公钥>"}` |
| /auth/session | `{"nonce":"<服务端返回值>","signature":"<原文 UTF-8 的 Ed25519 签名，以 Base64 编码>"}` |
| /orders/create | `{}` |
| /orders/list | `{}` |
| /orders/payment | `{"orderId":"<订单号>"}`，返回 Base64 未签名交易、最后有效区块高度及 lamports 手续费 |
| /orders/broadcast | `{"orderId":"<订单号>","transaction":"<Base64 已签名交易>"}` |
| /orders/settle | `{"orderId":"<订单号>","signature":"<链上交易签名>"}` |
| /inventory | `{}` |

订单和库存请求带 `Authorization: Bearer <token>`。钱包挑战有效五分钟且只能使用一次，服务器保存令牌哈希，有效一小时。重复登录同一钱包可恢复订单和库存。测试手机可经 ADB reverse 接本机 API，Compose 结账、异常付款对账和真实 Devnet 交易仍待接入。

## Seeker 联调记录

2026-11-20，安装提交 `ae0b3d8` 对应的调试包，通过 ADB reverse 连接本机 API。用户完成钱包签名，游戏显示「钱包登录成功」，本机数据库存在有效会话，游戏成功查询并显示「订单 0 笔 · 已解锁 0 件」。尚未配置实链测试 mint 和收款账户，未创建链上付款。

2026-11-20，Seeker 完成订单 `11aa984e0e2e3bbd56e030133daefcb3`，支付 1 枚 Devnet 测试代币。交易 `4y1zFiH4n2sksMcuK28A6k7D84yGJHVLs8JeRCy9MzH4mghqfy5R42u6PX74o4UdavgJQGnhuMpdeHmJnMQS1Nf5` 已最终确认且无链上错误。同一回执连续结算两次均返回 fulfilled，数据库中只有一条外观权益。手机查验显示「已到账，外观已发放」。装备界面暂未接入。

钱包负责签名，服务端比对签名者、账户权限、付款指令和区块哈希，再向 Devnet 提交。仅允许两种合法计算预算指令，优先费上限 10,000 lamports。测试中发生过区块哈希过期，旧单先核对未到账再重新下单。

装备续验：Seeker 登录原付款钱包后库存显示已解锁 1 件。点击「装备雷铃狐外观」后，首页预览切换成蓝紫配色。冷启动后外观继续生效，见 [首页实拍](ui-reference/compare/Devnet-fox-equipped.png)。从首页用雷铃狐开始冒险，战斗角色也使用同一外观，见 [战斗实拍](ui-reference/compare/Devnet-fox-battle.png)。

库存恢复续验：Seeker 安装 `ba55f68` 的调试包并冷启动。原钱包完成登录后，商店自动显示「已拥有 · 雷铃狐外观」和「已解锁 1 件」。另用临时钱包通过同一本机 API 完成真实签名登录，返回 0 笔订单、0 件库存，尝试查原订单返回 HTTP 404。手机上切到第二钱包后的外观显示尚未实拍。
