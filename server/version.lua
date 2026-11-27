local REPO = 'zeseides/alvis_dcchat'
local current = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '0.0.0'
local notified

local function parse(v)
    local t = {}
    for n in tostring(v):gmatch('%d+') do t[#t + 1] = tonumber(n) end
    return t
end

local function newer(a, b)
    local x, y = parse(a), parse(b)
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or 0, y[i] or 0
        if p ~= q then return p > q end
    end
    return false
end

local function check()
    PerformHttpRequest(('https://api.github.com/repos/%s/releases/latest'):format(REPO), function(status, body)
        if status ~= 200 or not body then return end
        local ok, rel = pcall(json.decode, body)
        if not ok or type(rel) ~= 'table' or not rel.tag_name then return end
        local latest = rel.tag_name:gsub('^v', '')
        if not newer(latest, current) or notified == latest then return end
        notified = latest
        print(('^3[alvis_dcchat] %s^7'):format(Config.Messages.update:format(latest, current)))
        print(('^3[alvis_dcchat] %s^7'):format(rel.html_url or ('https://github.com/' .. REPO .. '/releases/latest')))
        local notes = (rel.body or ''):gsub('\r', '')
        if notes ~= '' then
            for line in notes:sub(1, 600):gmatch('[^\n]+') do print('  ' .. line) end
        end
    end, 'GET', '', { ['User-Agent'] = 'alvis_dcchat', ['Accept'] = 'application/vnd.github+json' })
end

if Config.UpdateCheck then
    CreateThread(function()
        Wait(10000)
        while true do
            check()
            Wait(math.max(tonumber(Config.UpdateCheckHours) or 6, 1) * 3600000)
        end
    end)
end
