--[[
    🦕 Ride A Dino! [⚡] — Ultimate Energy & Base Autofarm (Minimalist Anime Edition)
    Разработано под игру "Ride A Dino!" (PlaceId: 93523763376122)
    
    Фокус: Исключительно чистый фарм энергии (хвата) и прокачка базы!
    
    Возможности:
    - ⚡ Непрерывная тренировка энергии / хвата (Grip Auto-Train)
    - 🦾 Авто-покупка лучших тренажеров (Machine Tiers)
    - 🏡 Авто-прокачка загона с авто-телепортом ($/сек доход)
    - ✨ Авто-покупка и экипировка лучших аур (Grip Multipliers)
    - 🎁 Авто-сбор оффлайн наград и подарков (Offline Rewards & Gifts)
    - 💎 Кнопка «Экипировать лучшее» (Equip Best в один клик)
    - 🛡️ Защита Anti-AFK от дисконнекта
    - 🎨 Аниме стили WindUI (Sakura Pink, Crimson Blood, Dark Minimal)
    - 📡 Discord Вебхук со статистикой базы и обходом блокировок
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

-- Универсальный поиск функции HTTP-запросов во всех экзекуторах
local function getHttpRequest()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if http and type(http.request) == "function" then return http.request end
    if Fluxus and type(Fluxus.request) == "function" then return Fluxus.request end
    if getgenv then
        local ok, g = pcall(getgenv)
        if ok and type(g) == "table" then
            if type(g.request) == "function" then return g.request end
            if type(g.http_request) == "function" then return g.http_request end
            if g.syn and type(g.syn.request) == "function" then return g.syn.request end
            if g.http and type(g.http.request) == "function" then return g.http.request end
            if g.Fluxus and type(g.Fluxus.request) == "function" then return g.Fluxus.request end
        end
    end
    return nil
end

local function sanitizeWebhookUrl(rawUrl)
    if not rawUrl or type(rawUrl) ~= "string" then return "" end
    return rawUrl:gsub("^%s*[\"']*", ""):gsub("[\"']*[%s\r\n]*$", ""):gsub("%s+", "")
end

local httpRequest = getHttpRequest()

local LocalPlayer = Players.LocalPlayer

-- Игровые модули Ride A Dino
local RideADino = ReplicatedStorage:WaitForChild("RideADino", 15)
assert(RideADino, "Не удалось найти RideADino в ReplicatedStorage")

local Net = require(RideADino.Shared.Net)
local Format = require(RideADino.Shared.Format)
local Gear = require(RideADino.Config.Gear)
local Training = require(RideADino.Config.Training)
local Ranch = require(RideADino.Config.Ranch)
local Auras = require(RideADino.Config.Auras)

local ClientModules = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("RideADinoClient"):WaitForChild("Modules")
local NetBridge = require(ClientModules:WaitForChild("NetBridge"))
local GearMachine = require(ClientModules:WaitForChild("GearMachine"))
local AuraShopModule = require(ClientModules:WaitForChild("AuraShop"))
local IndexModule = require(ClientModules:WaitForChild("Index"))

-- Очистка старых окон WindUI
local function cleanupOldUI()
    pcall(function()
        local cg = game:GetService("CoreGui")
        for _, c in ipairs(cg:GetChildren()) do
            if c:IsA("ScreenGui") and c.Name:find("WindUI") then
                c:Destroy()
            end
        end
        local rg = cg:FindFirstChild("RobloxGui")
        if rg then
            for _, c in ipairs(rg:GetChildren()) do
                if c:IsA("ScreenGui") and c.Name:find("WindUI") then
                    c:Destroy()
                end
            end
        end
    end)
end
cleanupOldUI()

-- Загрузка UI библиотеки WindUI
local WindUISuccess, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not WindUISuccess or type(WindUI) ~= "table" then
    WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end

-- Безопасные уведомления (никогда не крашат поток исполнения)
local function safeNotify(options)
    task.spawn(function()
        pcall(function()
            if setthreadidentity then setthreadidentity(8) end
            if WindUI and WindUI.Notify then
                WindUI:Notify(options)
            end
        end)
    end)
end

local function safeSetDesc(element, desc)
    pcall(function()
        if element and element.SetDesc then
            element:SetDesc(desc)
        end
    end)
end

-- Конфигурация бота (Фарм энергии и базы)
local Config = {
    AutoTrain = true,                 -- Авто-тренировка энергии (хвата)
    AutoPen = true,                   -- Авто-прокачка загона ($/сек доход)
    AutoMachine = true,               -- Авто-покупка тренажеров следующего тира
    AutoAura = true,                  -- Авто-покупка и экипировка аур (множители)
    AutoClaim = true,                 -- Авто-сбор оффлайн наград и подарков
    AutoClaimIndex = true,            -- Авто-сбор наград Индекса
    AntiAFK = true,                   -- Защита от AFK кика
    ChillVisuals = false,             -- Космическая неон-аура и шлейф (визуал)
    Theme = "🌸 Sakura Pink (Тянка 1)",
    BgTransparency = 0.35,
    CheckInterval = 2,
    ToggleKey = "RightControl",       -- Клавиша открытия/скрытия меню
    ToggleKeyCode = Enum.KeyCode.RightControl,
    DiscordWebhook = "",              -- URL вебхука Discord
    WebhookUseProxy = true,           -- Обход блокировки Discord в РФ через прокси lewisakura
    WebhookPeriodic = false,          -- Периодический отчет (каждые 15 минут)
    WebhookInterval = 900,            -- 15 минут в секундах
}

local BotState = {
    Running = true,
    LastCheck = 0,
    LastClaim = 0,
    LastAuraCheck = 0,
    LastWebhookReport = 0,
}

local function isAlive()
    if not BotState.Running then return false end
    if typeof(STATE) == "table" and STATE.alive and not STATE.alive() then
        return false
    end
    return true
end

-- ==================== ЧИЛ-ВИЗУАЛ: АУРА, ПАРТИКЛЫ И ШЛЕЙФ ====================
local function applyChillVisuals(enable)
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local oldAtt = hrp:FindFirstChild("ChillAuraAttachment")
        if oldAtt then oldAtt:Destroy() end
        local oldHl = char:FindFirstChild("ChillHighlight")
        if oldHl then oldHl:Destroy() end
        local oldTr = hrp:FindFirstChild("ChillTrail")
        if oldTr then oldTr:Destroy() end
        local a0 = hrp:FindFirstChild("TrailAtt0")
        if a0 then a0:Destroy() end
        local a1 = hrp:FindFirstChild("TrailAtt1")
        if a1 then a1:Destroy() end

        if not enable then return end

        -- Аттачмент ауры
        local att = Instance.new("Attachment")
        att.Name = "ChillAuraAttachment"
        att.Position = Vector3.new(0, -1, 0)
        att.Parent = hrp

        -- Неоновые космические искры
        local pe = Instance.new("ParticleEmitter")
        pe.Name = "ChillSparkles"
        pe.Texture = "rbxassetid://6071575925"
        pe.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 70, 255)),   -- Неоновый фиолетовый
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 230, 255)),  -- Неоновый бирюзовый
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 190))    -- Неоновый розовый
        })
        pe.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(0.6, 0.6),
            NumberSequenceKeypoint.new(1, 0)
        })
        pe.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(0.8, 0.4),
            NumberSequenceKeypoint.new(1, 1)
        })
        pe.LightEmission = 1
        pe.LightInfluence = 0
        pe.Lifetime = NumberRange.new(1.0, 1.8)
        pe.Rate = 24
        pe.Speed = NumberRange.new(2.5, 4.5)
        pe.SpreadAngle = Vector2.new(45, 45)
        pe.EmissionDirection = Enum.NormalId.Top
        pe.Drag = 1
        pe.Parent = att

        -- Космический туман
        local mist = Instance.new("ParticleEmitter")
        mist.Name = "ChillMist"
        mist.Texture = "rbxassetid://243664672"
        mist.Color = ColorSequence.new(Color3.fromRGB(140, 60, 255), Color3.fromRGB(0, 200, 255))
        mist.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1.2),
            NumberSequenceKeypoint.new(1, 2.5)
        })
        mist.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.6),
            NumberSequenceKeypoint.new(0.5, 0.75),
            NumberSequenceKeypoint.new(1, 1)
        })
        mist.LightEmission = 0.8
        mist.LightInfluence = 0
        mist.Lifetime = NumberRange.new(1.5, 2.2)
        mist.Rate = 12
        mist.Speed = NumberRange.new(1, 2)
        mist.EmissionDirection = Enum.NormalId.Top
        mist.Parent = att

        -- Световой шлейф шагов (Ribbon Trail)
        local att0 = Instance.new("Attachment")
        att0.Name = "TrailAtt0"
        att0.Position = Vector3.new(0, -1.8, 0.4)
        att0.Parent = hrp

        local att1 = Instance.new("Attachment")
        att1.Name = "TrailAtt1"
        att1.Position = Vector3.new(0, -1.8, -0.4)
        att1.Parent = hrp

        local tr = Instance.new("Trail")
        tr.Name = "ChillTrail"
        tr.Attachment0 = att0
        tr.Attachment1 = att1
        tr.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 240, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(160, 60, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 180))
        })
        tr.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 1)
        })
        tr.Lifetime = 0.6
        tr.MinLength = 0.1
        tr.LightEmission = 1
        tr.FaceCamera = true
        tr.Parent = hrp

        -- Неоновый контур персонажа
        local hl = Instance.new("Highlight")
        hl.Name = "ChillHighlight"
        hl.FillColor = Color3.fromRGB(130, 60, 240)
        hl.FillTransparency = 0.8
        hl.OutlineColor = Color3.fromRGB(0, 240, 255)
        hl.OutlineTransparency = 0.2
        hl.Adornee = char
        hl.Parent = char
    end)
end

-- ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================
local function getMyStand()
    local userId = LocalPlayer.UserId
    local machines = workspace:FindFirstChild("RideADinoMachines")
    if machines then
        for i = 1, 8 do
            local m = machines:FindFirstChild("Plot" .. i)
            if m and m:GetAttribute("Owner") == userId then
                return m, i
            end
        end
    end
    local p8 = machines and machines:FindFirstChild("Plot8")
    return p8 or (machines and machines:GetChildren()[1]), 8
end

local function getMyPen()
    local _, plotNum = getMyStand()
    local pens = workspace:FindFirstChild("Pens")
    local pen = pens and pens:FindFirstChild("Plot" .. tostring(plotNum))
    return pen, plotNum
end

local function isPlayerOnMachine()
    local char = LocalPlayer.Character
    if not char then return false end
    if char:GetAttribute("TrainingMachine") == true then
        return true
    end
    if GearMachine and GearMachine.state and GearMachine.state.mine ~= nil then
        return true
    end
    return false
end

local function teleportToStandAndMount()
    local stand = getMyStand()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not stand or not hrp then return end

    -- Если оседлан динозавр в хабе, спешиваемся
    if char:GetAttribute("HubMountSpecies") then
        pcall(function()
            NetBridge.equip(2, {slot = nil})
        end)
        task.wait(0.4)
    end

    local targetCF = stand:GetPivot()
    if targetCF then
        hrp.CFrame = targetCF * CFrame.new(0, 3, 0)
        task.wait(0.3)
        NetBridge.machineMount()
    end
end

-- Умная прокачка загона с телепортом к табличке
local function tryUpgradePen()
    local pen, plotNum = getMyPen()
    local stats = NetBridge.stats()
    if not pen or not stats then return false end

    local lvl = pen:GetAttribute("Level") or 1
    local price = pen:GetAttribute("Price") or 0
    if price > 0 and stats.dollars >= price then
        local stand = getMyStand()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local sign = pen:FindFirstChild("Sign")
        if not hrp or not sign then return false end

        NetBridge.machineDismount("jump")
        task.wait(0.3)

        hrp.CFrame = sign.CFrame * CFrame.new(0, 0, 5)
        task.wait(0.4)

        NetBridge.penUpgrade(plotNum, lvl, false)
        task.wait(0.4)

        if stand then
            hrp.CFrame = stand:GetPivot() * CFrame.new(0, 3, 0)
            task.wait(0.3)
            NetBridge.machineMount()
        end

        safeNotify({
            Title = "Загон прокачан!",
            Content = "Уровень " .. tostring(lvl + 1) .. "! Вместимость и $/сек выросли.",
            Duration = 3,
            Icon = "trending-up"
        })
        return true
    end
    return false
end

-- Покупка и экипировка ауры
local function tryUpgradeAura()
    local stats = NetBridge.stats()
    local auraState = NetBridge.state.aura
    if not stats or not auraState then return end

    local currentDollars = stats.dollars or 0
    local owned = auraState.owned or {}
    local equipped = auraState.equipped or ""

    local auraOrder = {"lvl1", "lvl2", "lvl3", "lvl4", "lvl5", "lvl6", "lvl7", "lvl8", "lvl9", "lvl10", "lvl11", "lvl12"}

    local bestAffordable = nil
    for _, id in ipairs(auraOrder) do
        local info = Training.Auras[id]
        if info and not owned[id] and currentDollars >= info.price then
            bestAffordable = id
        end
    end

    local bestOwned = nil
    for _, id in ipairs(auraOrder) do
        if owned[id] then
            bestOwned = id
        end
    end

    if bestAffordable then
        local stand = getMyStand()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        NetBridge.machineDismount("jump")
        task.wait(0.4)

        hrp.CFrame = CFrame.new(24.98, 26.5, -267.50)
        task.wait(1.2)

        NetBridge.auraAction("open")
        task.wait(0.3)
        NetBridge.auraAction("buy", bestAffordable)
        task.wait(0.4)
        NetBridge.auraAction("equip", bestAffordable)
        task.wait(0.4)

        if stand then
            hrp.CFrame = stand:GetPivot() * CFrame.new(0, 3, 0)
            task.wait(0.4)
            NetBridge.machineMount()
        end
    elseif bestOwned and bestOwned ~= equipped then
        NetBridge.auraAction("equip", bestOwned)
    end
end

-- Сбор всех доступных наград Индекса
local function checkAndClaimIndex()
    pcall(function()
        if not Config.AutoClaimIndex then return end
        if IndexModule and IndexModule.state then
            local claimed = IndexModule.state.claimed and IndexModule.state.claimed.species or {}
            local known = IndexModule.state.known or {}
            for specId, _ in pairs(known) do
                if not claimed[specId] then
                    NetBridge.indexClaim("species", specId)
                    safeNotify({
                        Title = "Индекс пополнен! 💎",
                        Content = "Получена награда за вид: " .. tostring(specId),
                        Duration = 3,
                        Icon = "award"
                    })
                end
            end
        end
    end)
end

-- ==================== КАСТОМНЫЕ АНИМЕ ТЕМЫ И ФОНЫ ====================

-- ==================== ДИСКОРД ВЕБХУК (DISCORD WEBHOOK) ====================
local function safeFormatMoney(n)
    local ok, res = pcall(function()
        if Format and Format.money then return Format.money(n or 0) end
    end)
    if ok and res then return tostring(res) end
    return "$" .. tostring(n or 0)
end

local function safeFormatAbbrev(n)
    local ok, res = pcall(function()
        if Format and Format.abbreviate then return Format.abbreviate(n or 0) end
    end)
    if ok and res then return tostring(res) end
    return tostring(n or 0)
end

local function sendDiscordWebhook(embed, isTest, callback)
    local rawUrl = sanitizeWebhookUrl(Config.DiscordWebhook)
    if rawUrl == "" or not rawUrl:find("http") then
        if callback then callback(false, "Укажите корректный URL вебхука (начинается с http)") end
        return false, "No webhook URL"
    end

    local reqFn = getHttpRequest()
    if not reqFn then
        warn("[Ride A Dino Webhook] Ошибка: в экзекуторе не найдена функция request / http_request!")
        if callback then callback(false, "Экзекутор не поддерживает функцию request") end
        return false, "No HTTP request function found in executor"
    end

    task.spawn(function()
        -- 1. Санитизация полей эмбеда по стандартам Discord API
        if embed.fields and type(embed.fields) == "table" then
            local sanitized = {}
            for _, f in ipairs(embed.fields) do
                if type(f) == "table" then
                    local fn = tostring(f.name or "Инфо"):sub(1, 256)
                    local fv = tostring(f.value or "-"):sub(1, 1024)
                    if fn == "" then fn = "-" end
                    if fv == "" then fv = "-" end
                    table.insert(sanitized, {
                        name = fn,
                        value = fv,
                        inline = (f.inline == true)
                    })
                end
            end
            embed.fields = sanitized
        end

        local payload = {
            username = "Ride A Dino! Bot 🦕",
            avatar_url = "https://raw.githubusercontent.com/ryomotik/ride-a-dino-autofarm/main/assets/anime1.png",
            embeds = { embed }
        }

        local jsonSuccess, json = pcall(function()
            return HttpService:JSONEncode(payload)
        end)

        if not jsonSuccess or not json then
            warn("[Ride A Dino Webhook] Ошибка JSONEncode: " .. tostring(json))
            if callback then callback(false, "Ошибка создания JSON: " .. tostring(json)) end
            return
        end

        local reqHeaders = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }

        local function executeRequest(targetUrl)
            local reqOptions = {
                Url = targetUrl,
                url = targetUrl,
                Method = "POST",
                method = "POST",
                Headers = reqHeaders,
                headers = reqHeaders,
                Body = json,
                body = json
            }

            local ok, res = pcall(function()
                return reqFn(reqOptions)
            end)

            return ok, res
        end

        -- 2. Цепочка URL: автоматический обход блокировки discord.com через прокси lewisakura
        local urlsToTry = {}
        local isDiscordDomain = rawUrl:find("discord%.com") or rawUrl:find("discordapp%.com")

        if isDiscordDomain then
            local proxyUrl = rawUrl:gsub("discord%.com", "webhook.lewisakura.moe"):gsub("discordapp%.com", "webhook.lewisakura.moe")
            if Config.WebhookUseProxy then
                -- Если пользователь выбрал прокси (по умолчанию для РФ) - сначала пробуем через прокси
                table.insert(urlsToTry, proxyUrl)
                table.insert(urlsToTry, rawUrl)
            else
                -- Иначе сначала напрямую, а при ошибке - через прокси
                table.insert(urlsToTry, rawUrl)
                table.insert(urlsToTry, proxyUrl)
            end
        else
            table.insert(urlsToTry, rawUrl)
        end

        local finalSuccess = false
        local lastStatus = 0
        local lastMsg = ""

        for idx, tryUrl in ipairs(urlsToTry) do
            local ok, res = executeRequest(tryUrl)
            if ok and type(res) == "table" then
                local statusCode = tonumber(res.StatusCode or res.status_code or res.statusCode) or 0
                local body = tostring(res.Body or res.body or "")
                lastStatus = statusCode
                lastMsg = body

                -- Discord возвращает 204 No Content или 200 OK при успешной доставке
                if statusCode == 204 or statusCode == 200 then
                    finalSuccess = true
                    print(string.format("[Ride A Dino Webhook] ✅ Успешно отправлено через %s (HTTP %d)", (tryUrl:find("lewisakura") and "Proxy" or "Direct"), statusCode))
                    break
                else
                    warn(string.format("[Ride A Dino Webhook] Попытка %d (%s) вернула HTTP %d: %s", idx, tryUrl, statusCode, body:sub(1, 150)))
                end
            else
                lastMsg = tostring(res)
                warn(string.format("[Ride A Dino Webhook] Попытка %d (%s) ошибка pcall: %s", idx, tryUrl, tostring(res)))
            end
            task.wait(0.25)
        end

        if callback then
            if finalSuccess then
                callback(true, "Отправлено успешно! (HTTP " .. tostring(lastStatus) .. ")")
            else
                local errDesc = "HTTP " .. tostring(lastStatus)
                if lastStatus == 404 then
                    errDesc = "Ошибка 404: Вебхук не найден! Проверьте ссылку в Discord."
                elseif lastStatus == 401 then
                    errDesc = "Ошибка 401: Неверный токен вебхука Discord."
                elseif lastStatus == 403 then
                    errDesc = "Ошибка 403: Доступ заблокирован Discord/Cloudflare."
                elseif lastStatus == 400 then
                    errDesc = "Ошибка 400: Неверный запрос (Bad Request)."
                elseif lastStatus == 429 then
                    errDesc = "Ошибка 429: Лимит запросов Discord. Подождите 1 минуту."
                elseif lastStatus == 0 then
                    errDesc = "Ошибка соединения: " .. tostring(lastMsg):sub(1, 70)
                end
                callback(false, errDesc)
            end
        end
    end)
    return true
end


local function sendStatsWebhookReport(isTest, callback)
    local ok, err = pcall(function()
        local stats = NetBridge.stats()
        local loadout = NetBridge.loadout()
        local pen = NetBridge.pen()
        local aura = NetBridge.state.aura
        local penInstance = getMyPen()

        local gripText = safeFormatAbbrev(stats and stats.grip or 0)
        local moneyText = safeFormatMoney(stats and stats.dollars or 0)
        local incomeText = pen and (safeFormatMoney(pen.income or 0) .. "/сек") or "$0/сек"

        local auraStr = "Нет"
        if aura and aura.equipped then
            local auraData = Training.Auras[aura.equipped]
            local mult = auraData and auraData.gripMult or 1
            auraStr = tostring(aura.equipped):upper() .. " (x" .. tostring(mult) .. ")"
        end

        local machineStr = "Tier 1"
        if loadout then
            local tier = loadout.tier or 1
            local tierData = Gear.Tiers[tier]
            machineStr = tierData and tierData.name or ("Tier " .. tostring(tier))
        end

        local penStr = "Ур. 1"
        if penInstance then
            local lvl = penInstance:GetAttribute("Level") or 1
            local cap = (pen and pen.capacity) or "?"
            penStr = "Ур. " .. tostring(lvl) .. " (макс " .. tostring(cap) .. " дино)"
        end

        local knownCount = 0
        if IndexModule and IndexModule.state and IndexModule.state.known then
            for _ in pairs(IndexModule.state.known) do knownCount = knownCount + 1 end
        end

        local title = isTest and "🧪 Тестовый отчет вебхука" or "📊 Периодический отчет фарма"
        local embed = {
            title = title,
            description = isTest and "Связь с Discord вебхуком успешно установлена! ✅" or "Текущий прогресс и статистика автофарма в игре Ride A Dino!",
            color = isTest and 0x5865F2 or 0x00F0FF,
            fields = {
                { name = "🎮 Игрок", value = LocalPlayer.Name, inline = true },
                { name = "💪 Хватка (Grip)", value = gripText, inline = true },
                { name = "💰 Баланс", value = moneyText, inline = true },
                { name = "📈 Доход загона", value = incomeText, inline = true },
                { name = "⚡ Аура", value = auraStr, inline = true },
                { name = "🏋️ Машина", value = machineStr, inline = true },
                { name = "🏡 Загон", value = penStr, inline = true },
                { name = "📖 Индекс", value = string.format("`%d / 58`", knownCount), inline = true },
            },
            footer = {
                text = "Ride A Dino! • Anime Minimalist Edition"
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
        sendDiscordWebhook(embed, isTest, callback)
    end)

    if not ok and callback then
        callback(false, "Ошибка формирования отчета: " .. tostring(err))
    end
end

-- ==================== ЭКИПИРОВКА ЛУЧШЕГО (EQUIP BEST) ====================
local function equipBest()
    task.spawn(function()
        pcall(function()
            safeNotify({
                Title = "Экипировка ⚡",
                Content = "Установка лучшего снаряжения...",
                Duration = 2,
                Icon = "zap"
            })

            local stats = NetBridge.stats()
            local dollars = stats and stats.dollars or 0
            local auraOrder = {"lvl1", "lvl2", "lvl3", "lvl4", "lvl5", "lvl6", "lvl7", "lvl8", "lvl9", "lvl10", "lvl11", "lvl12"}
            local auraState = NetBridge.state.aura
            local owned = auraState and auraState.owned or {}

            -- 1. Покупаем и экипируем лучшую доступную ауру
            local bestAffordable = nil
            for _, id in ipairs(auraOrder) do
                local info = Training.Auras[id]
                if info and not owned[id] and dollars >= info.price then
                    bestAffordable = id
                end
            end

            if bestAffordable then
                local stand = getMyStand()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    NetBridge.machineDismount("jump")
                    task.wait(0.3)
                    hrp.CFrame = CFrame.new(24.98, 26.5, -267.50)
                    task.wait(1.0)
                    NetBridge.auraAction("open")
                    task.wait(0.3)
                    NetBridge.auraAction("buy", bestAffordable)
                    task.wait(0.3)
                    NetBridge.auraAction("equip", bestAffordable)
                    task.wait(0.3)
                    if stand then
                        hrp.CFrame = stand:GetPivot() * CFrame.new(0, 3, 0)
                        task.wait(0.3)
                    end
                end
            else
                local highestOwned = nil
                for _, id in ipairs(auraOrder) do
                    if owned[id] then highestOwned = id end
                end
                if highestOwned and auraState.equipped ~= highestOwned then
                    NetBridge.auraAction("equip", highestOwned)
                end
            end

            -- 2. Покупаем следующий тир тренажера
            local loadout = NetBridge.loadout()
            local currentTier = loadout and loadout.tier or 1
            local nextTierData = Gear.Tiers[currentTier + 1]
            if nextTierData and dollars >= nextTierData.price then
                NetBridge.buy(currentTier + 1)
            end

            -- 3. Прокачиваем загон при наличии средств
            tryUpgradePen()

            -- 4. Возврат и посадка на свой тренажер
            task.wait(0.3)
            teleportToStandAndMount()

            safeNotify({
                Title = "Готово! ⚡",
                Content = "Лучшая аура, машина и загон экипированы!",
                Duration = 3,
                Icon = "zap"
            })
        end)
    end)
end

local GITHUB_RAW_BASE = "https://raw.githubusercontent.com/ryomotik/ride-a-dino-autofarm/main/assets/"

local function getCustomAssetSafe(fileName, url)
    local assetId = nil
    pcall(function()
        if isfile and not isfile(fileName) and url and game.HttpGet then
            local data = game:HttpGet(url)
            if data and #data > 0 and writefile then
                writefile(fileName, data)
            end
        end
        if getcustomasset then
            assetId = getcustomasset(fileName)
        end
    end)
    return assetId
end

-- Переменная окна для доступа внутри темы
local Window = nil

local function getWindowFrame()
    local cg = game:GetService("CoreGui")
    local rg = cg:FindFirstChild("RobloxGui") or cg
    local w = rg:FindFirstChild("WindUI") or cg:FindFirstChild("WindUI")
    if w then
        local winFolder = w:FindFirstChild("Window")
        if winFolder and winFolder:FindFirstChild("Frame") then
            return winFolder.Frame
        end
    end
    return nil
end

local function applyCustomTheme(themeKey, transparency)
    transparency = transparency or Config.BgTransparency or 0.35
    pcall(function()
        local frame = getWindowFrame()
        local bgImg = frame and frame:FindFirstChild("CustomAnimeBg")
        if not bgImg and frame then
            bgImg = Instance.new("ImageLabel")
            bgImg.Name = "CustomAnimeBg"
            bgImg.Size = UDim2.fromScale(1, 1)
            bgImg.Position = UDim2.fromScale(0, 0)
            bgImg.BackgroundTransparency = 1
            bgImg.ScaleType = Enum.ScaleType.Crop
            bgImg.ZIndex = 2

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 16)
            corner.Parent = bgImg

            bgImg.Parent = frame
        end

        if themeKey == "🌸 Sakura Pink (Тянка 1)" then
            local asset1 = getCustomAssetSafe("RideADino_anime1.png", GITHUB_RAW_BASE .. "anime1.png")
            WindUI:SetTheme("Rose")
            if bgImg then
                bgImg.Image = asset1 or ""
                bgImg.ImageTransparency = transparency
                bgImg.Visible = true
            end
        elseif themeKey == "🩸 Crimson Blood (Тянка 2)" then
            local asset2 = getCustomAssetSafe("RideADino_anime2.jpg", GITHUB_RAW_BASE .. "anime2.jpg")
            WindUI:SetTheme("Crimson")
            if bgImg then
                bgImg.Image = asset2 or ""
                bgImg.ImageTransparency = transparency
                bgImg.Visible = true
            end
        elseif themeKey == "🖤 Dark Minimal" then
            WindUI:SetTheme("Dark")
            if bgImg then
                bgImg.Visible = false
            end
        else
            WindUI:SetTheme(themeKey)
            if bgImg then
                bgImg.Visible = false
            end
        end
    end)
end

-- ==================== СОЗДАНИЕ ИНТЕРФЕЙСА WINDUI (МИНИМАЛИЗМ) ====================
Window = WindUI:CreateWindow({
    Title = "Ride A Dino! ⚡ [Energy Edition]",
    Icon = "zap",
    Author = "by Antigravity & ryomotik",
    Folder = "RideADinoAutofarm",
    Size = UDim2.fromOffset(560, 440),
    Theme = "Rose",
    Transparent = true,
    Resizable = true,
    ToggleKey = Config.ToggleKeyCode,
})

-- Устанавливаем клавишу скрытия/открытия меню
pcall(function()
    if Window and Window.SetToggleKey then
        Window:SetToggleKey(Config.ToggleKeyCode)
    end
end)

-- Применяем начальную тему и фоновое изображение
task.spawn(function()
    task.wait(0.2)
    applyCustomTheme(Config.Theme, Config.BgTransparency)
end)

-- 3 Лаконичные вкладки (Энергия & База)
local TabFarm = Window:Tab({ Title = "⚡ Фарм Энергии", Icon = "zap" })
local TabVisuals = Window:Tab({ Title = "🎨 Стиль & Визуал", Icon = "palette" })
local TabStats = Window:Tab({ Title = "📊 Инфо & Настройки", Icon = "bar-chart-2" })

-- ==================== ВКЛАДКА 1: ФАРМ ЭНЕРГИИ И БАЗЫ ====================
local secFast = TabFarm:Section({ Title = "Быстрые действия", Opened = true })

secFast:Button({
    Title = "⚡ Экипировать лучшее (Equip Best)",
    Desc = "Купить лучшую ауру, машину, прокачать загон и сесть на тренажер",
    Callback = function()
        equipBest()
    end
})

local secToggles = TabFarm:Section({ Title = "Автоматизация тренировки и базы", Opened = true })

secToggles:Toggle({
    Title = "⚡ Авто-тренировка энергии (Auto Grip Train)",
    Desc = "Непрерывная тренировка на тренажере и удержание хвата",
    Value = Config.AutoTrain,
    Callback = function(val)
        Config.AutoTrain = val
        if val and not isPlayerOnMachine() then
            teleportToStandAndMount()
        end
        safeNotify({
            Title = "Тренировка энергии ⚡",
            Content = val and "Авто-тренировка энергии включена! 🚀" or "Авто-тренировка выключена",
            Duration = 2,
            Icon = "zap"
        })
    end
})

secToggles:Toggle({
    Title = "🦾 Авто-покупка тренажеров (Auto Machines)",
    Desc = "Автоматическая покупка машины следующего тира при наличии денег",
    Value = Config.AutoMachine,
    Callback = function(val)
        Config.AutoMachine = val
        safeNotify({
            Title = "Тренажеры 🦾",
            Content = val and "Авто-покупка тренажеров включена!" or "Авто-покупка выключена",
            Duration = 2,
            Icon = "award"
        })
    end
})

secToggles:Toggle({
    Title = "🏡 Авто-прокачка загона (Auto Pen Upgrade)",
    Desc = "Умный апгрейд таблички загона для повышения дохода ($/сек)",
    Value = Config.AutoPen,
    Callback = function(val)
        Config.AutoPen = val
        safeNotify({
            Title = "Загон 🏡",
            Content = val and "Авто-прокачка загона включена!" or "Авто-прокачка выключена",
            Duration = 2,
            Icon = "home"
        })
    end
})

secToggles:Toggle({
    Title = "✨ Авто-покупка и экипировка аур (Auto Auras)",
    Desc = "Покупка и экипировка лучших доступных аур с умножителем энергии",
    Value = Config.AutoAura,
    Callback = function(val)
        Config.AutoAura = val
        safeNotify({
            Title = "Ауры ✨",
            Content = val and "Авто-экипировка аур включена!" or "Авто-экипировка выключена",
            Duration = 2,
            Icon = "sparkles"
        })
    end
})

secToggles:Toggle({
    Title = "🎁 Авто-сбор оффлайн наград и подарков",
    Desc = "Автоматический сбор таймеров подарков и оффлайн прибыли",
    Value = Config.AutoClaim,
    Callback = function(val)
        Config.AutoClaim = val
    end
})

secToggles:Toggle({
    Title = "🛡️ Защита Anti-AFK",
    Desc = "Предотвращает отключение от игры за неактивность",
    Value = Config.AntiAFK,
    Callback = function(val)
        Config.AntiAFK = val
    end
})

-- ==================== ВКЛАДКА 2: СТИЛЬ & ВИЗУАЛ ====================
local secTheme = TabVisuals:Section({ Title = "Темы оформления интерфейса", Opened = true })

secTheme:Dropdown({
    Title = "Тема оформления GUI",
    Desc = "Выберите визуальный стиль",
    Values = {
        "🌸 Sakura Pink (Тянка 1)",
        "🩸 Crimson Blood (Тянка 2)",
        "🖤 Dark Minimal"
    },
    Value = Config.Theme,
    Callback = function(themeName)
        Config.Theme = themeName
        applyCustomTheme(themeName, Config.BgTransparency)
        safeNotify({
            Title = "Стиль интерфейса",
            Content = "Установлена тема: " .. tostring(themeName),
            Duration = 2,
            Icon = "palette"
        })
    end
})

secTheme:Slider({
    Title = "Прозрачность фона (10% - 90%)",
    Desc = "Яркость аниме арта",
    Step = 5,
    Value = {
        Min = 10,
        Max = 90,
        Default = math.floor(Config.BgTransparency * 100),
    },
    Callback = function(val)
        Config.BgTransparency = val / 100
        local frame = getWindowFrame()
        local bgImg = frame and frame:FindFirstChild("CustomAnimeBg")
        if bgImg then
            bgImg.ImageTransparency = Config.BgTransparency
        end
    end
})

local secVisualFX = TabVisuals:Section({ Title = "Визуальные эффекты персонажа", Opened = true })

secVisualFX:Toggle({
    Title = "✨ Космическая Аура (Chill VFX)",
    Desc = "Искры, неоновый контур и след за персонажем",
    Value = Config.ChillVisuals,
    Callback = function(val)
        Config.ChillVisuals = val
        applyChillVisuals(val)
    end
})

-- ==================== ВКЛАДКА 3: ИНФО & НАСТРОЙКИ ====================
local secStats = TabStats:Section({ Title = "Сводка персонажа", Opened = true })
local pStatsOverview = secStats:Paragraph({
    Title = "Показатели игрока",
    Desc = "Загрузка данных..."
})

local secSettings = TabStats:Section({ Title = "Параметры & Бинд", Opened = true })

secSettings:Keybind({
    Title = "Бинд открытия меню",
    Desc = "Клавиша для скрытия и показа меню (по умолчанию RightControl)",
    Value = Config.ToggleKey,
    Callback = function(key)
        pcall(function()
            local code = typeof(key) == "EnumItem" and key or Enum.KeyCode[key]
            if code then
                Config.ToggleKeyCode = code
                Config.ToggleKey = typeof(key) == "string" and key or key.Name
                if Window and Window.SetToggleKey then
                    Window:SetToggleKey(code)
                end
                safeNotify({
                    Title = "Бинд меню ⌨️",
                    Content = "Клавиша открытия: " .. tostring(Config.ToggleKey),
                    Duration = 2,
                    Icon = "keyboard"
                })
            end
        end)
    end
})

secSettings:Button({
    Title = "Выгрузить автофарм (Unload)",
    Desc = "Полностью закрыть скрипт и очистить интерфейс",
    Callback = function()
        BotState.Running = false
        applyChillVisuals(false)
        if Window and Window.Destroy then
            Window:Destroy()
        end
    end
})

local secWebhook = TabStats:Section({ Title = "Дискорд Вебхук (Discord Webhook)", Opened = true })

local webhookInput
webhookInput = secWebhook:Input({
    Title = "URL Вебхука (Webhook URL)",
    Desc = "Вставьте ссылку на ваш Discord Webhook",
    Value = Config.DiscordWebhook,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(text)
        Config.DiscordWebhook = sanitizeWebhookUrl(text)
        if Config.DiscordWebhook ~= "" and Config.DiscordWebhook:find("http") then
            safeNotify({
                Title = "Discord Webhook 📡",
                Content = "Вебхук успешно сохранен!",
                Duration = 2,
                Icon = "check"
            })
        end
    end
})

secWebhook:Toggle({
    Title = "🛡️ Прокси-сервер (Обход блокировок РФ / Discord)",
    Desc = "Автоматический обход блокировки discord.com через прокси lewisakura",
    Value = Config.WebhookUseProxy,
    Callback = function(val)
        Config.WebhookUseProxy = val
        safeNotify({
            Title = "Discord Прокси 🛡️",
            Content = val and "Обход блокировок ВКЛЮЧЕН (через прокси)" or "Прямое подключение к Discord",
            Duration = 2,
            Icon = "shield"
        })
    end
})

secWebhook:Toggle({
    Title = "Периодический отчет (Report каждые 15м)",
    Desc = "Отправлять сводку баланса и хвата каждые 15 минут",
    Value = Config.WebhookPeriodic,
    Callback = function(val)
        Config.WebhookPeriodic = val
    end
})

secWebhook:Button({
    Title = "🧪 Проверить вебхук (Отправить тест)",
    Desc = "Отправить тестовое сообщение со статистикой в Discord",
    Callback = function()
        -- Подтягиваем значение из инпута если пользователь только вставил ссылку
        if webhookInput then
            local currentVal = webhookInput.Value or (webhookInput.GetValue and webhookInput:GetValue())
            if currentVal and type(currentVal) == "string" and currentVal ~= "" then
                Config.DiscordWebhook = sanitizeWebhookUrl(currentVal)
            end
        end

        local cleanUrl = sanitizeWebhookUrl(Config.DiscordWebhook)
        if cleanUrl == "" or not cleanUrl:find("http") then
            safeNotify({
                Title = "Ошибка вебхука ⚠️",
                Content = "Сначала укажите корректную ссылку на Discord Webhook!",
                Duration = 3,
                Icon = "alert-triangle"
            })
            return
        end

        safeNotify({
            Title = "Отправка теста... 📡",
            Content = "Устанавливаем связь с Discord...",
            Duration = 2,
            Icon = "send"
        })

        sendStatsWebhookReport(true, function(ok, msg)
            if ok then
                safeNotify({
                    Title = "Успех! ✅",
                    Content = "Тестовый отчет успешно доставлен в Discord!",
                    Duration = 4,
                    Icon = "check"
                })
            else
                safeNotify({
                    Title = "Ошибка вебхука ❌",
                    Content = msg or "Не удалось отправить отчет в Discord",
                    Duration = 5,
                    Icon = "alert-triangle"
                })
            end
        end)
    end
})

-- Обновление сводки статистики в UI
local function updateStatsUI()
    pcall(function()
        if not pStatsOverview then return end

        local stats = NetBridge.stats()
        local loadout = NetBridge.loadout()
        local pen = NetBridge.pen()
        local aura = NetBridge.state.aura
        local penInstance = getMyPen()

        local gripStr = stats and Format.abbreviate(stats.grip or 0) or "0"
        local moneyStr = stats and Format.money(stats.dollars or 0) or "$0"
        local incomeStr = pen and (Format.money(pen.income or 0) .. "/сек") or "$0/сек"

        local auraStr = "Нет"
        if aura and aura.equipped then
            local auraData = Training.Auras[aura.equipped]
            local mult = auraData and auraData.gripMult or 1
            auraStr = tostring(aura.equipped):upper() .. " (x" .. tostring(mult) .. ")"
        end

        local machineStr = "Tier 1"
        if loadout then
            local tier = loadout.tier or 1
            local tierData = Gear.Tiers[tier]
            local nextTier = tier + 1
            local nextTierData = Gear.Tiers[nextTier]
            local nextText = nextTierData and (" (След: " .. Format.money(nextTierData.price) .. ")") or " (МАКС)"
            machineStr = (tierData and tierData.name or ("Tier " .. tostring(tier))) .. nextText
        end

        local penStr = "Ур. 1"
        if penInstance then
            local lvl = penInstance:GetAttribute("Level") or 1
            local price = penInstance:GetAttribute("Price") or 0
            local cap = (pen and pen.capacity) or "?"
            local nextText = price > 0 and (" (Апгрейд: " .. Format.money(price) .. ")") or " (МАКС)"
            penStr = "Ур. " .. tostring(lvl) .. " [" .. tostring(cap) .. " дино]" .. nextText
        end

        local indexStr = "0 / 58"
        if IndexModule and IndexModule.state and IndexModule.state.known then
            local knownCount = 0
            for _ in pairs(IndexModule.state.known) do
                knownCount = knownCount + 1
            end
            indexStr = tostring(knownCount) .. " / 58"
        end

        local text = string.format(
            "💪 Хватка (Grip): %s\n💰 Баланс: %s\n📈 Доход загона: %s\n⚡ Аура: %s\n🏋️ Машина: %s\n🏡 Загон: %s\n📖 Открыто в Индексе: %s",
            gripStr, moneyStr, incomeStr, auraStr, machineStr, penStr, indexStr
        )
        safeSetDesc(pStatsOverview, text)
    end)
end


-- Защита Anti-AFK
local afkConn = LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK then
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end
end)

-- Авто-восстановление визуала при респавне персонажа
local charAddedConn = LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    if Config.ChillVisuals then
        applyChillVisuals(true)
    end
end)

-- Очистка при повторной загрузке
if typeof(STATE) == "table" and STATE.onCleanup then
    STATE.onCleanup(function()
        BotState.Running = false
        applyChillVisuals(false)
        if afkConn then afkConn:Disconnect() end
        if charAddedConn then charAddedConn:Disconnect() end
        if Window and Window.Destroy then Window:Destroy() end
    end)
end

-- Включаем чил-ауру при старте (если включено в конфиге)
if Config.ChillVisuals then
    applyChillVisuals(true)
else
    applyChillVisuals(false)
end

-- ==================== ОСНОВНОЙ ЦИКЛ БОТА ====================
task.spawn(function()
    print("[Ride A Dino Autofarm | Anime Edition] Бот успешно запущен!")
    safeNotify({
        Title = "Ride A Dino! 🌸",
        Content = "Автофарм запущен! Стиль: " .. tostring(Config.Theme),
        Duration = 4,
        Icon = "sparkles"
    })

    -- Начальная посадка на тренажер
    if Config.AutoTrain and not isPlayerOnMachine() then
        teleportToStandAndMount()
    end

    while isAlive() do
        local now = os.clock()

        -- Если идет заезд в каньоне, ждем его окончания
        if not BotState.IsRiding then
            -- Проверка тренировки и прокачек
            if now - BotState.LastCheck >= Config.CheckInterval then
                BotState.LastCheck = now

                -- Авто-тренировка хвата
                if Config.AutoTrain and not isPlayerOnMachine() then
                    local char = LocalPlayer.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        teleportToStandAndMount()
                    end
                end

                -- Авто-прокачка загона
                if Config.AutoPen then
                    tryUpgradePen()
                end

                -- Авто-покупка машин
                if Config.AutoMachine then
                    local loadout = NetBridge.loadout()
                    local stats = NetBridge.stats()
                    local currentTier = loadout and loadout.tier or 1
                    local nextTier = currentTier + 1
                    local tierConfig = Gear.Tiers[nextTier]
                    if tierConfig and stats and stats.dollars >= tierConfig.price then
                        NetBridge.buy(nextTier)
                        safeNotify({
                            Title = "Новый тренажер!",
                            Content = "Приобретен: " .. tierConfig.name,
                            Duration = 4,
                            Icon = "award"
                        })
                    end
                end
            end

            -- Авто-покупка и экипировка аур
            if Config.AutoAura and (now - BotState.LastAuraCheck >= 15) then
                BotState.LastAuraCheck = now
                pcall(tryUpgradeAura)
            end

            -- Сбор оффлайн наград и подарков
            if Config.AutoClaim and (now - BotState.LastClaim >= 30) then
                BotState.LastClaim = now
                pcall(function()
                    NetBridge.offlineClaim()
                    NetBridge.giftClaim(true)
                end)
            end

            -- Сбор наград Индекса
            if Config.AutoClaimIndex then
                checkAndClaimIndex()
            end


            -- Периодический отчет в Discord (каждые 15 минут)
            if Config.WebhookPeriodic and Config.DiscordWebhook ~= "" and (now - BotState.LastWebhookReport >= Config.WebhookInterval) then
                BotState.LastWebhookReport = now
                sendStatsWebhookReport(false)
            end
        end

        -- Обновление статистики в UI
        updateStatsUI()

        task.wait(1)
    end
end)
