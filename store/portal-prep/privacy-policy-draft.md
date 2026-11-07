# Privacy Policy — SpriteBonk（DRAFT / 草稿）

状态：**草稿，未发布**。托管到公开 HTTPS 页是用户关口（台账 R9 / 里程碑 M5）。
内容依据应用实测行为撰写（`scripts/wallet.gd`、`scripts/profile.gd`，2026-10-25 核对）：
游客默认、无账号系统、无服务器、无分析/广告 SDK；钱包地址仅存本机、
余额经公共 Solana RPC 只读查询、无签名无交易。
发布者主体信息一律留占位，不编造。

Publisher / 发布者：
Contact email / 联系邮箱：
Effective date / 生效日期：
Hosted URL / 托管地址：

---

## English

### Privacy Policy

SpriteBonk (the "App") is a single-player game published by
("we", "us"). This policy describes
what data the App handles. The short version: **the App has no account
system and no server operated by us, and it does not collect personal
data.**

### 1. Data stored on your device only

- **Game progress.** Your progress, captures, and settings are saved
in the App's local storage on your device. This data never leaves
your device.
- **Wallet address (optional).** If you choose to use the optional
wallet view, you paste a public Solana address into the App. The
App saves that address — and nothing else about your wallet — in
local storage on your device so you don't have to paste it again.
Choosing "disconnect" clears the saved address.

### 2. Network requests

- The App makes **no network requests at all** unless you use the
optional wallet view.
- When you do, the App sends the address you provided to a public
Solana RPC endpoint (`api.mainnet-beta.solana.com`) to read its
SOL balance (JSON-RPC `getBalance`). A wallet address and its
balance are public on-chain information. As with any HTTPS
request, the RPC operator may see technical data such as your
IP address; that handling is governed by the RPC operator, not
by us, and we receive none of it.

### 3. What we never handle

- We never ask for, receive, or store private keys, seed phrases,
or passwords. **This version of the App cannot sign anything and
cannot make transactions.**
- The App contains no analytics, advertising, or tracking SDKs
and sets no cookies.
- Because there are no accounts and no server, we have no user
database: there is nothing for us to sell, share, or leak.

### 4. Children

The App does not collect data from anyone, including minors.

### 5. Deleting your data

Disconnect the wallet inside the App to erase the saved address,
and uninstall the App to erase all locally stored game data.
Because we hold no server-side data, no separate account-deletion
process applies.

### 6. Changes and contact

If a future version changes any behavior described here (for
example, adding transaction features), this policy will be updated
and re-published before that version is submitted to the store.
Questions:

---

## 中文

### 隐私政策

《SpriteBonk》（下称「本应用」）是一款单机游戏，发布者为
（下称「我们」）。本政策说明本应用
处理数据的方式。一句话版本：**本应用没有账号系统，没有由我们
运营的服务器，不收集个人数据。**

### 1. 仅存于你设备上的数据

- **游戏进度。** 你的进度、捕获记录与设置保存在本应用在设备上
的本地存储中，永不离开你的设备。
- **钱包地址（可选）。** 若你选择使用可选的钱包查看功能，你会
把一个公开的 Solana 地址粘贴进本应用。本应用仅把该地址
（不含任何其他钱包信息）保存在设备本地，免得你每次重新粘贴。
选择「断开连接」即清除已保存的地址。

### 2. 网络请求

- 除非你使用可选的钱包查看功能，本应用**不发出任何网络请求**。
- 使用该功能时，本应用会把你提供的地址发送到公共 Solana RPC
节点（`api.mainnet-beta.solana.com`）以读取其 SOL 余额
（JSON-RPC `getBalance`）。钱包地址及其余额本就是链上公开
信息。与任何 HTTPS 请求一样，RPC 运营方可能看到你的 IP
地址等技术数据；该等处理由 RPC 运营方负责，与我们无关，
我们也不会收到这些数据。

### 3. 我们从不经手的东西

- 我们从不要求、接收或存储私钥、助记词或密码。**本版本应用
无法签名、无法发起交易。**
- 本应用不含任何分析、广告或追踪 SDK，不设置 Cookie。
- 因为没有账号、没有服务器，我们没有任何用户数据库：
没有什么可出售、可分享、可泄露的。

### 4. 未成年人

本应用不向任何人（包括未成年人）收集数据。

### 5. 删除你的数据

在本应用内断开钱包即清除已保存的地址；卸载本应用即清除全部
本地游戏数据。因我们不持有任何服务器端数据，不存在单独的
账号删除流程。

### 6. 变更与联系

若未来版本改变本政策所述的任何行为（例如加入交易功能），
本政策会先更新并重新发布，然后该版本才会提交商店审核。
问题联系：
