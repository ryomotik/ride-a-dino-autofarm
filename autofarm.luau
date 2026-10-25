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
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

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

local ClientModules = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("RideADinoClient"):WaitForChild("Modules")
local NetBridge = require(ClientModules:WaitForChild("NetBridge"))
local GearMachine = require(ClientModules:WaitForChild("GearMachine"))
local AuraShopModule = require(ClientModules:WaitForChild("AuraShop"))
local RideModule = require(ClientModules:WaitForChild("Ride"))
local IndexModule = require(ClientModules:WaitForChild("Index"))

-- Очистка старых окон WindUI
pcall(function()
    for _, c in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if c.Name == "WindUI" or (c.Name == "RobloxGui" and c:FindFirstChild("WindUI")) then
            local w = c:FindFirstChild("WindUI") or c
            w:Destroy()
        end
    end
end)

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
    AutoClaimIndex = true,    -- Сбор наград Индекса
    DinoESP = true,           -- Подсветка новых/редких динозавров
    ChillVisuals = false,     -- Космическая неон-аура и шлейф (отключено по умолчанию)
    RideInterval = 120,       -- Интервал между скачками (сек)
    CheckInterval = 2,
}

local BotState = {
    Running = true,
    IsRiding = false,
    LastCheck = 0,
    LastClaim = 0,
    LastAuraCheck = 0,
    LastRide = 0,
    RideStatus = "В ожидании",
}

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

-- ==================== СОЗДАНИЕ ИНТЕРФЕЙСА WINDUI ====================
local Window = WindUI:CreateWindow({
    Title = "Ride A Dino! 🦕",
    Icon = "flame",
    Author = "by Antigravity • Chill Edition",
    Folder = "RideADinoAutofarm",
    Size = UDim2.fromOffset(630, 530),
    Theme = "Violet", -- Модный фиолетовый неоновый стиль
    Transparent = true,
    Resizable = true,
})

-- Вкладки
local TabAuto = Window:Tab({ Title = "Автофарм", Icon = "dumbbell" })
local TabRide = Window:Tab({ Title = "Скачки & Индекс", Icon = "zap" })
local TabVFX = Window:Tab({ Title = "Визуал & Чил", Icon = "sparkles" })
local TabStats = Window:Tab({ Title = "Статистика", Icon = "bar-chart-2" })
local TabSettings = Window:Tab({ Title = "Настройки", Icon = "settings" })

-- ==================== ВКЛАДКА 1: АВТОФАРМ ====================
local secAuto = TabAuto:Section({ Title = "Автоматизация тренировки и загона", Opened = true })

secAuto:Toggle({
    Title = "Авто-тренировка хвата (Grip)",
    Desc = "Постоянное нахождение на тренажере и удержание хвата",
    Value = Config.AutoTrain,
    Callback = function(val)
        Config.AutoTrain = val
        safeNotify({
            Title = "Автофарм",
            Content = val and "Авто-тренировка включена" or "Авто-тренировка выключена",
            Duration = 2,
            Icon = "dumbbell"
        })
    end
})

secAuto:Toggle({
    Title = "Авто-прокачка загона (Pen Upgrade)",
    Desc = "Автоматическое улучшение загона при накоплении средств",
    Value = Config.AutoPen,
    Callback = function(val)
        Config.AutoPen = val
        safeNotify({
            Title = "Автофарм",
            Content = val and "Авто-прокачка загона включена" or "Авто-прокачка загона выключена",
            Duration = 2,
            Icon = "home"
        })
    end
})

secAuto:Toggle({
    Title = "Авто-покупка тренажеров (Machine Tier)",
    Desc = "Приобретение следующего уровня машины при наличии денег",
    Value = Config.AutoMachine,
    Callback = function(val)
        Config.AutoMachine = val
        safeNotify({
            Title = "Автофарм",
            Content = val and "Авто-покупка машин включена" or "Авто-покупка машин выключена",
            Duration = 2,
            Icon = "cpu"
        })
    end
})

secAuto:Toggle({
    Title = "Авто-покупка и экипировка аур",
    Desc = "Автоматическая покупка лучших аур с множителем хвата",
    Value = Config.AutoAura,
    Callback = function(val)
        Config.AutoAura = val
        safeNotify({
            Title = "Автофарм",
            Content = val and "Авто-ауры включены" or "Авто-ауры выключены",
            Duration = 2,
            Icon = "zap"
        })
    end
})

secAuto:Toggle({
    Title = "Авто-сбор наград (Rewards)",
    Desc = "Сбор оффлайн наград и подарков каждые 30 секунд",
    Value = Config.AutoClaim,
    Callback = function(val)
        Config.AutoClaim = val
    end
})

secAuto:Toggle({
    Title = "Защита Anti-AFK",
    Desc = "Предотвращает кик из игры за бездействие",
    Value = Config.AntiAFK,
    Callback = function(val)
        Config.AntiAFK = val
    end
})

local secActions = TabAuto:Section({ Title = "Быстрые действия", Opened = true })

secActions:Button({
    Title = "Встать на тренажер",
    Desc = "Телепортироваться на свой тренажер и начать тренировку",
    Callback = function()
        teleportToStandAndMount()
        safeNotify({
            Title = "Тренажер",
            Content = "Телепортация на тренажер...",
            Duration = 2,
            Icon = "arrow-right-circle"
        })
    end
})

secActions:Button({
    Title = "Слезть с тренажера",
    Desc = "Спешиться с текущей машины",
    Callback = function()
        NetBridge.machineDismount("jump")
        safeNotify({
            Title = "Тренажер",
            Content = "Спешились с машины",
            Duration = 2,
            Icon = "log-out"
        })
    end
})

secActions:Button({
    Title = "Прокачать загон сейчас",
    Desc = "Улучшить свой загон вручную",
    Callback = function()
        local success = tryUpgradePen()
        if not success then
            local pen = getMyPen()
            local price = pen and pen:GetAttribute("Price") or 0
            safeNotify({
                Title = "Загон",
                Content = "Недостаточно средств: нужно " .. Format.money(price),
                Duration = 3,
                Icon = "alert-circle"
            })
        end
    end
})

secActions:Button({
    Title = "Купить следующий тренажер",
    Desc = "Приобрести следующий тир машины",
    Callback = function()
        local loadout = NetBridge.loadout()
        local stats = NetBridge.stats()
        local currentTier = loadout and loadout.tier or 1
        local nextTier = currentTier + 1
        local tierConfig = Gear.Tiers[nextTier]
        if tierConfig and stats then
            if stats.dollars >= tierConfig.price then
                NetBridge.buy(nextTier)
                safeNotify({
                    Title = "Тренажер",
                    Content = "Куплен тренажер: " .. tierConfig.name .. "!",
                    Duration = 3,
                    Icon = "check-circle"
                })
            else
                safeNotify({
                    Title = "Тренажер",
                    Content = "Недостаточно средств: нужно " .. Format.money(tierConfig.price),
                    Duration = 3,
                    Icon = "alert-circle"
                })
            end
        else
            safeNotify({
                Title = "Тренажер",
                Content = "Достигнут максимальный уровень машины!",
                Duration = 3,
                Icon = "award"
            })
        end
    end
})

-- ==================== ВКЛАДКА 2: СКАЧКИ & ИНДЕКС ====================
local secRide = TabRide:Section({ Title = "Автоскачки и Охота за Индексом", Opened = true })

local pRideStatus = secRide:Paragraph({ Title = "Статус скачек", Desc = "В ожидании" })
local pIndexCount = secRide:Paragraph({ Title = "Прогресс Индекса", Desc = "Загрузка..." })

-- Функция скачки с поиском редких и неизвестных динозавров
local function startCanyonRide()
    if BotState.IsRiding then return end
    BotState.IsRiding = true
    BotState.RideStatus = "Подготовка к заезду..."
    pRideStatus:SetDesc(BotState.RideStatus)

    safeNotify({
        Title = "Скачки 🦕",
        Content = "Запуск скачки на динозаврах/драконах...",
        Duration = 3,
        Icon = "zap"
    })

    -- 1. Спешиваемся с тренажера
    if isPlayerOnMachine() then
        NetBridge.machineDismount("jump")
        task.wait(0.4)
    end

    -- 2. Экипируем верхового маунта (слот 2 в хотбаре)
    pcall(function()
        NetBridge.equip(2, {slot = 2})
    end)
    task.wait(0.6)

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        BotState.IsRiding = false
        BotState.RideStatus = "Ошибка: персонаж не найден"
        pRideStatus:SetDesc(BotState.RideStatus)
        return
    end

    -- 3. Телепортируемся на рампу перед обрывом
    hrp.CFrame = CFrame.lookAt(Vector3.new(41.38, 26, -215), Vector3.new(41.38, 26, -100))
    task.wait(0.3)

    -- 4. Направляем камеру прямо в каньон (+Z)
    workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(41.38, 30, -225), Vector3.new(41.38, 26, -100))

    -- 5. Бежим вперед к обрыву
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
    task.wait(0.7)

    -- 6. Прыгаем с обрыва в каньон!
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)

    task.wait(1.2)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)

    -- 7. Ожидаем подтверждения старта заезда
    local waitStart = os.clock()
    while os.clock() - waitStart < 4 do
        task.wait(0.2)
        if NetBridge.state.ride and NetBridge.state.ride.riding then
            break
        end
    end

    BotState.RideStatus = "Скачка в каньоне! Поиск редких мобов..."
    pRideStatus:SetDesc(BotState.RideStatus)

    -- 8. Цикл скачки (до 40 секунд)
    local rideEndTime = os.clock() + 40
    while BotState.Running and os.clock() < rideEndTime do
        local rState = NetBridge.state.ride
        if not rState or not rState.riding or RideModule.state.phase == "idle" then
            break
        end

        local currentChar = LocalPlayer.Character
        local currentHrp = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
        if not currentHrp then break end

        -- Поиск неизвестных динозавров в стаде каньона
        local unindexedTarget = nil
        local herd = workspace:FindFirstChild("StampedeHerd")
        if herd and Config.HuntUnindexed then
            local closestDist = 130
            for _, dino in ipairs(herd:GetChildren()) do
                if dino:IsA("Model") and dino.PrimaryPart then
                    local name = dino.Name
                    local isUnknown = not NetBridge.knows(name)
                    
                    -- Glow ESP для динозавра
                    if Config.DinoESP and isUnknown and not dino:FindFirstChild("IndexHuntGlow") then
                        pcall(function()
                            local hl = Instance.new("Highlight")
                            hl.Name = "IndexHuntGlow"
                            hl.FillColor = Color3.fromRGB(255, 215, 0)
                            hl.FillTransparency = 0.4
                            hl.OutlineColor = Color3.fromRGB(255, 255, 120)
                            hl.Adornee = dino
                            hl.Parent = dino
                        end)
                    end

                    local dist = (dino.PrimaryPart.Position - currentHrp.Position).Magnitude
                    if isUnknown and dist < closestDist then
                        closestDist = dist
                        unindexedTarget = dino
                    end
                end
            end
        end

        -- Рулим к не открытому в Индексе динозавру
        if unindexedTarget and unindexedTarget.PrimaryPart then
            local diffX = unindexedTarget.PrimaryPart.Position.X - currentHrp.Position.X
            RideModule.state.steer = math.clamp(diffX / 15, -1, 1)
            RideModule.state.jumpWanted = true
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end)
        elseif Config.AutoLeap then
            -- Стандартный прыжок на ближайшего динозавра
            RideModule.state.jumpWanted = true
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end)
            RideModule.state.steer = 0
        end

        task.wait(1.5)
    end

    -- 9. Завершаем скачку и возвращаемся
    BotState.RideStatus = "Возврат в хаб и сбор наград..."
    pRideStatus:SetDesc(BotState.RideStatus)
    pcall(function()
        NetBridge.rideEnd("done")
    end)
    task.wait(1.5)

    -- Проверяем новые открытия в Индексе
    checkAndClaimIndex()

    -- 10. Возвращаемся на тренажер
    task.wait(0.5)
    if Config.AutoTrain then
        teleportToStandAndMount()
    end

    BotState.IsRiding = false
    BotState.RideStatus = "В ожидании (готов к следующей скачке)"
    pRideStatus:SetDesc(BotState.RideStatus)

    safeNotify({
        Title = "Скачки 🦕",
        Content = "Скачка завершена! Награды собраны, вернулись на тренажер.",
        Duration = 3,
        Icon = "check"
    })
end

secRide:Toggle({
    Title = "Авто-скачки в каньоне (Auto Ride)",
    Desc = "Периодические забеги по каньону на драконах и динозаврах",
    Value = Config.AutoRide,
    Callback = function(val)
        Config.AutoRide = val
        safeNotify({
            Title = "Скачки",
            Content = val and "Авто-скачки включены!" or "Авто-скачки выключены",
            Duration = 2,
            Icon = "zap"
        })
    end
})

secRide:Toggle({
    Title = "Охота на новых динозавров (Hunt Missing)",
    Desc = "Приоритет прыжков на мобов, которых еще нет в вашем Индексе",
    Value = Config.HuntUnindexed,
    Callback = function(val)
        Config.HuntUnindexed = val
    end
})

secRide:Toggle({
    Title = "Авто-прыжки и приручение (Auto Leap)",
    Desc = "Автоматические прыжки на диких мобов во время заезда",
    Value = Config.AutoLeap,
    Callback = function(val)
        Config.AutoLeap = val
    end
})

secRide:Toggle({
    Title = "Авто-сбор наград Индекса (Claim Rewards)",
    Desc = "Автоматически забирать алмазы и награды за открытые виды",
    Value = Config.AutoClaimIndex,
    Callback = function(val)
        Config.AutoClaimIndex = val
        if val then checkAndClaimIndex() end
    end
})

secRide:Toggle({
    Title = "Glow ESP на новых динозаврах",
    Desc = "Золотая подсветка динозавров, которых еще нет в Индексе",
    Value = Config.DinoESP,
    Callback = function(val)
        Config.DinoESP = val
    end
})

secRide:Button({
    Title = "🏇 Начать скачки прямо сейчас",
    Desc = "Немедленно оседлать маунта и запрыгнуть в каньон",
    Callback = function()
        task.spawn(startCanyonRide)
    end
})

secRide:Button({
    Title = "🛑 Завершить скачку / Вернуться",
    Desc = "Досрочно остановить заезд и телепортироваться в хаб",
    Callback = function()
        pcall(function()
            NetBridge.rideEnd("done")
        end)
        task.wait(1)
        if Config.AutoTrain then
            teleportToStandAndMount()
        end
        safeNotify({
            Title = "Скачки",
            Content = "Заезд завершен, вернулись в хаб",
            Duration = 2,
            Icon = "home"
        })
    end
})

-- ==================== ВКЛАДКА 3: ВИЗУАЛ & ЧИЛ ====================
local secVFX = TabVFX:Section({ Title = "Кайфовый неон-визуал и частицы", Opened = true })

secVFX:Toggle({
    Title = "Космическая Аура и Партиклы (Neon Aura)",
    Desc = "Фиолетово-бирюзовые неоновые искры и космический туман вокруг персонажа",
    Value = Config.ChillVisuals,
    Callback = function(val)
        Config.ChillVisuals = val
        applyChillVisuals(val)
        safeNotify({
            Title = "Визуал",
            Content = val and "Неоновая аура активирована!" or "Аура отключена",
            Duration = 2,
            Icon = "sparkles"
        })
    end
})

secVFX:Button({
    Title = "✨ Перезапустить Аура-Эффекты",
    Desc = "Обновить частицы и световой шлейф персонажа",
    Callback = function()
        applyChillVisuals(true)
        safeNotify({
            Title = "Визуал",
            Content = "Эффекты успешно обновлены!",
            Duration = 2,
            Icon = "check"
        })
    end
})

-- ==================== ВКЛАДКА 4: СТАТИСТИКА ====================
local secStats = TabStats:Section({ Title = "Текущие показатели игрока", Opened = true })

local pGrip = secStats:Paragraph({ Title = "Хватка (Grip)", Desc = "Загрузка..." })
local pDollars = secStats:Paragraph({ Title = "Баланс ($)", Desc = "Загрузка..." })
local pIncome = secStats:Paragraph({ Title = "Доход загона ($/сек)", Desc = "Загрузка..." })
local pAura = secStats:Paragraph({ Title = "Аура и Множитель", Desc = "Загрузка..." })
local pMachine = secStats:Paragraph({ Title = "Текущий тренажер", Desc = "Загрузка..." })
local pPen = secStats:Paragraph({ Title = "Загон и Вместимость", Desc = "Загрузка..." })

-- Обновление статистики
local function updateStatsUI()
    pcall(function()
        local stats = NetBridge.stats()
        local loadout = NetBridge.loadout()
        local pen = NetBridge.pen()
        local aura = NetBridge.state.aura
        local penInstance = getMyPen()

        if stats then
            pGrip:SetDesc(Format.abbreviate(stats.grip or 0) .. " (" .. tostring(stats.grip or 0) .. ")")
            pDollars:SetDesc(Format.money(stats.dollars or 0))
        end

        if pen then
            pIncome:SetDesc(Format.money(pen.income or 0) .. " в секунду")
        end

        if aura and aura.equipped then
            local auraData = Training.Auras[aura.equipped]
            local mult = auraData and auraData.gripMult or 1
            pAura:SetDesc(tostring(aura.equipped):upper() .. " (Множитель хвата: x" .. tostring(mult) .. ")")
        end

        if loadout then
            local tier = loadout.tier or 1
            local tierData = Gear.Tiers[tier]
            local tierName = tierData and tierData.name or ("Tier " .. tostring(tier))
            local nextTier = tier + 1
            local nextTierData = Gear.Tiers[nextTier]
            local nextText = nextTierData and (" • След.: " .. Format.money(nextTierData.price)) or " • МАКС."
            pMachine:SetDesc(tierName .. nextText)
        end

        if penInstance then
            local lvl = penInstance:GetAttribute("Level") or 1
            local price = penInstance:GetAttribute("Price") or 0
            local cap = (pen and pen.capacity) or "?"
            local nextText = price > 0 and (" • След. апгрейд: " .. Format.money(price)) or " • МАКС."
            pPen:SetDesc("Уровень " .. tostring(lvl) .. " (Вместимость: " .. tostring(cap) .. " дино)" .. nextText)
        end

        if IndexModule and IndexModule.state and IndexModule.state.known then
            local knownCount = 0
            for _ in pairs(IndexModule.state.known) do
                knownCount = knownCount + 1
            end
            pIndexCount:SetDesc("Открыто видов: " .. tostring(knownCount) .. " / 58")
        end
    end)
end

-- ==================== ВКЛАДКА 5: НАСТРОЙКИ ====================
local secSettings = TabSettings:Section({ Title = "Параметры и темы", Opened = true })

secSettings:Slider({
    Title = "Интервал проверки (сек)",
    Step = 1,
    Value = {
        Min = 1,
        Max = 10,
        Default = Config.CheckInterval,
    },
    Callback = function(val)
        Config.CheckInterval = val
    end
})

secSettings:Slider({
    Title = "Интервал авто-скачек (сек)",
    Step = 30,
    Value = {
        Min = 60,
        Max = 300,
        Default = Config.RideInterval,
    },
    Callback = function(val)
        Config.RideInterval = val
    end
})

secSettings:Dropdown({
    Title = "Тема оформления",
    Desc = "Выберите визуальную тему интерфейса",
    Values = { "Violet", "Indigo", "Dark", "Rose", "Sky", "Emerald" },
    Value = "Violet",
    Callback = function(themeName)
        WindUI:SetTheme(themeName)
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
    print("[Ride A Dino Autofarm | Chill Edition] Бот успешно запущен!")
    safeNotify({
        Title = "Ride A Dino! 🦕",
        Content = "Автофарм запущен в стильном фиолетовом вайбе!",
        Duration = 4,
        Icon = "sparkles"
    })

    -- Начальная посадка на тренажер
    if Config.AutoTrain and not isPlayerOnMachine() then
        teleportToStandAndMount()
    end

    while BotState.Running do
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
        end

        -- Обновление статистики в UI
        updateStatsUI()

        task.wait(1)
    end
end)
