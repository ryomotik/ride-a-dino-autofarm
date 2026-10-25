--[[
    🦕 Ride A Dino! [☄️] — Ultimate Autofarm & Dragon Rider Bot (Chill Edition)
    Разработано под игру "Ride A Dino!" (PlaceId: 93523763376122)
    
    Визуальный стиль: WindUI Violet Neon (стильный молодёжный вайб, неоновые ауры и партиклы)
    
    Возможности:
    - 🏋️ Авто-тренировка хвата (Grip): непрерывный фарм на тренажере и удержание
    - 🏡 Авто-прокачка загона (Pen Upgrade): умный апгрейд с телепортом к табличке ($/сек)
    - 🦾 Авто-покупка новых тренажеров (Machine Tiers)
    - ✨ Авто-покупка и экипировка лучших аур (Aura Multipliers)
    - 🎁 Авто-сбор оффлайн наград и подарков (Offline Rewards & Gifts)
    - 🦕 Автоскачки в каньоне (Canyon Auto-Ride): заезды по каньону на драконах и динозаврах
    - 🎯 Охота на новых динозавров (Hunt Unindexed Dinos): приоритет приручения тех, кого нет в Индексе
    - 💎 Авто-сбор наград Индекса (Auto Claim Index Rewards): получение бонусов за открытые виды
    - 🌌 Мощный Чил-Визуал: космическая неон-аура, партиклы, световой шлейф шагов (Trail)
    - 🦖 Glow ESP: неоновая золотая подсветка редких и неизвестных динозавров в каньоне
    - 🛡️ Защита Anti-AFK от кика за неактивность
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (Fluxus and Fluxus.request) or request

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
local Dinos = require(RideADino.Config.Dinos)
local Track = require(RideADino.Config.Track)
local TameConfig = require(RideADino.Config.Tame)

local ClientModules = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("RideADinoClient"):WaitForChild("Modules")
local NetBridge = require(ClientModules:WaitForChild("NetBridge"))
local GearMachine = require(ClientModules:WaitForChild("GearMachine"))
local AuraShopModule = require(ClientModules:WaitForChild("AuraShop"))
local RideModule = require(ClientModules:WaitForChild("Ride"))
local TameModule = require(ClientModules:WaitForChild("Ride"):WaitForChild("Tame"))
local LeapModule = require(ClientModules:WaitForChild("Ride"):WaitForChild("Leap"))
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

-- Конфигурация бота
local Config = {
    AutoTrain = true,
    AutoPen = true,
    AutoMachine = true,
    AutoAura = true,
    AutoClaim = true,
    AntiAFK = true,
    AutoRide = true,          -- Автоскачки в каньоне
    AutoLeap = true,          -- Прыжки на диких мобов
    HuntUnindexed = true,     -- Охота на мобов, которых нет в Индексе
    PrioritizeRare = true,    -- Приоритет редких видов, гигантов и мутаций
    AutoClaimIndex = true,    -- Сбор наград Индекса
    DinoESP = true,           -- Подсветка новых/редких динозавров
    ChillVisuals = false,     -- Космическая неон-аура и шлейф (отключено по умолчанию)
    Theme = "🌸 Sakura Pink (Тянка 1)",
    BgTransparency = 0.35,
    RideInterval = 60,        -- Интервал между скачками (сек)
    CheckInterval = 2,
    ToggleKey = "RightControl",       -- Клавиша открытия/скрытия меню
    ToggleKeyCode = Enum.KeyCode.RightControl,
    DiscordWebhook = "",              -- URL вебхука Discord
    WebhookOnTame = true,             -- Уведомления о приручении динозавров
    WebhookPeriodic = false,          -- Периодический отчет (каждые 15 минут)
    WebhookInterval = 900,            -- 15 минут в секундах
}

local BotState = {
    Running = true,
    IsRiding = false,
    LastCheck = 0,
    LastClaim = 0,
    LastAuraCheck = 0,
    LastRide = 0,
    LastWebhookReport = 0,
    RideStatus = "В ожидании",
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
local function sendDiscordWebhook(embed)
    if not Config.DiscordWebhook or Config.DiscordWebhook == "" or not Config.DiscordWebhook:find("http") then
        return
    end

    task.spawn(function()
        pcall(function()
            if not httpRequest then return end

            local payload = {
                username = "Ride A Dino! Bot 🦕",
                avatar_url = "https://raw.githubusercontent.com/ryomotik/ride-a-dino-autofarm/main/assets/anime1.png",
                embeds = { embed }
            }

            local json = HttpService:JSONEncode(payload)
            httpRequest({
                Url = Config.DiscordWebhook,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = json
            })
        end)
    end)
end

local function notifyWebhookTamed(specId, isNew, size, mutation)
    if not Config.WebhookOnTame then return end
    pcall(function()
        size = size or "Normal"
        mutation = mutation or "None"
        local stats = NetBridge.stats()
        local pen = NetBridge.pen()
        local knownCount = 0
        if IndexModule and IndexModule.state and IndexModule.state.known then
            for _ in pairs(IndexModule.state.known) do knownCount = knownCount + 1 end
        end

        local gripText = stats and Format.abbreviate(stats.grip or 0) or "0"
        local moneyText = stats and Format.money(stats.dollars or 0) or "$0"
        local incomeText = pen and (Format.money(pen.income or 0) .. "/сек") or "$0/сек"

        local tag = ""
        if mutation ~= "None" and mutation ~= "" then
            tag = " [" .. mutation .. "]"
        end
        if size ~= "Normal" and size ~= "" then
            tag = tag .. " (" .. size .. ")"
        end

        local title = ""
        local color = 0xFF69B4
        if isNew then
            title = "🎉 ОТКРЫТ НОВЫЙ ВИД: " .. tostring(specId) .. tag .. "!"
            color = 0xFFD700
        elseif mutation == "Rainbow" or mutation == "Golden" then
            title = "🌟 ЛЕГЕНДАРНАЯ МУТАЦИЯ: " .. tostring(specId) .. tag .. "!"
            color = 0xFFD700
        elseif size == "Colossal" or size == "Huge" or size == "Giant" then
            title = "👑 ГИГАНТСКИЙ ДИНОЗАВР: " .. tostring(specId) .. tag .. "!"
            color = 0xBA55D3
        elseif mutation == "Silver" then
            title = "✨ СЕРЕБРЯНЫЙ ДИНОЗАВР: " .. tostring(specId) .. tag .. "!"
            color = 0xC0C0C0
        else
            title = "💖 Приручен: " .. tostring(specId) .. tag
        end

        local desc = isNew and "🦖 Новый динозавр добавлен в ваш Индекс!" or "🦕 Динозавр успешно оседлан и приручен на 100%!"

        local fields = {
            { name = "🦕 Вид", value = "`" .. tostring(specId) .. "`", inline = true },
            { name = "📏 Размер", value = "`" .. tostring(size) .. "`", inline = true },
            { name = "🧬 Мутация", value = "`" .. tostring(mutation) .. "`", inline = true },
            { name = "📖 Индекс", value = string.format("`%d / 58`", knownCount), inline = true },
            { name = "💰 Баланс", value = moneyText, inline = true },
            { name = "💪 Хватка (Grip)", value = gripText, inline = true },
            { name = "📈 Доход загона", value = incomeText, inline = true },
            { name = "🎮 Игрок", value = LocalPlayer.Name, inline = true },
        }

        local embed = {
            title = title,
            description = desc,
            color = color,
            fields = fields,
            footer = {
                text = "Ride A Dino! • Anime Minimalist Edition"
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
        sendDiscordWebhook(embed)
    end)
end

local function sendStatsWebhookReport(isTest)
    pcall(function()
        local stats = NetBridge.stats()
        local loadout = NetBridge.loadout()
        local pen = NetBridge.pen()
        local aura = NetBridge.state.aura
        local penInstance = getMyPen()

        local gripText = stats and Format.abbreviate(stats.grip or 0) or "0"
        local moneyText = stats and Format.money(stats.dollars or 0) or "$0"
        local incomeText = pen and (Format.money(pen.income or 0) .. "/сек") or "$0/сек"

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
        sendDiscordWebhook(embed)
    end)
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

            -- 4. Экипируем верхового маунта (слот 2 в хотбаре)
            pcall(function()
                NetBridge.equip(2, {slot = 2})
            end)

            -- 5. Телепорт на свой тренажер
            task.wait(0.3)
            teleportToStandAndMount()

            safeNotify({
                Title = "Готово! ✨",
                Content = "Лучшая аура, тренажер и маунт экипированы!",
                Duration = 3,
                Icon = "check-circle"
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
    Title = "Ride A Dino! 🦕 [Minimalist Edition]",
    Icon = "flame",
    Author = "by Antigravity & ryomotik",
    Folder = "RideADinoAutofarm",
    Size = UDim2.fromOffset(580, 450),
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

-- 3 Минималистичные вкладки (Минимализм - наше золото)
local TabFarm = Window:Tab({ Title = "⚡ Главная (Фарм)", Icon = "zap" })
local TabVisuals = Window:Tab({ Title = "🎨 Стиль & Визуал", Icon = "palette" })
local TabStats = Window:Tab({ Title = "📊 Инфо & Настройки", Icon = "bar-chart-2" })

-- ==================== ВКЛАДКА 1: ФАРМ И СКАЧКИ ====================
local secFast = TabFarm:Section({ Title = "Быстрые действия", Opened = true })

secFast:Button({
    Title = "⚡ Экипировать лучшее (Equip Best)",
    Desc = "Купить и одеть лучшую ауру, машину, улучшить загон и маунта",
    Callback = function()
        equipBest()
    end
})

local startCanyonRide -- пред-объявление

secFast:Button({
    Title = "🏇 Скачки прямо сейчас (Ride Now)",
    Desc = "Немедленно оседлать маунта и запрыгнуть в каньон для приручения",
    Callback = function()
        if startCanyonRide then
            task.spawn(startCanyonRide)
        end
    end
})

local secToggles = TabFarm:Section({ Title = "Автоматизация", Opened = true })

secToggles:Toggle({
    Title = "🔥 Полный автофарм базы (Base Auto)",
    Desc = "Хватка, тренажеры, загон, ауры, награды и Anti-AFK",
    Value = Config.AutoTrain,
    Callback = function(val)
        Config.AutoTrain = val
        Config.AutoPen = val
        Config.AutoMachine = val
        Config.AutoAura = val
        Config.AutoClaim = val
        if val and not isPlayerOnMachine() then
            teleportToStandAndMount()
        end
        safeNotify({
            Title = "Автофарм базы",
            Content = val and "Полный автофарм базы включен! 🚀" or "Автофарм выключен",
            Duration = 2,
            Icon = "zap"
        })
    end
})

secToggles:Toggle({
    Title = "🦕 Авто-скачки и Приручение (Canyon Ride)",
    Desc = "Периодические забеги по каньону и быстрое приручение",
    Value = Config.AutoRide,
    Callback = function(val)
        Config.AutoRide = val
        Config.AutoLeap = val
        safeNotify({
            Title = "Скачки в каньоне",
            Content = val and "Авто-скачки и приручение включены!" or "Авто-скачки выключены",
            Duration = 2,
            Icon = "zap"
        })
    end
})

secToggles:Toggle({
    Title = "🎯 Охота на новых видов (Index Hunt)",
    Desc = "Приоритет динозавров, которых еще нет в вашем Индексе",
    Value = Config.HuntUnindexed,
    Callback = function(val)
        Config.HuntUnindexed = val
    end
})

secToggles:Toggle({
    Title = "👑 Приоритет редких видов (Rare Prioritize)",
    Desc = "Охота на редких драконов, мутации (Rainbow, Golden, Silver) и гигантов (Colossal, Giant)",
    Value = Config.PrioritizeRare,
    Callback = function(val)
        Config.PrioritizeRare = val
    end
})

local secRideInfo = TabFarm:Section({ Title = "Текущий Заезд в Каньоне", Opened = true })
local pRideStatus = secRideInfo:Paragraph({ Title = "Статус скачек", Desc = "В ожидании (готов к заезду)" })
local pTameProgress = secRideInfo:Paragraph({ Title = "Шкала приручения (Розовая шкала)", Desc = "Ожидание заезда (0%)" })

-- Оценка ценности и редкости динозавра
local function getDinoRarity(dino, playerGrip)
    if not (dino and dino:IsA("Model")) then
        return 0, false, "Normal", "None", 20, Color3.fromRGB(255, 255, 255), false, "Unknown"
    end

    local specId = dino:GetAttribute("SpecId") or dino.Name
    local size = dino:GetAttribute("Size") or "Normal"
    local mutation = dino:GetAttribute("Mutation") or "None"

    local reqGrip = 20
    pcall(function()
        if TameConfig and TameConfig.gate then
            reqGrip = TameConfig.gate(specId) or TameConfig.gate(dino.Name) or 20
        elseif TameConfig and TameConfig.GATE then
            reqGrip = TameConfig.GATE[specId] or TameConfig.GATE[dino.Name] or 20
        end
    end)

    -- Базовый балл вида на основе требований к энергии (Grip)
    local speciesScore = math.floor(math.log10(math.max(10, reqGrip)) * 100)

    -- Множитель размера
    local sizeMult = 1.0
    if size == "Colossal" then
        sizeMult = 5.0
    elseif size == "Huge" then
        sizeMult = 3.5
    elseif size == "Giant" then
        sizeMult = 2.5
    elseif size == "Big" then
        sizeMult = 1.4
    elseif size == "Tiny" then
        sizeMult = 0.7
    end

    -- Множитель мутации
    local mutMult = 1.0
    if mutation == "Rainbow" then
        mutMult = 8.0
    elseif mutation == "Golden" then
        mutMult = 5.0
    elseif mutation == "Spectral" or mutation == "Magma" or mutation == "Mummified" or mutation == "Void" or mutation == "Electric" then
        mutMult = 4.0
    elseif mutation == "Silver" then
        mutMult = 2.5
    elseif mutation ~= "None" and mutation ~= "" then
        mutMult = 2.0
    end

    local isUnknown = not NetBridge.knows(specId)
    local indexBonus = (Config.HuntUnindexed and isUnknown) and 3500 or 0

    local totalScore = math.floor((speciesScore * sizeMult * mutMult) + indexBonus)

    -- Цвет для ESP и интерфейса
    local espColor = Color3.fromRGB(255, 255, 255)
    local isSpecial = false
    if mutation == "Rainbow" or mutation == "Golden" then
        espColor = Color3.fromRGB(255, 215, 0)
        isSpecial = true
    elseif size == "Colossal" or size == "Huge" or size == "Giant" then
        espColor = Color3.fromRGB(186, 85, 211)
        isSpecial = true
    elseif mutation == "Silver" then
        espColor = Color3.fromRGB(192, 215, 255)
        isSpecial = true
    elseif isUnknown then
        espColor = Color3.fromRGB(255, 215, 0)
        isSpecial = true
    end

    return totalScore, isSpecial, size, mutation, reqGrip, espColor, isUnknown, specId
end

-- Логика скачки по каньону: пробег через все доступные по энергии локации
startCanyonRide = function()
    if BotState.IsRiding then return end
    BotState.IsRiding = true
    BotState.RideStatus = "Подготовка к заезду..."
    safeSetDesc(pRideStatus, BotState.RideStatus)

    safeNotify({
        Title = "Скачки 🦕",
        Content = "Запуск заезда через локации каньона...",
        Duration = 3,
        Icon = "zap"
    })

    -- 1. Спешиваемся если на тренажере
    if isPlayerOnMachine() then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.08)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
        NetBridge.machineDismount("jump")
        task.wait(0.5)
    end

    -- 2. Спешиваемся с хаб-маунта если есть
    pcall(function()
        if LocalPlayer.Character and LocalPlayer.Character:GetAttribute("HubMountSpecies") then
            NetBridge.equip(2, {slot = nil})
            task.wait(0.4)
        end
    end)

    -- 3. Экипируем верхового маунта (слот 2 в хотбаре)
    pcall(function()
        NetBridge.equip(2, {slot = 2})
    end)
    task.wait(0.6)

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        BotState.IsRiding = false
        BotState.RideStatus = "Ошибка: персонаж не найден"
        safeSetDesc(pRideStatus, BotState.RideStatus)
        return
    end

    -- 4. Телепортируемся на StartZonePad (рампа в начале каньона)
    local startX = Track.CENTRE_X or 41.38
    local startZ = Track.Z0 or -196.37
    local spawnCF = CFrame.new(startX, 27, startZ + 15)

    -- Пробуем телепорт несколько раз (сервер иногда реджектит)
    for attempt = 1, 3 do
        hrp.CFrame = spawnCF
        task.wait(0.35)
        local newPos = hrp.Position
        -- Если телепорт сработал (X близко к 41 и Z близко к старту)
        if math.abs(newPos.X - startX) < 20 and newPos.Z > startZ - 50 then
            break
        end
    end

    -- 5. Направляем камеру вперед в каньон
    pcall(function()
        workspace.CurrentCamera.CFrame = CFrame.lookAt(
            Vector3.new(startX, 30, startZ + 5),
            Vector3.new(startX, 26, startZ + 200)
        )
    end)

    -- 6. Бежим вперёд и прыгаем с рампы
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
    task.wait(0.8)

    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
    task.wait(0.12)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    task.wait(0.6)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)

    -- 7. Ожидаем начала заезда (riding = true)
    BotState.RideStatus = "Ожидание старта заезда..."
    safeSetDesc(pRideStatus, BotState.RideStatus)

    local waitStart = os.clock()
    while os.clock() - waitStart < 5 do
        task.wait(0.2)
        if NetBridge.state.ride and NetBridge.state.ride.riding then
            break
        end
    end

    -- Если так и не запустился — выходим
    if not (NetBridge.state.ride and NetBridge.state.ride.riding) then
        BotState.IsRiding = false
        BotState.RideStatus = "Не удалось начать заезд. Повтор через 60с."
        safeSetDesc(pRideStatus, BotState.RideStatus)
        return
    end

    BotState.RideStatus = "Скачка в каньоне! Поиск мобов..."
    safeSetDesc(pRideStatus, BotState.RideStatus)

    -- 8. Главный цикл приручения
    local lastTamedSpec = nil

    while isAlive() do
        local rState = NetBridge.state.ride
        if not rState or not rState.riding then
            break
        end

        local currentChar = LocalPlayer.Character
        local currentHrp = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
        if not currentHrp then break end

        local currentZ = currentHrp.Position.Z
        local myX = currentHrp.Position.X

        -- Зона и дистанция
        local zoneName = "Canyon"
        pcall(function()
            local stage = Track.stageAt and Track.stageAt(currentZ)
            if stage then zoneName = stage.name end
        end)
        local distanceM = math.max(0, math.floor(currentZ - startZ))

        -- Центр трека
        local trackCenter = startX
        pcall(function()
            trackCenter = Track.centreX(currentZ) or startX
        end)
        local diffCenter = trackCenter - myX

        -- Энергия игрока
        local stats = NetBridge.stats()
        local playerGrip = stats and stats.grip or 0

        -- Ручное управление игрока (A/D)
        local manualSteer = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
            manualSteer = -1
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
            manualSteer = 1
        end

        -- Состояние приручения
        local tameMode = TameModule.state.mode
        local tameFrac = tonumber(TameModule.state.fraction) or 0
        local currentSpec = TameModule.state.specId or "Unknown"
        local angryLeft = tonumber(TameModule.state.angryLeft) or 0
        local isAirborne = (RideModule.state.phase == "airborne")
        local isTamed = (tameMode == "tamed" or tameFrac >= 1.0)

        -- СОСТОЯНИЕ 1: В ПОЛЁТЕ
        if isAirborne then
            BotState.RideStatus = string.format("[%s • %dm] В полёте...", zoneName, distanceM)
            safeSetDesc(pRideStatus, BotState.RideStatus)
            safeSetDesc(pTameProgress, "В полёте к цели...")
            task.wait(0.12)
            continue
        end

        -- СОСТОЯНИЕ 2: ЗАПОЛНЕНИЕ ШКАЛЫ ПРИРУЧЕНИЯ
        if tameMode == "filling" and tameFrac < 1.0 then
            local percent = math.floor(tameFrac * 100)
            BotState.RideStatus = string.format("[%s • %dm] Приручение: %s 💖", zoneName, distanceM, tostring(currentSpec))
            safeSetDesc(pRideStatus, BotState.RideStatus)
            safeSetDesc(pTameProgress, string.format("Розовая шкала: %d%% (%s)", percent, tostring(currentSpec)))

            if manualSteer ~= 0 then
                RideModule.state.steer = manualSteer
            else
                RideModule.state.steer = math.clamp(diffCenter / 15, -0.6, 0.6)
            end
            RideModule.state.jumpWanted = false
            task.wait(0.15)
            continue
        end

        -- СОСТОЯНИЕ 3: ДИНОЗАВР ПРИРУЧЕН!
        if isTamed and lastTamedSpec ~= currentSpec
            and currentSpec ~= "CarnotaurusEvolved" and currentSpec ~= "Carnotaurus" then
            local currentSize = TameModule.state.size or TameModule.state.settledSize or "Normal"
            local currentMut = TameModule.state.mutation or TameModule.state.settledMutation or "None"
            local isNew = not NetBridge.knows(currentSpec)
            lastTamedSpec = currentSpec

            local notifTitle = isNew and "🎉 НОВЫЙ ВИД ОТКРЫТ!" or "Приручен! 💖"
            if currentMut ~= "None" and currentMut ~= "" then
                notifTitle = "🌟 [" .. currentMut .. "] " .. tostring(currentSpec) .. "!"
            elseif currentSize == "Colossal" or currentSize == "Huge" or currentSize == "Giant" then
                notifTitle = "👑 (" .. currentSize .. ") " .. tostring(currentSpec) .. "!"
            end

            safeSetDesc(pTameProgress, string.format("ПРИРУЧЕН 100%%! 🎉 %s", tostring(currentSpec)))
            safeNotify({
                Title = notifTitle,
                Content = tostring(currentSpec) ..
                    (currentMut ~= "None" and (" [" .. currentMut .. "]") or "") ..
                    (currentSize ~= "Normal" and (" (" .. currentSize .. ")") or ""),
                Duration = 4,
                Icon = "heart"
            })
            checkAndClaimIndex()
            notifyWebhookTamed(currentSpec, isNew, currentSize, currentMut)
        end

        -- СОСТОЯНИЕ 4: ПОИСК СЛЕДУЮЩЕЙ ЦЕЛИ
        local bestTarget = nil
        local bestDist = 180
        local bestScore = -1
        local targetLabel = ""

        local herd = workspace:FindFirstChild("StampedeHerd")
        if herd then
            local myPos = currentHrp.Position
            for _, dino in ipairs(herd:GetChildren()) do
                if dino:IsA("Model") and dino.PrimaryPart then
                    local dPos = dino.PrimaryPart.Position
                    local dz = dPos.Z - myPos.Z

                    -- Только те кто ВПЕРЕДИ нас
                    if dz > 5 and dz < 160 then
                        local score, isSpecial, size, mut, reqGrip, espColor, isUnknown, specId = getDinoRarity(dino, playerGrip)

                        -- Только если энергии хватает
                        if reqGrip <= playerGrip then
                            local dist = (dPos - myPos).Magnitude

                            -- ESP подсветка редких
                            if Config.DinoESP and isSpecial and not dino:FindFirstChild("DinoRarityGlow") then
                                pcall(function()
                                    local hl = Instance.new("Highlight")
                                    hl.Name = "DinoRarityGlow"
                                    hl.FillColor = espColor
                                    hl.FillTransparency = 0.35
                                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                                    hl.OutlineTransparency = 0.1
                                    hl.Adornee = dino
                                    hl.Parent = dino
                                end)
                            end

                            -- Выбор цели
                            local isBetter = false
                            if not bestTarget then
                                isBetter = true
                            elseif Config.PrioritizeRare then
                                -- Редкий приоритет: выбираем более редкого даже дальнего
                                if score > bestScore * 1.15 then
                                    isBetter = true
                                elseif score >= bestScore * 0.85 and dist < bestDist then
                                    isBetter = true
                                end
                            else
                                -- Без приоритета редкости: HuntUnindexed и ближний
                                if Config.HuntUnindexed and isUnknown and not (bestScore > 3000) then
                                    isBetter = true
                                elseif dist < bestDist then
                                    isBetter = true
                                end
                            end

                            if isBetter then
                                bestTarget = dino
                                bestDist = dist
                                bestScore = score

                                local tags = {}
                                if mut ~= "None" and mut ~= "" then table.insert(tags, mut) end
                                if size ~= "Normal" and size ~= "" then table.insert(tags, size) end
                                if isUnknown then table.insert(tags, "NEW") end
                                targetLabel = dino.Name .. (#tags > 0 and (" [" .. table.concat(tags, ",") .. "]") or "")
                            end
                        end
                    end
                end
            end
        end

        if bestTarget and bestTarget.PrimaryPart then
            local targetPos = bestTarget.PrimaryPart.Position
            local diffX = targetPos.X - currentHrp.Position.X

            if manualSteer ~= 0 then
                RideModule.state.steer = manualSteer
            else
                RideModule.state.steer = math.clamp(diffX / 12, -1, 1)
            end

            BotState.RideStatus = string.format("[%s • %dm] → %s (%.0fm)", zoneName, distanceM, targetLabel, bestDist)
            safeSetDesc(pRideStatus, BotState.RideStatus)

            -- Прыгаем: сразу если приручили, по дистанции или при сбросе
            local shouldJump = false
            if isTamed then
                shouldJump = bestDist <= 85 or (bestDist <= 115 and math.abs(diffX) <= 28)
            else
                shouldJump = (bestDist <= 72 and math.abs(diffX) <= 20)
                    or (angryLeft > 0 and angryLeft <= 3.5)
                    or tameMode == "warn"
            end

            if shouldJump then
                RideModule.state.jumpWanted = true
                pcall(function()
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    task.wait(0.06)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end)
                task.wait(0.3)
            else
                task.wait(0.1)
            end
        else
            -- Нет целей — держим центр
            if manualSteer ~= 0 then
                RideModule.state.steer = manualSteer
            else
                RideModule.state.steer = math.clamp(diffCenter / 15, -0.6, 0.6)
            end
            local baseDesc = isTamed
                and "Приручен! Скачем вперёд..."
                or string.format("Едем: %s (%.0fs до сброса)", tostring(currentSpec), angryLeft)
            BotState.RideStatus = string.format("[%s • %dm] %s", zoneName, distanceM, baseDesc)
            safeSetDesc(pRideStatus, BotState.RideStatus)
            task.wait(0.15)
        end
    end

    -- Завершение заезда
    BotState.RideStatus = "Возврат в хаб..."
    safeSetDesc(pRideStatus, BotState.RideStatus)
    pcall(function() NetBridge.rideEnd("done") end)
    task.wait(1.5)

    checkAndClaimIndex()
    task.wait(0.5)
    if Config.AutoTrain then
        teleportToStandAndMount()
    end

    BotState.IsRiding = false
    BotState.RideStatus = "В ожидании (готов к следующей скачке)"
    safeSetDesc(pRideStatus, BotState.RideStatus)

    safeNotify({
        Title = "Скачки 🦕",
        Content = "Заезд завершён! Вернулись в хаб.",
        Duration = 3,
        Icon = "check"
    })
end

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

secSettings:Slider({
    Title = "Интервал авто-скачек (сек)",
    Step = 15,
    Value = {
        Min = 45,
        Max = 300,
        Default = Config.RideInterval,
    },
    Callback = function(val)
        Config.RideInterval = val
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

secWebhook:Input({
    Title = "URL Вебхука (Webhook URL)",
    Desc = "Вставьте ссылку на ваш Discord Webhook",
    Value = Config.DiscordWebhook,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(text)
        Config.DiscordWebhook = text:gsub("%s+", "")
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
    Title = "Оповещения о приручении (Tame Alerts)",
    Desc = "Отправлять уведомление в Discord при приручении динозавра",
    Value = Config.WebhookOnTame,
    Callback = function(val)
        Config.WebhookOnTame = val
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
        if not Config.DiscordWebhook or Config.DiscordWebhook == "" or not Config.DiscordWebhook:find("http") then
            safeNotify({
                Title = "Ошибка вебхука ⚠️",
                Content = "Сначала укажите корректную ссылку на Discord Webhook!",
                Duration = 3,
                Icon = "alert-triangle"
            })
            return
        end
        sendStatsWebhookReport(true)
        safeNotify({
            Title = "Тест отправлен! 🚀",
            Content = "Проверьте ваш Discord канал!",
            Duration = 3,
            Icon = "send"
        })
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

            -- Автоскачки в каньоне (периодический заезд за новыми динозаврами)
            if Config.AutoRide and (now - BotState.LastRide >= Config.RideInterval) then
                BotState.LastRide = now
                task.spawn(startCanyonRide)
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
