Config = {}

-- 進服時必須有 Discord(玩家需開著 Discord 並在 FiveM 設定連結)
Config.RequireDiscord = true

-- 一個遊戲帳號(license)只能綁一個 Discord,反之亦然。解除綁定: 控制台 dcunlink <license 或 discord id>
Config.LockAccount = true

-- 'builtin'  插件自己處理一般聊天(沒有其他聊天插件的伺服器用這個)
-- 'external' 由你的聊天插件呼叫 export(見 README),例如 rpchat
Config.ChatMode = 'builtin'

-- builtin 模式下,遊戲內聊天顯示的名字: 'game' 遊戲名稱 / 'discord' Discord 名稱
Config.InGameName = 'game'

-- 在 Discord 群組被禁言(Timeout)的玩家,遊戲內也不能發言
Config.MuteSync = true

-- 遊戲內顯示 Discord 訊息的設定
Config.DiscordLabel = '[DC]'
Config.DiscordLabelColor = '88, 101, 242'
Config.MaxImages = 4
Config.MaxTextLength = 500

-- 發言冷卻(秒),遊戲和 Discord 兩邊各自計算,同一人在冷卻內的訊息會被擋下。0 = 關閉
Config.Cooldown = 0.5

-- 機器人狀態顯示在線人數。%d 依序為在線人數、人數上限
Config.Presence = true
Config.PresenceText = '在線 %d/%d'
Config.PresenceInterval = 60

-- 啟動時與每隔幾小時檢查 GitHub 是否有新版本,有的話在伺服器控制台提醒
Config.UpdateCheck = true
Config.UpdateCheckHours = 6

Config.Messages = {
    checking = '正在確認 Discord 綁定...',
    noLicense = '無法取得你的 Rockstar 授權,請重新啟動 FiveM',
    noDiscord = '本伺服器必須綁定 Discord。請先開啟 Discord 桌面版,並在 FiveM 設定裡連結 Discord 帳號,然後重新啟動 FiveM 再連線',
    licenseTaken = '這個遊戲帳號已綁定其他 Discord 帳號,請用原本的 Discord 登入,或聯絡管理員解除綁定',
    discordTaken = '這個 Discord 帳號已綁定其他遊戲帳號,請聯絡管理員解除綁定',
    muted = '你在 Discord 被禁言中,暫時無法發言',
    cooldown = '發言太快了,請稍等一下',
    system = '系統',
    reply = '回覆 %s',
    update = '有新版本 v%s 可以更新(目前 v%s)',
}
