# alvis_dcchat

讓遊戲內聊天和 Discord 頻道互通。遊戲裡打的字會用玩家自己的 Discord 名字和頭像出現在頻道裡(看起來像本人發的),Discord 的訊息也會帶頭像、表情、貼圖和圖片出現在遊戲聊天框。

由 Alvis 獨立製作。

## 功能

- 遊戲 → Discord:用 Webhook 發送,每則訊息顯示玩家的 Discord 名稱與頭像
- Discord → 遊戲:顯示 `[DC] 名字`、頭像、自訂表情、貼圖、圖片、GIF(Tenor / Klipy / Giphy),回覆訊息會顯示「回覆 某某」
- 遊戲聊天框顯示每位玩家的 Discord 頭像
- 進服強制綁定 Discord,可鎖定一個遊戲帳號只能對應一個 Discord
- 在 Discord 群組被禁言(Timeout)的玩家,遊戲內也無法發言,即時同步
- 玩家在遊戲內無法 @everyone 或 @身分組
- 不需要另外架機器人程式,Discord 連線直接跑在 FXServer 裡

## 需求

- FXServer 近期版本(內建 Node 22,需支援 WebSocket)
- `oxmysql`(用來記錄帳號綁定)
- 預設 `chat` 資源,或任何使用 `chat:addMessage` 的聊天介面
- 不依賴任何框架(ESX、QBCore、獨立伺服器皆可)

## 安裝

### 1. 建立 Discord 機器人

1. 到 <https://discord.com/developers/applications> 按 **New Application**
2. 左側 **Bot**:按 **Reset Token** 取得 token(只會顯示一次,請保存)
3. 同一頁往下,打開 **Server Members Intent** 和 **Message Content Intent**,存檔
4. 左側 **OAuth2 → URL Generator**:Scopes 勾 `bot`,Bot Permissions 勾 `View Channels`、`Read Message History`,用產生的網址把機器人邀進你的群組

### 2. 建立 Webhook

在要互通的頻道:**編輯頻道 → 整合 → Webhook → 新 Webhook**,複製 Webhook 網址。機器人只會讀取這個 Webhook 所在的頻道。

### 3. 安裝資源

把 `alvis_dcchat` 資料夾放進 `resources/`,在 `server.cfg` 加入:

```
set dcchat_token "你的機器人 token"
set dcchat_webhook "你的 Webhook 網址"

ensure oxmysql
ensure chat
ensure alvis_dcchat
```

token 和 webhook 等同密碼,請不要上傳到公開的 git 或分享給別人。用 `set`(不要用 `setr`),玩家端才讀不到。

### 4. 重啟伺服器

主控台出現 `[alvis_dcchat] connected as 機器人名稱` 就代表連上了。資料表 `alvis_dcchat_link` 會自動建立。

## 設定(config.lua)

| 設定 | 說明 |
|---|---|
| `RequireDiscord` | 沒有連結 Discord 的玩家無法進服 |
| `LockAccount` | 一個遊戲帳號只能綁一個 Discord,反之亦然 |
| `ChatMode` | `builtin`:插件自己處理一般聊天。`external`:你已有聊天插件,改用 export 串接(見下方) |
| `InGameName` | builtin 模式下遊戲內顯示的名字:`game` 或 `discord` |
| `MuteSync` | Discord 禁言同步到遊戲 |
| `DiscordLabel` / `DiscordLabelColor` | Discord 訊息前的標籤和顏色 |
| `MaxImages` / `MaxTextLength` | Discord 訊息在遊戲內最多顯示幾張圖、幾個字 |
| `Messages` | 所有提示文字,可自行翻譯 |

## 搭配既有聊天插件(external 模式)

如果你的伺服器已經有自訂聊天插件(例如 rpchat),把 `Config.ChatMode` 設成 `external`,然後在該插件送出一般聊天的地方呼叫:

```lua
local dc = exports.alvis_dcchat

if dc:isMuted(source) then return end

local avatar = dc:avatarTag(source)
TriggerClientEvent('chat:addMessage', -1, {
    template = '<div>' .. avatar .. '<b>{0}</b>: {1}</div>',
    args = { name, message },
})

dc:relay(source, message)
```

| Export | 說明 |
|---|---|
| `isMuted(source)` | 玩家是否在 Discord 被禁言,是的話會自動提示玩家並回傳 `true` |
| `avatarTag(source)` | 回傳玩家頭像的 `<img>` HTML,可放進 chat template |
| `relay(source, text)` | 把文字用玩家的名字和頭像送到 Discord 頻道 |
| `profile(source)` | 回傳 `{ id, name, avatar }`,沒有資料時回傳 `nil` |

## 管理指令

`dcunlink <license 或 discord id>`:解除綁定(只能在伺服器主控台使用)。玩家換 Discord 帳號時用。

## 常見問題

- **玩家說有開 Discord 還是進不去**:要用 Discord 桌面版,開著的情況下重新啟動 FiveM。FiveM 設定裡也可以手動連結
- **主控台顯示 gateway closed with 4014**:沒有打開 Message Content Intent 或 Server Members Intent
- **主控台顯示 4004**:token 錯誤,重新產生並更新 `dcchat_token`
- **Discord 名字旁邊有 APP 標籤**:這是 Discord 對所有 Webhook 訊息的強制標示,無法移除
- **訊息量很大時有延遲**:Discord 對 Webhook 有速率限制,插件會自動排隊重送,不會遺失(佇列上限 50 則)

## 授權

MIT License,可自由使用、修改、再發布,請保留作者標示。

---

## English

Bridges in-game chat with a Discord channel. Game messages are posted through a webhook with each player's own Discord name and avatar; Discord messages show up in game with avatar, custom emoji, stickers and images. Forces Discord linking on connect, optionally locks one license to one Discord account, and syncs Discord timeouts to in-game chat. The Discord gateway runs inside FXServer (Node 22), no external bot process.

Setup: create a bot with Server Members and Message Content intents, invite it, create a webhook in the channel, then add to `server.cfg`:

```
set dcchat_token "bot token"
set dcchat_webhook "webhook url"
ensure alvis_dcchat
```

Requires `oxmysql`. Use `Config.ChatMode = 'external'` and the exports above if you already run a custom chat resource.
