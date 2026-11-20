# Devnet 商店订单原型

`tools/devnet_orders.py` 是仅供本地操作的订单工具，使用 Python 标准库和 SQLite。RPC 固定在 Devnet。收款配置由运行方提供，工具不保存或读取密钥。

设置 `SPRITEBONK_DEVNET_MINT`（测试 SPL mint）、`SPRITEBONK_DEVNET_TOKEN_ACCOUNT`（预先创建的收款代币账户）、`SPRITEBONK_DEVNET_AMOUNT`（整数最小单位金额）。数据库放在仓库外。

- `python tools/devnet_orders.py --db <db> create <payer>` 生成唯一订单号及 15 分钟报价。
- 钱包交易应包含以订单号为内容的 SPL Memo，以及付款钱包授权的 TransferChecked 指令。
- `python tools/devnet_orders.py --db <db> settle <order-id> <signature>` 校验 Devnet 最终确认的交易。重复提交同一签名和订单返回同一结果。只有交易通过后才在一个数据库事务中写入付款与库存。
- `python tools/devnet_orders.py --db <db> inventory <payer>` 本地查看权益。

这是交易验证与持久化的第一段。面向设备的 API、钱包身份挑战、Compose 结账、异常付款对账和真实 Devnet 交易验收仍待接入。本地工具的付款人参数由操作者提供，不能直接暴露为玩家鉴权。
