--[[
    🦕 Ride A Dino! [☄️] — Advanced Autofarm Bot (WindUI Edition)
    Разработано под игру "Ride A Dino!" (PlaceId: 93523763376122)
    
    Визуальный стиль: WindUI (футуристичный дизайн с закругленными панелями, иконками и темами)
    
    Возможности:
    - 🏋️ Авто-тренировка хвата (Grip): авто-посадка на тренажер и удержание
    - 🏡 Авто-прокачка загона (Pen Upgrade): рост пассивного дохода ($/сек)
    - 🦾 Авто-покупка новых тренажеров (Machine Tiers)
    - ✨ Авто-покупка и экипировка лучших аур (Aura Multipliers)
    - 🎁 Авто-сбор оффлайн наград и подарков (Offline Rewards & Gifts)
    - 🛡️ Защита Anti-AFK от кика за неактивность
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

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

-- Загрузка UI библиотеки WindUI
local WindUISuccess, WindUI = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not WindUISuccess or type(WindUI) ~= "table" then
    WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end

-- Переменные конфигурации автофарма
local Config = {
    AutoTrain = true,
    AutoPen = true,
    AutoMachine = true,
    AutoAura = true,
    AutoClaim = true,
    AntiAFK = true,
    CheckInterval = 2,
}

local BotState = {
    Running = true,
    LastCheck = 0,
    LastClaim = 0,
    LastAuraCheck = 0,
}

-- Вспомогательные функции поиска стенда и загона
local function getMyStand()
    local userId = LocalPlayer.UserId
    local machines = workspace:FindFirstChild("RideADinoMachines")
    if machines then
        for _, m in ipairs(machines:GetChildren()) do
            if m:GetAttribute("Owner") == userId then
                return m, m:GetAttribute("Plot") or 1
            end
        end
    end
    local fallback = machines and machines:FindFirstChild("Plot1")
    return fallback, (fallback and fallback:GetAttribute("Plot")) or 1
end

local function getMyPen()
    local _, plotNum = getMyStand()
    local pens = workspace:FindFirstChild("Pens")
    if pens then
        local pen = pens:FindFirstChild("Plot" .. tostring(plotNum))
        return pen, plotNum
    end
    return nil, plotNum
end

local function isPlayerOnMachine()
    local char = LocalPlayer.Character
    if not char then return false end
    return char:GetAttribute("TrainingMachine") == true
end

local function teleportToStandAndMount()
    local stand = getMyStand()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not stand or not hrp then return end

    local targetCF = (stand.PrimaryPart and stand.PrimaryPart.CFrame) or stand:GetPivot()
    if targetCF then
        hrp.CFrame = targetCF * CFrame.new(0, 3, 0)
        task.wait(0.3)
        NetBridge.machineMount()
    end
end

-- Создание окна WindUI
local Window = WindUI:CreateWindow({
    Title = "Ride A Dino! 🦕",
    Icon = "flame",
    Author = "by Antigravity • Futuristic Autofarm",
    Folder = "RideADinoAutofarm",
    Size = UDim2.fromOffset(620, 500),
    Theme = "Dark",
    Transparent = true,
    Resizable = true,
})

-- Создание вкладок
local TabAuto = Window:Tab({ Title = "Автофарм", Icon = "sparkles" })
local TabStats = Window:Tab({ Title = "Статистика", Icon = "bar-chart-2" })
local TabSettings = Window:Tab({ Title = "Настройки", Icon = "settings" })

-- Секция "Автоматизация"
local secAuto = TabAuto:Section({ Title = "Управление автофармом", Opened = true })

secAuto:Toggle({
    Title = "Авто-тренировка хвата (Grip)",
    Desc = "Непрерывная тренировка на машине с авто-возвратом",
    Value = Config.AutoTrain,
    Callback = function(val)
        Config.AutoTrain = val
        WindUI:Notify({
            Title = "Автофарм",
            Content = val and "Авто-тренировка включена" or "Авто-тренировка выключена",
            Duration = 2,
            Icon = "dumbbell"
        })
    end
})

secAuto:Toggle({
    Title = "Авто-прокачка загона (Pen Upgrade)",
    Desc = "Повышает уровень загона для роста дохода ($/сек)",
    Value = Config.AutoPen,
    Callback = function(val)
        Config.AutoPen = val
        WindUI:Notify({
            Title = "Автофарм",
            Content = val and "Авто-прокачка загона включена" or "Авто-прокачка загона выключена",
            Duration = 2,
            Icon = "home"
        })
    end
})

secAuto:Toggle({
    Title = "Авто-покупка тренажеров (Machine Tier)",
    Desc = "Покупка новых тиров тренажера при накоплении денег",
    Value = Config.AutoMachine,
    Callback = function(val)
        Config.AutoMachine = val
        WindUI:Notify({
            Title = "Автофарм",
            Content = val and "Авто-покупка машин включена" or "Авто-покупка машин выключена",
            Duration = 2,
            Icon = "cpu"
        })
    end
})

secAuto:Toggle({
    Title = "Авто-покупка и экипировка аур",
    Desc = "Покупка и экипировка лучшей ауры (множитель хвата)",
    Value = Config.AutoAura,
    Callback = function(val)
        Config.AutoAura = val
        WindUI:Notify({
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
    Desc = "Предотвращает кик из игры за 20 минут бездействия",
    Value = Config.AntiAFK,
    Callback = function(val)
        Config.AntiAFK = val
    end
})

-- Секция "Быстрые действия"
local secActions = TabAuto:Section({ Title = "Быстрые действия", Opened = true })

secActions:Button({
    Title = "Встать на тренажер",
    Desc = "Телепортироваться на свой тренажер и начать тренировку",
    Callback = function()
        teleportToStandAndMount()
        WindUI:Notify({
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
        WindUI:Notify({
            Title = "Тренажер",
            Content = "Спешились с машины",
            Duration = 2,
            Icon = "log-out"
        })
    end
})

secActions:Button({
    Title = "Прокачать загон сейчас",
    Desc = "Улучшить загон вручную",
    Callback = function()
        local pen, plotNum = getMyPen()
        local stats = NetBridge.stats()
        if pen and stats then
            local lvl = pen:GetAttribute("Level") or 1
            local price = pen:GetAttribute("Price") or 0
            if stats.dollars >= price and price > 0 then
                NetBridge.penUpgrade(plotNum, lvl, false)
                WindUI:Notify({
                    Title = "Загон",
                    Content = "Загон улучшен до уровня " .. tostring(lvl + 1) .. "!",
                    Duration = 3,
                    Icon = "check-circle"
                })
            else
                WindUI:Notify({
                    Title = "Загон",
                    Content = "Недостаточно средств: нужно " .. Format.money(price),
                    Duration = 3,
                    Icon = "alert-circle"
                })
            end
        end
    end
})

secActions:Button({
    Title = "Купить следующий тренажер",
    Desc = "Приобрести следующий тир тренажера",
    Callback = function()
        local loadout = NetBridge.loadout()
        local stats = NetBridge.stats()
        local currentTier = loadout and loadout.tier or 1
        local nextTier = currentTier + 1
        local tierConfig = Gear.Tiers[nextTier]
        if tierConfig and stats then
            if stats.dollars >= tierConfig.price then
                NetBridge.buy(nextTier)
                WindUI:Notify({
                    Title = "Тренажер",
                    Content = "Куплен тренажер: " .. tierConfig.name .. "!",
                    Duration = 3,
                    Icon = "check-circle"
                })
            else
                WindUI:Notify({
                    Title = "Тренажер",
                    Content = "Недостаточно средств: нужно " .. Format.money(tierConfig.price),
                    Duration = 3,
                    Icon = "alert-circle"
                })
            end
        else
            WindUI:Notify({
                Title = "Тренажер",
                Content = "Достигнут максимальный уровень машины!",
                Duration = 3,
                Icon = "award"
            })
        end
    end
})

-- Секция "Статистика"
local secStats = TabStats:Section({ Title = "Текущие показатели", Opened = true })

local pGrip = secStats:Paragraph({ Title = "Хватка (Grip)", Desc = "Загрузка..." })
local pDollars = secStats:Paragraph({ Title = "Баланс ($)", Desc = "Загрузка..." })
local pIncome = secStats:Paragraph({ Title = "Доход загона ($/сек)", Desc = "Загрузка..." })
local pAura = secStats:Paragraph({ Title = "Аура и Множитель", Desc = "Загрузка..." })
local pMachine = secStats:Paragraph({ Title = "Текущий тренажер", Desc = "Загрузка..." })
local pPen = secStats:Paragraph({ Title = "Загон и Вместимость", Desc = "Загрузка..." })

-- Секция "Настройки"
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

secSettings:Dropdown({
    Title = "Тема оформления",
    Desc = "Выберите визуальную тему интерфейса",
    Values = { "Dark", "Rose", "Indigo", "Sky", "Emerald", "Violet" },
    Value = "Dark",
    Callback = function(themeName)
        WindUI:SetTheme(themeName)
    end
})

secSettings:Button({
    Title = "Выгрузить автофарм (Unload)",
    Desc = "Полностью закрыть скрипт и очистить интерфейс",
    Callback = function()
        BotState.Running = false
        if Window.Destroy then
            Window:Destroy()
        end
    end
})

-- Безопасная покупка ауры
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

        if stand and stand.PrimaryPart then
            hrp.CFrame = stand.PrimaryPart.CFrame * CFrame.new(0, 3, 0)
            task.wait(0.4)
            NetBridge.machineMount()
        end
    elseif bestOwned and bestOwned ~= equipped then
        NetBridge.auraAction("equip", bestOwned)
    end
end

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

-- Очистка при перезагрузке
if typeof(STATE) == "table" and STATE.onCleanup then
    STATE.onCleanup(function()
        BotState.Running = false
        if afkConn then afkConn:Disconnect() end
        if Window and Window.Destroy then Window:Destroy() end
    end)
end

-- Основной цикл
task.spawn(function()
    print("[Ride A Dino Autofarm | WindUI] Бот успешно запущен!")
    WindUI:Notify({
        Title = "Ride A Dino! 🦕",
        Content = "Автофарм запущен в современном стиле WindUI!",
        Duration = 4,
        Icon = "sparkles"
    })

    if Config.AutoTrain and not isPlayerOnMachine() then
        teleportToStandAndMount()
    end

    while BotState.Running do
        local now = os.clock()

        if Config.AutoTrain and (now - BotState.LastCheck >= Config.CheckInterval) then
            BotState.LastCheck = now

            if not isPlayerOnMachine() then
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    teleportToStandAndMount()
                end
            end

            -- Авто-прокачка загона
            if Config.AutoPen then
                local pen, plotNum = getMyPen()
                local stats = NetBridge.stats()
                if pen and stats then
                    local lvl = pen:GetAttribute("Level") or 1
                    local price = pen:GetAttribute("Price") or 0
                    if price > 0 and stats.dollars >= price then
                        NetBridge.penUpgrade(plotNum, lvl, false)
                        WindUI:Notify({
                            Title = "Загон прокачан!",
                            Content = "Уровень " .. tostring(lvl + 1) .. "! Доход вырос.",
                            Duration = 3,
                            Icon = "trending-up"
                        })
                    end
                end
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
                    WindUI:Notify({
                        Title = "Новый тренажер!",
                        Content = "Приобретен: " .. tierConfig.name,
                        Duration = 4,
                        Icon = "award"
                    })
                end
            end
        end

        -- Проверка аур
        if Config.AutoAura and (now - BotState.LastAuraCheck >= 15) then
            BotState.LastAuraCheck = now
            pcall(tryUpgradeAura)
        end

        -- Сбор наград
        if Config.AutoClaim and (now - BotState.LastClaim >= 30) then
            BotState.LastClaim = now
            pcall(function()
                NetBridge.offlineClaim()
                NetBridge.giftClaim(true)
            end)
        end

        -- Обновление статистики
        updateStatsUI()

        task.wait(1)
    end
end)
