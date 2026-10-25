--[[
    🦕 Ride A Dino! [☄️] — Advanced Autofarm Bot (Maclib UI)
    Разработано специально под игру "Ride A Dino!" (PlaceId: 93523763376122)
    
    Возможности:
    - 🏋️ Авто-тренировка хвата (Grip): авто-посадка на тренажер и удержание
    - 🏡 Авто-прокачка загона (Pen Upgrade): авто-покупка слотов для роста пассивного дохода ($)
    - 🦾 Авто-покупка новых тренажеров (Next Machine Tier)
    - ✨ Авто-покупка и экипировка лучших аур (Aura Multiplier)
    - 🎁 Авто-сбор наград (Offline Rewards & Gifts)
    - 🛡️ Защита Anti-AFK против вылета за неактивность
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

-- Подключение игровых модулей Ride A Dino
local RideADino = ReplicatedStorage:WaitForChild("RideADino", 15)
assert(RideADino, "Не удалось найти папку RideADino в ReplicatedStorage")

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

-- Загрузка UI библиотеки Maclib
local MacLibSuccess, MacLib = pcall(function()
    return loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()
end)
if not MacLibSuccess or type(MacLib) ~= "table" then
    warn("[Autofarm] Ошибка загрузки Maclib, загрузка резервной копии...")
    MacLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/biggaboy212/Maclib/main/maclib.txt"))()
end

-- Переменные состояния и настроек автофарма
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
    Status = "Инициализация...",
}

-- Вспомогательные функции для поиска стенда и загона игрока
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
    -- Fallback на Plot1
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

-- Создание интерфейса Maclib
local Window = MacLib:Window({
    Title = "Ride A Dino! 🦕 | Автофарм",
    Subtitle = "Advanced Automation • Maclib UI",
    Size = UDim2.fromOffset(800, 520),
    DragStyle = 1,
    DisabledWindowControls = {},
    ShowUserInfo = true,
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
})

local tabGroup = Window:TabGroup()

local tabs = {
    Main = tabGroup:Tab({ Name = "Автофарм", Image = "rbxassetid://18821914323" }),
    Stats = tabGroup:Tab({ Name = "Статистика", Image = "rbxassetid://10734950309" }),
    Settings = tabGroup:Tab({ Name = "Настройки", Image = "rbxassetid://10734950309" })
}

-- Секции на вкладке "Автофарм"
local autoSection = tabs.Main:Section({ Side = "Left" })
local actionSection = tabs.Main:Section({ Side = "Right" })

autoSection:Header({ Text = "⚙️ Автоматизация" })

autoSection:Toggle({
    Name = "Авто-тренировка хвата (Grip)",
    Default = Config.AutoTrain,
    Callback = function(val)
        Config.AutoTrain = val
        Window:Notify({
            Title = "Автофарм",
            Description = val and "Авто-тренировка включена" or "Авто-тренировка выключена",
            Lifetime = 2
        })
    end,
}, "AutoTrainToggle")

autoSection:Toggle({
    Name = "Авто-прокачка загона (Pen Upgrade)",
    Default = Config.AutoPen,
    Callback = function(val)
        Config.AutoPen = val
        Window:Notify({
            Title = "Автофарм",
            Description = val and "Авто-прокачка загона включена" or "Авто-прокачка загона выключена",
            Lifetime = 2
        })
    end,
}, "AutoPenToggle")

autoSection:Toggle({
    Name = "Авто-покупка тренажеров (Machine Tier)",
    Default = Config.AutoMachine,
    Callback = function(val)
        Config.AutoMachine = val
        Window:Notify({
            Title = "Автофарм",
            Description = val and "Авто-покупка тренажеров включена" or "Авто-покупка тренажеров выключена",
            Lifetime = 2
        })
    end,
}, "AutoMachineToggle")

autoSection:Toggle({
    Name = "Авто-покупка и экип лучших аур",
    Default = Config.AutoAura,
    Callback = function(val)
        Config.AutoAura = val
        Window:Notify({
            Title = "Автофарм",
            Description = val and "Авто-ауры включены" or "Авто-ауры выключены",
            Lifetime = 2
        })
    end,
}, "AutoAuraToggle")

autoSection:Toggle({
    Name = "Авто-сбор подарков и наград",
    Default = Config.AutoClaim,
    Callback = function(val)
        Config.AutoClaim = val
        Window:Notify({
            Title = "Автофарм",
            Description = val and "Авто-сбор наград включен" or "Авто-сбор наград выключен",
            Lifetime = 2
        })
    end,
}, "AutoClaimToggle")

autoSection:Toggle({
    Name = "Защита Anti-AFK (от вылета)",
    Default = Config.AntiAFK,
    Callback = function(val)
        Config.AntiAFK = val
    end,
}, "AntiAFKToggle")

-- Секция быстрых действий
actionSection:Header({ Text = "⚡ Быстрые действия" })

actionSection:Button({
    Name = "Встать на свой тренажер",
    Callback = function()
        teleportToStandAndMount()
        Window:Notify({
            Title = "Тренажер",
            Description = "Телепортация и посадка на тренажер...",
            Lifetime = 2
        })
    end,
})

actionSection:Button({
    Name = "Слезть с тренажера",
    Callback = function()
        NetBridge.machineDismount("jump")
        Window:Notify({
            Title = "Тренажер",
            Description = "Спешились с машины",
            Lifetime = 2
        })
    end,
})

actionSection:Button({
    Name = "Прокачать загон сейчас",
    Callback = function()
        local pen, plotNum = getMyPen()
        local stats = NetBridge.stats()
        if pen and stats then
            local lvl = pen:GetAttribute("Level") or 1
            local price = pen:GetAttribute("Price") or 0
            if stats.dollars >= price and price > 0 then
                NetBridge.penUpgrade(plotNum, lvl, false)
                Window:Notify({
                    Title = "Загон",
                    Description = "Загон успешно улучшен до ур. " .. tostring(lvl + 1),
                    Lifetime = 3
                })
            else
                Window:Notify({
                    Title = "Загон",
                    Description = "Недостаточно средств: нужно " .. Format.money(price),
                    Lifetime = 3
                })
            end
        end
    end,
})

actionSection:Button({
    Name = "Купить следующий тренажер",
    Callback = function()
        local loadout = NetBridge.loadout()
        local stats = NetBridge.stats()
        local currentTier = loadout and loadout.tier or 1
        local nextTier = currentTier + 1
        local tierConfig = Gear.Tiers[nextTier]
        if tierConfig and stats then
            if stats.dollars >= tierConfig.price then
                NetBridge.buy(nextTier)
                Window:Notify({
                    Title = "Тренажер",
                    Description = "Куплен тренажер: " .. tierConfig.name,
                    Lifetime = 3
                })
            else
                Window:Notify({
                    Title = "Тренажер",
                    Description = "Недостаточно средств на " .. tierConfig.name .. " (нужно " .. Format.money(tierConfig.price) .. ")",
                    Lifetime = 3
                })
            end
        else
            Window:Notify({
                Title = "Тренажер",
                Description = "Достигнут максимальный уровень тренажера!",
                Lifetime = 3
            })
        end
    end,
})

-- Секции вкладки "Статистика"
local statsLeft = tabs.Stats:Section({ Side = "Left" })
local statsRight = tabs.Stats:Section({ Side = "Right" })

statsLeft:Header({ Text = "📊 Показатели игрока" })
local lblGrip = statsLeft:Label({ Text = "Хватка (Grip): Загрузка..." })
local lblDollars = statsLeft:Label({ Text = "Баланс: Загрузка..." })
local lblIncome = statsLeft:Label({ Text = "Доход загона: Загрузка..." })
local lblAura = statsLeft:Label({ Text = "Аура: Загрузка..." })

statsRight:Header({ Text = "🛠️ Уровни и улучшения" })
local lblMachine = statsRight:Label({ Text = "Тренажер: Загрузка..." })
local lblPen = statsRight:Label({ Text = "Уровень загона: Загрузка..." })
local lblNextPenCost = statsRight:Label({ Text = "След. апгрейд загона: Загрузка..." })
local lblNextMachCost = statsRight:Label({ Text = "След. тренажер: Загрузка..." })

-- Секция настроек
local settingsSection = tabs.Settings:Section({ Side = "Left" })
settingsSection:Header({ Text = "⚙️ Параметры работы" })

settingsSection:Slider({
    Name = "Интервал проверки (сек)",
    Default = Config.CheckInterval,
    Minimum = 1,
    Maximum = 10,
    DisplayMethod = "Value",
    Precision = 0,
    Callback = function(val)
        Config.CheckInterval = val
    end,
}, "CheckIntervalSlider")

settingsSection:Button({
    Name = "Выгрузить автофарм (Unload)",
    Callback = function()
        BotState.Running = false
        Window:Notify({
            Title = "Автофарм",
            Description = "Автофарм завершает работу...",
            Lifetime = 2
        })
    end,
})

-- Функция безопасной покупки ауры (с временным визитом в AuraShop)
local function tryUpgradeAura()
    local stats = NetBridge.stats()
    local auraState = NetBridge.state.aura
    if not stats or not auraState then return end

    local currentDollars = stats.dollars or 0
    local owned = auraState.owned or {}
    local equipped = auraState.equipped or ""

    -- Порядок аур от lvl1 до lvl12
    local auraOrder = {"lvl1", "lvl2", "lvl3", "lvl4", "lvl5", "lvl6", "lvl7", "lvl8", "lvl9", "lvl10", "lvl11", "lvl12"}

    -- Ищем лучшую доступную для покупки ауру
    local bestAffordable = nil
    for _, id in ipairs(auraOrder) do
        local info = Training.Auras[id]
        if info and not owned[id] and currentDollars >= info.price then
            bestAffordable = id
        end
    end

    -- Ищем наивысшую имеющуюся ауру
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

        local origCF = hrp.CFrame
        -- Спешиваемся с тренажера
        NetBridge.machineDismount("jump")
        task.wait(0.4)

        -- Телепортируемся в зону магазина аур (24.98, 26.5, -267.50)
        hrp.CFrame = CFrame.new(24.98, 26.5, -267.50)
        task.wait(1.2)

        NetBridge.auraAction("open")
        task.wait(0.3)
        NetBridge.auraAction("buy", bestAffordable)
        task.wait(0.4)
        NetBridge.auraAction("equip", bestAffordable)
        task.wait(0.4)

        -- Возвращаемся на тренажер
        if stand and stand.PrimaryPart then
            hrp.CFrame = stand.PrimaryPart.CFrame * CFrame.new(0, 3, 0)
            task.wait(0.4)
            NetBridge.machineMount()
        end
    elseif bestOwned and bestOwned ~= equipped then
        NetBridge.auraAction("equip", bestOwned)
    end
end

-- Функция обновления меток статистики в UI
local function updateStatsUI()
    pcall(function()
        local stats = NetBridge.stats()
        local loadout = NetBridge.loadout()
        local pen = NetBridge.pen()
        local aura = NetBridge.state.aura
        local penInstance = getMyPen()

        if stats then
            lblGrip:UpdateName("Хватка (Grip): " .. Format.abbreviate(stats.grip or 0))
            lblDollars:UpdateName("Баланс: " .. Format.money(stats.dollars or 0))
        end

        if pen then
            lblIncome:UpdateName("Доход загона: " .. Format.money(pen.income or 0) .. " / сек")
        end

        if aura and aura.equipped then
            local auraData = Training.Auras[aura.equipped]
            local mult = auraData and auraData.gripMult or 1
            lblAura:UpdateName("Аура: " .. tostring(aura.equipped):upper() .. " (хватка x" .. tostring(mult) .. ")")
        end

        if loadout then
            local tier = loadout.tier or 1
            local tierData = Gear.Tiers[tier]
            local tierName = tierData and tierData.name or ("Tier " .. tostring(tier))
            lblMachine:UpdateName("Тренажер: " .. tierName)

            local nextTier = tier + 1
            local nextTierData = Gear.Tiers[nextTier]
            if nextTierData then
                lblNextMachCost:UpdateName("След. тренажер: " .. Format.money(nextTierData.price))
            else
                lblNextMachCost:UpdateName("След. тренажер: МАКСИМУМ")
            end
        end

        if penInstance then
            local lvl = penInstance:GetAttribute("Level") or 1
            local price = penInstance:GetAttribute("Price") or 0
            local cap = (pen and pen.capacity) or "?"
            lblPen:UpdateName("Уровень загона: " .. tostring(lvl) .. " (мест: " .. tostring(cap) .. ")")
            lblNextPenCost:UpdateName("След. апгрейд загона: " .. (price > 0 and Format.money(price) or "МАКСИМУМ"))
        end
    end)
end

-- Защита от вылета (Anti-AFK)
local afkConn = LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK then
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end
end)

-- Регистрация очистки при перезагрузке live-reload
if typeof(STATE) == "table" and STATE.onCleanup then
    STATE.onCleanup(function()
        BotState.Running = false
        if afkConn then
            afkConn:Disconnect()
        end
    end)
end

Window.onUnloaded(function()
    BotState.Running = false
    if afkConn then
        afkConn:Disconnect()
    end
end)

tabs.Main:Select()

-- Основной цикл автофарма
task.spawn(function()
    print("[Ride A Dino Autofarm] Бот успешно запущен!")
    Window:Notify({
        Title = "Ride A Dino! 🦕",
        Description = "Автофарм запущен! Нажмите RightControl чтобы скрыть/показать меню.",
        Lifetime = 5
    })

    -- Первая проверка посадки на тренажер
    if Config.AutoTrain and not isPlayerOnMachine() then
        teleportToStandAndMount()
    end

    while BotState.Running do
        local now = os.clock()

        -- Проверка статуса тренажера и удержание персонажа
        if Config.AutoTrain and (now - BotState.LastCheck >= Config.CheckInterval) then
            BotState.LastCheck = now

            if not isPlayerOnMachine() then
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    teleportToStandAndMount()
                end
            end

            -- Авто-прокачка загона (Pen Upgrade)
            if Config.AutoPen then
                local pen, plotNum = getMyPen()
                local stats = NetBridge.stats()
                if pen and stats then
                    local lvl = pen:GetAttribute("Level") or 1
                    local price = pen:GetAttribute("Price") or 0
                    if price > 0 and stats.dollars >= price then
                        NetBridge.penUpgrade(plotNum, lvl, false)
                        Window:Notify({
                            Title = "Прокачка загона",
                            Description = "Загон прокачан до уровня " .. tostring(lvl + 1) .. "! Доход вырос.",
                            Lifetime = 3
                        })
                    end
                end
            end

            -- Авто-покупка тиров тренажера (Next Machine Tier)
            if Config.AutoMachine then
                local loadout = NetBridge.loadout()
                local stats = NetBridge.stats()
                local currentTier = loadout and loadout.tier or 1
                local nextTier = currentTier + 1
                local tierConfig = Gear.Tiers[nextTier]
                if tierConfig and stats and stats.dollars >= tierConfig.price then
                    NetBridge.buy(nextTier)
                    Window:Notify({
                        Title = "Новый тренажер!",
                        Description = "Приобретен: " .. tierConfig.name .. " (хватка +" .. tostring(tierConfig.gripPerRep) .. "/сек)",
                        Lifetime = 4
                    })
                end
            end
        end

        -- Проверка аур (раз в 15 секунд, чтобы не прерывать тренировку слишком часто)
        if Config.AutoAura and (now - BotState.LastAuraCheck >= 15) then
            BotState.LastAuraCheck = now
            pcall(tryUpgradeAura)
        end

        -- Сбор бесплатных подарков и оффлайн наград (раз в 30 секунд)
        if Config.AutoClaim and (now - BotState.LastClaim >= 30) then
            BotState.LastClaim = now
            pcall(function()
                NetBridge.offlineClaim()
                NetBridge.giftClaim(true)
            end)
        end

        -- Обновление UI статистики
        updateStatsUI()

        task.wait(1)
    end
end)
