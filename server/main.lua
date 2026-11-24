local TOKEN = GetConvar('dcchat_token', '')
local WEBHOOK = GetConvar('dcchat_webhook', '')
local API = 'https://discord.com/api/v10'
local M = Config.Messages

local guild = ''
local profiles = {}
local byDiscord = {}

local function identifierOf(src, kind)
    local id = GetPlayerIdentifierByType(src, kind)
    return id and id:gsub('^' .. kind .. ':', '') or nil
end

local function utcEpoch(iso)
    local y, mo, d, h, mi, s = tostring(iso or ''):match('^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)')
    if not y then return 0 end
    local t = os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = s, isdst = false })
    local now = os.time()
    return t + (now - os.time(os.date('!*t', now)))
end

local function api(path)
    local p = promise.new()
    PerformHttpRequest(API .. path, function(status, body)
        local ok, data = pcall(json.decode, body or '')
        p:resolve({ status = status, data = ok and data or nil })
    end, 'GET', '', { Authorization = 'Bot ' .. TOKEN })
    return Citizen.Await(p)
end

local function avatarUrl(id, user, member)
    if member and member.avatar and guild ~= '' then
        return ('https://cdn.discordapp.com/guilds/%s/users/%s/avatars/%s.png?size=64'):format(guild, id, member.avatar)
    end
    if user and user.avatar then
        return ('https://cdn.discordapp.com/avatars/%s/%s.png?size=64'):format(id, user.avatar)
    end
    return ('https://cdn.discordapp.com/embed/avatars/%d.png'):format((math.tointeger(tonumber(id)) >> 22) % 6)
end

local function displayName(user, member)
    return (member and member.nick) or (user and (user.global_name or user.username)) or '?'
end

local function setProfile(src, id, user, member)
    local p = {
        id = id,
        name = displayName(user, member),
        avatar = avatarUrl(id, user, member),
        mutedUntil = utcEpoch(member and member.communication_disabled_until),
    }
    if p.name == '?' then p.name = GetPlayerName(src) or '?' end
    profiles[src] = p
    byDiscord[id] = src
end

local function loadProfile(src)
    local id = identifierOf(src, 'discord')
    if not id or TOKEN == '' then return end
    local member, user
    if guild ~= '' then
        local r = api(('/guilds/%s/members/%s'):format(guild, id))
        if r.status == 200 and r.data then member, user = r.data, r.data.user end
    end
    if not user then
        local r = api('/users/' .. id)
        if r.status == 200 then user = r.data end
    end
    if not user and profiles[src] then return end
    setProfile(src, id, user, member)
end

local function loadAll()
    for _, src in ipairs(GetPlayers()) do
        loadProfile(tonumber(src))
        Wait(200)
    end
end

AddEventHandler('alvis_dcchat:config', function(g)
    guild = tostring(g or '')
    CreateThread(loadAll)
end)

AddEventHandler('alvis_dcchat:member', function(d)
    local id = d and d.user and d.user.id
    local src = id and byDiscord[id]
    if src and profiles[src] and profiles[src].id == id then
        setProfile(src, id, d.user, d)
    end
end)

if Config.LockAccount then
    MySQL.ready(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS alvis_dcchat_link (
            license VARCHAR(64) NOT NULL PRIMARY KEY,
            discord VARCHAR(32) NOT NULL UNIQUE,
            linked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )]])
    end)
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    if not Config.RequireDiscord and not Config.LockAccount then return end
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update(M.checking)
    local license = identifierOf(src, 'license')
    local discord = identifierOf(src, 'discord')
    if not discord then
        return deferrals.done(Config.RequireDiscord and M.noDiscord or nil)
    end
    if not Config.LockAccount then return deferrals.done() end
    if not license then return deferrals.done(M.noLicense) end
    local rows = MySQL.query.await('SELECT license, discord FROM alvis_dcchat_link WHERE license = ? OR discord = ?', { license, discord }) or {}
    for _, row in ipairs(rows) do
        if row.license == license and row.discord ~= discord then return deferrals.done(M.licenseTaken) end
        if row.discord == discord and row.license ~= license then return deferrals.done(M.discordTaken) end
    end
    if #rows == 0 then
        MySQL.insert.await('INSERT INTO alvis_dcchat_link (license, discord) VALUES (?, ?)', { license, discord })
    end
    deferrals.done()
end)

AddEventHandler('playerJoining', function()
    local src = source
    CreateThread(function() loadProfile(src) end)
end)

AddEventHandler('playerDropped', function()
    local p = profiles[source]
    if p and byDiscord[p.id] == source then byDiscord[p.id] = nil end
    profiles[source] = nil
end)

RegisterCommand('dcunlink', function(src, args)
    if src ~= 0 or not args[1] then return print('usage (console only): dcunlink <license or discord id>') end
    local n = MySQL.update.await('DELETE FROM alvis_dcchat_link WHERE license = ? OR discord = ?', { args[1], args[1] })
    print(('alvis_dcchat: removed %d link(s)'):format(n or 0))
end, true)

local function escapeHtml(s)
    return (tostring(s):gsub('[&<>"\']', { ['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;', ['"'] = '&quot;', ["'"] = '&#39;' }))
end

local function safeUrl(u)
    if type(u) ~= 'string' or #u > 600 then return nil end
    if not (u:match('^https://cdn%.discordapp%.com/') or u:match('^https://media%.discordapp%.net/')
        or u:match('^https://images%-ext%-%d+%.discordapp%.net/') or u:match('^https://media%d*%.tenor%.com/')
        or u:match('^https://media%d*%.giphy%.com/')) then return nil end
    if u:find('[%s"\'<>\\`]') then return nil end
    return u
end

local function avatarImg(url)
    url = safeUrl(url)
    return url and ('<img src="%s" style="width:1.6em;height:1.6em;border-radius:50%%;vertical-align:middle;margin-right:0.3em;object-fit:cover">'):format(url) or ''
end

local function avatarTag(src)
    local p = profiles[tonumber(src)]
    return p and avatarImg(p.avatar) or ''
end

local function isMuted(src)
    local p = Config.MuteSync and profiles[tonumber(src)]
    return p and p.mutedUntil > os.time() or false
end

local queue, sending = {}, false

local function pump()
    if sending then return end
    sending = true
    CreateThread(function()
        while #queue > 0 do
            local p = promise.new()
            PerformHttpRequest(WEBHOOK, function(status, resp)
                p:resolve({ status = status, resp = resp })
            end, 'POST', queue[1], { ['Content-Type'] = 'application/json' })
            local r = Citizen.Await(p)
            if r.status == 429 then
                local ok, d = pcall(json.decode, r.resp or '')
                Wait(math.ceil(((ok and d and d.retry_after) or 1) * 1000) + 100)
            else
                table.remove(queue, 1)
                Wait(400)
            end
        end
        sending = false
    end)
end

local function relay(src, text)
    local p = profiles[tonumber(src)]
    if WEBHOOK == '' or not p then return end
    text = tostring(text):gsub('%^%d', ''):sub(1, 1900)
    if text:match('^%s*$') then return end
    local name = p.name:gsub('[Dd][Ii][Ss][Cc][Oo][Rr][Dd]', 'D1scord'):gsub('[Cc][Ll][Yy][Dd][Ee]', 'Cl yde'):sub(1, 80)
    if #queue >= 50 then table.remove(queue, 1) end
    queue[#queue + 1] = json.encode({ username = name, avatar_url = p.avatar, content = text, allowed_mentions = { parse = {} } })
    pump()
end

local function notifyMuted(src)
    TriggerClientEvent('chat:addMessage', src, { args = { M.system, M.muted } })
end

exports('avatarTag', avatarTag)
exports('isMuted', function(src)
    if isMuted(src) then notifyMuted(src) return true end
    return false
end)
exports('relay', relay)
exports('profile', function(src)
    local p = profiles[tonumber(src)]
    return p and { id = p.id, name = p.name, avatar = p.avatar } or nil
end)

local function renderText(text)
    local out, pos = {}, 1
    for s, anim, id, e in text:gmatch('()<(a?):[%w_~]+:(%d+)>()') do
        out[#out + 1] = escapeHtml(text:sub(pos, s - 1))
        out[#out + 1] = ('<img src="https://cdn.discordapp.com/emojis/%s.%s?size=48" style="height:1.4em;vertical-align:middle">'):format(id, anim == 'a' and 'gif' or 'png')
        pos = e
    end
    out[#out + 1] = escapeHtml(text:sub(pos))
    return table.concat(out)
end

AddEventHandler('alvis_dcchat:message', function(msg)
    if type(msg) ~= 'table' or not msg.author then return end
    local id = tostring(msg.author.id)
    local text = tostring(msg.text or ''):gsub('%^%d', ''):sub(1, Config.MaxTextLength)
    local html = {
        '<div style="padding:0.1vw;margin:0.1vw;font-weight:bold;font-size:16px;word-break:break-all;">',
        avatarImg(avatarUrl(id, msg.author, msg.member)),
        ('<span style="color:rgb(%s);">%s</span> '):format(Config.DiscordLabelColor, escapeHtml(Config.DiscordLabel)),
        '<span style="color:rgb(220,220,220);">', escapeHtml(displayName(msg.author, msg.member):sub(1, 80)), '</span>',
        msg.replyTo and ('<span style="color:rgb(150,150,150);font-weight:normal;"> %s</span>'):format(escapeHtml(M.reply:format(tostring(msg.replyTo):sub(1, 80)))) or '',
        ' ^0: ',
        renderText(text),
    }
    local n = 0
    for _, u in ipairs(type(msg.images) == 'table' and msg.images or {}) do
        u = safeUrl(u)
        if u and n < Config.MaxImages then
            n = n + 1
            html[#html + 1] = ('<img src="%s" style="display:block;max-height:14vh;max-width:18vw;border-radius:6px;margin-top:0.3em">'):format(u)
        end
    end
    html[#html + 1] = '</div>'
    TriggerClientEvent('chat:addMessage', -1, { template = table.concat(html), args = {} })
end)

if Config.ChatMode == 'builtin' then
    AddEventHandler('chatMessage', function(src, name, message)
        if message:sub(1, 1) == '/' then return end
        CancelEvent()
        if isMuted(src) then return notifyMuted(src) end
        local p = profiles[src]
        local shown = Config.InGameName == 'discord' and p and p.name or name
        TriggerClientEvent('chat:addMessage', -1, {
            template = '<div style="padding:0.1vw;margin:0.1vw;word-break:break-all;">' .. avatarTag(src) .. '<b>{0}</b>: {1}</div>',
            args = { shown, message },
        })
        relay(src, message)
    end)
end
