# Devnet 商店订单原型

`tools/devnet_orders.py` 是仅供本地操作的订单工具，使用 Python 标准库和 SQLite。RPC 固定在 Devnet。收款配置由运行方提供，工具不保存或读取密钥。

设置 `SPRITEBONK_DEVNET_MINT`（测试 SPL mint）、`SPRITEBONK_DEVNET_TOKEN_ACCOUNT`（预先创建的收款代币账户）、`SPRITEBONK_DEVNET_AMOUNT`（整数最小单位金额）。数据库放在仓库外。

下单前会到 Devnet 查询收款代币账户，要求它已初始化且 mint 与配置相同。当前原型只接受标准 SPL Token 程序的收款账户。配置缺失或校验失败时不写订单。

- `python tools/devnet_orders.py --db <db> create <payer>` 生成唯一订单号及 15 分钟报价。
- 钱包交易应包含以订单号为内容的 SPL Memo，以及付款钱包授权的 TransferChecked 指令。
- `python tools/devnet_orders.py --db <db> settle <order-id> <signature>` 校验 Devnet 最终确认的交易。重复提交同一签名和订单返回同一结果。只有交易通过后才在一个数据库事务中写入付款与库存。
- `python tools/devnet_orders.py --db <db> inventory <payer>` 本地查看权益。

## 本地 HTTP API

安装 Python 的 `cryptography`（本轮使用 50.0.0），运行 `python tools/devnet_api.py --db <db>`。仅监听 127.0.0.1:8765，供本机开发。正式部署需要 HTTPS、独立鉴权限流及运维方案。

| POST 路由 | JSON 请求 |
| --- | --- |
| /auth/challenge | `{"wallet":"<base58 公钥>"}` |
| /auth/session | `{"nonce":"<服务端返回值>","signature":"<原文 UTF-8 的 Ed25519 签名，以 Base64 编码>"}` |
| /orders/create | `{}` |
| /orders/list | `{}` |
| /orders/settle | `{"orderId":"<订单号>","signature":"<链上交易签名>"}` |
| /inventory | `{}` |

订单和库存请求带 `Authorization: Bearer <token>`。钱包挑战有效五分钟且只能使用一次，服务器保存令牌哈希，有效一小时。重复登录同一钱包可恢复订单和库存。测试手机可经 ADB reverse 接本机 API，Compose 结账、异常付款对账和真实 Devnet 交易仍待接入。

## Seeker 联调记录

2026-11-20，安装提交 `ae0b3d8` 对应的调试包，通过 ADB reverse 连接本机 API。用户完成钱包签名，游戏显示「钱包登录成功」，本机数据库存在有效会话，游戏成功查询并显示「订单 0 笔 · 已解锁 0 件」。尚未配置实链测试 mint 和收款账户，未创建链上付款。
