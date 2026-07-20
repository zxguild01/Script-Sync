--[[ 
    MUND COMMUNITY - GROW A GARDEN 2 
    VERSÃO V47 - CORRIGIDO: PROTEÇÃO SÓ ATIVA COM LIMITE + ANTI-AFK
]]

-- ==================== ANTI-AFK ====================
local function startAntiAFK()
    if _G.AntiAFKRunning then 
        print("⚠️ Anti-AFK já está rodando!")
        return 
    end
    _G.AntiAFKRunning = true
    
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local VirtualUser = game:GetService("VirtualUser")
    
    print("🔄 ANTI-AFK ATIVADO - 4 MÉTODOS DE PROTEÇÃO")
    
    -- MÉTODO 1: VirtualUser (não perde foco)
    task.spawn(function()
        while _G.AntiAFKRunning do
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
                task.wait(0.1)
                VirtualUser:ClickButton2(Vector2.new())
            end)
            task.wait(20) -- Mais frequente
        end
    end)
    
    -- MÉTODO 2: PULO AUTOMÁTICO (GARANTIDO)
    task.spawn(function()
        while _G.AntiAFKRunning do
            pcall(function()
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("Humanoid") then
                    local humanoid = char.Humanoid
                    if humanoid.Health > 0 then
                        humanoid.Jump = true
                        task.wait(0.05)
                        humanoid.Jump = false
                        task.wait(0.05)
                        humanoid.Jump = true -- Pula duas vezes seguidas
                        print("🦘 Pulou!")
                    end
                end
            end)
            task.wait(45) -- A cada 45 segundos
        end
    end)
    
    -- MÉTODO 3: Movimento (simula AFK)
    task.spawn(function()
        while _G.AntiAFKRunning do
            pcall(function()
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
                    local rootPart = char.HumanoidRootPart
                    local humanoid = char.Humanoid
                    
                    if humanoid.Health > 0 then
                        local randomDirection = Vector3.new(
                            math.random(-2, 2),
                            0,
                            math.random(-2, 2)
                        )
                        humanoid:MoveTo(rootPart.Position + randomDirection)
                        task.wait(0.3)
                        humanoid:MoveTo(rootPart.Position) -- Volta
                    end
                end
            end)
            task.wait(90) -- A cada 90 segundos
        end
    end)
    
    -- MÉTODO 4: Reconexão de virtual (Roblox)
    task.spawn(function()
        while _G.AntiAFKRunning do
            pcall(function()
                -- Simula tecla pressionada
                local ContextActionService = game:GetService("ContextActionService")
                ContextActionService:SetEmotesEnabled(true)
                ContextActionService:TriggerEmote("Wave")
                task.wait(0.5)
                ContextActionService:TriggerEmote("None")
            end)
            task.wait(120) -- A cada 2 minutos
        end
    end)
    
    print("✅ ANTI-AFK CONFIGURADO COM SUCESSO!")
end

local API_BASE_URL = "https://mundcommunity.squareweb.app/keys"
local SALES_API_URL = "https://syncapigag2.squareweb.app"
local KEY_SAVE_FILE = "MundCommunity_Key.txt"
local WEBHOOK_SAVE_FILE = "MundCommunity_Webhook.txt"
local BACKUP_ACCOUNT_SAVE_FILE = "MundCommunity_BackupAccount.txt"

-- Configurações do Sistema de Proteção
local currentSends = 0
local protectionActive = false
local isAutoSelling = false
local autoSalesLoop = nil
local watchdogLoop = nil
local globalStatusWatchdogLoop = nil
local lastActivityTime = tick()

-- Variáveis para a UI
local AutoSalesBtn = nil
local StatusLabel = nil
local WebhookInput = nil
local BackupAccountInput = nil
local MainFrame = nil
local ScreenGui = nil
local HttpService = nil

-- ==================== TEMPO DE DELAY ENTRE VENDAS ====================
local DELAY_BETWEEN_SALES = 15
local DELAY_NO_SALES = 5

-- ==================== FUNÇÃO HTTP REQUEST GLOBAL ====================

local function httpRequest(options)
    local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if req then 
        if options.Method == "DELETE" and not options.Body then
            options.Body = "{}"
        end
        return req(options) 
    else 
        error("Executor incompatível") 
    end
end

-- ==================== FUNÇÃO DE WEBHOOK ====================

local function getRobloxHeadshot(userId)
    if not userId or userId == 0 then
        return "https://www.roblox.com/headshot-thumbnail/image?userId=1&width=420&height=420&format=png"
    end
    return "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(userId) .. "&width=420&height=420&format=png"
end

local function sendWebhookLog(playerID, targetName, category, item, count, isTest, multiItems)
    local url = WebhookInput and WebhookInput.Text or ""
    if not url or url == "" or not url:find("http") then
        return false
    end

    url = string.gsub(url, "%s+", "")
    
    if not url:find("with_components=true") then
        url = url .. (url:find("?") and "&with_components=true" or "?with_components=true")
    end

    local localPlayer = game:GetService("Players").LocalPlayer
    local now = os.time()

    local avatarUserId = isTest and 1 or (playerID or 1)
    local avatarUrl = getRobloxHeadshot(avatarUserId)

    local title = isTest and "## `⚠️` Isso é uma webhook teste" or "## `✅` Item enviado com êxito!"
    local color = isTest and 0xFFFF00 or 0x00FF00

    local sectionComponents = {
        {["type"] = 10, ["content"] = title},
        {
            ["type"] = 10,
            ["content"] = "-# **Remetente (Você):** `" .. tostring(localPlayer.Name) .. " - (" .. tostring(localPlayer.UserId) .. ")`"
        }
    }

    if not isTest then
        if multiItems and #multiItems > 0 then
            local itemsString = ""
            for i, it in ipairs(multiItems) do
                itemsString = itemsString .. "`" .. tostring(it.Count) .. "x " .. tostring(it.ItemKey) .. " (" .. tostring(it.Category) .. ")`"
                if i < #multiItems then itemsString = itemsString .. " | " end
            end
            table.insert(sectionComponents, {
                ["type"] = 10,
                ["content"] = "-# **Destinatário:** `" .. tostring(targetName) .. " - (" .. tostring(playerID or 0) .. ")` | **Enviado:** " .. itemsString
            })
        else
            table.insert(sectionComponents, {
                ["type"] = 10,
                ["content"] = "-# **Destinatário:** `" .. tostring(targetName) .. " - (" .. tostring(playerID or 0) .. ")` | **Enviado:** `" .. tostring(count) .. "x " .. tostring(item) .. " (" .. tostring(category) .. ")`"
            })
        end
    end

    local section = {
        ["type"] = 9,
        ["components"] = sectionComponents
    }

    if avatarUrl then
        section["accessory"] = {
            ["type"] = 11,
            ["media"] = { ["url"] = avatarUrl }
        }
    end

    local data = {
        ["flags"] = 32768,
        ["components"] = {{
            ["type"] = 17,
            ["accent_color"] = color,
            ["components"] = {
                section,
                {["type"] = 14, ["divider"] = true, ["spacing"] = 1},
                {["type"] = 10, ["content"] = "-# Mund Community  •  <t:" .. now .. ":R>"}
            }
        }}
    }

    local success, response = pcall(function()
        return httpRequest({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
    
    if not success or not response then
        success, response = pcall(function()
            return HttpService:PostAsync(url, HttpService:JSONEncode(data))
        end)
    end
    
    return success
end

-- ==================== FUNÇÕES DE SUPORTE ====================

local function saveFile(filename, content) 
    pcall(function() 
        if writefile then 
            writefile(filename, tostring(content)) 
        end 
    end) 
end

local function loadFile(filename) 
    local content = ""; 
    pcall(function() 
        if readfile and isfile and isfile(filename) then 
            content = readfile(filename) 
        end 
    end); 
    return tostring(content) 
end

local function getCleanHWID() 
    local raw = game:GetService("RbxAnalyticsService"):GetClientId(); 
    return string.upper(string.gsub(string.gsub(raw, "{", ""), "}", "")) 
end

local HWID = getCleanHWID()

local function authenticate(key, callback)
    local url = API_BASE_URL .. "/" .. key .. "?hwid=" .. HWID
    local success, response = pcall(function() 
        return httpRequest({ 
            Url = url, 
            Method = "GET", 
            Headers = { ["X-HWID"] = HWID } 
        }) 
    end)
    
    if success and response then
        local statusCode = response.StatusCode
        local body = response.Body
        local ok, decoded = pcall(function() return HttpService:JSONDecode(body) end)
        
        if statusCode == 200 then
            if ok and decoded.hwid then
                local sHWID = string.upper(string.gsub(string.gsub(decoded.hwid, "{", ""), "}", ""))
                if sHWID ~= "" and sHWID ~= HWID then 
                    return callback(false, "KEY em outro dispositivo!") 
                end
            end
            callback(true, "Logado!")
        elseif statusCode == 403 then 
            callback(false, "KEY já vinculada!")
        elseif statusCode == 404 then 
            callback(false, "Chave inválida!")
        else 
            callback(false, "Erro: " .. statusCode) 
        end
    else 
        callback(false, "Erro de conexão") 
    end
end

local function getUserIdFromUsername(username)
    local Players = game:GetService("Players")
    local success, userId = pcall(function()
        return Players:GetUserIdFromNameAsync(username)
    end)
    if success then return userId else return nil end
end

local function getCategory(itemName)
    if not itemName then return "Outros" end
    local lowerItemName = string.lower(tostring(itemName))
    
    if string.find(lowerItemName, "sprinkler") then
        return "Sprinklers"
    end
    
    if string.find(lowerItemName, "watering can") or string.find(lowerItemName, "watering") then
        return "WateringCans"
    end
    
    local seedNames = {
        "bamboo", "rainbow", "gold", "mushroom",
        "carrot", "strawberry", "blueberry", "tulip", "tomato", "apple", "corn", 
        "cactus", "pineapple", "green bean", "banana", "grape", "coconut", 
        "mango", "dragon fruit", "acorn", "cherry", "sunflower",
        "venus fly trap", "pomegranate", "poison apple", "venom spitter", 
        "moon bloom", "ghost pepper", "hypno bloom", "sun bloom", "star fruit", 
        "mega seed", "dragon's breath",
        -- Variações e nomes alternativos
        "dragon breath", "dragonbreath", "dragon seed", "dragonfruit",
        "hypno", "bloom", "moon", "sun", "venus", "flytrap", "fly trap",
        "poison", "spitter", "ghost", "pepper", "star", "fruit", "mega seed"
    }

    for _, seedName in ipairs(seedNames) do
        if string.find(lowerItemName, seedName) then
            return "Seeds"
        end
    end
    
    return "Outros"
end

local function parseQuantityString(str)
    if type(str) == "number" then return str end
    if type(str) ~= "string" then return 0 end
    
    str = string.upper(str)
    str = string.gsub(str, "X", "")
    
    local multiplier = 1
    if string.find(str, "K") then
        multiplier = 1000
        str = string.gsub(str, "K", "")
    elseif string.find(str, "M") then
        multiplier = 1000000
        str = string.gsub(str, "M", "")
    end
    
    local num = tonumber(str)
    if num then
        return math.floor(num * multiplier)
    end
    return 0
end

-- ==================== SCANNER DE INVENTÁRIO ====================

local function getPlayerInventory()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    if not LocalPlayer or not LocalPlayer.Character then
        warn("getPlayerInventory: LocalPlayer ou Character não disponível.")
        return {}
    end

    print("--- INICIANDO SCAN DE INVENTÁRIO ---")
    local inventory = {}
    local scannedInstances = {}

    local currentTool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if currentTool then
        LocalPlayer.Character.Humanoid:UnequipTools()
        task.wait(0.1)
    end
    
    local firstToolInBackpack = LocalPlayer.Backpack:FindFirstChildOfClass("Tool")
    if firstToolInBackpack then
        LocalPlayer.Character.Humanoid:EquipTool(firstToolInBackpack)
        task.wait(0.1)
    end

    local function isValidQuantity(qty)
        if not qty or qty <= 0 then return false end
        if qty > 100000 then return false end
        return true
    end

    local function extractQuantitySafe(instance)
        if not instance then return 0 end
        
        if instance:IsA("NumberValue") or instance:IsA("IntValue") then
            local val = instance.Value
            if isValidQuantity(val) then
                return val
            end
            return 0
        end
        
        if instance:IsA("StringValue") then
            local val = parseQuantityString(instance.Value)
            if isValidQuantity(val) then
                return val
            end
            return 0
        end
        
        local attrAmount = instance:GetAttribute("Amount") or instance:GetAttribute("Count") or instance:GetAttribute("Quantity")
        if attrAmount then
            local val = parseQuantityString(tostring(attrAmount))
            if isValidQuantity(val) then
                return val
            end
        end
        
        return 0
    end

    local function scanRecursive(instance, depth)
        if not instance or table.find(scannedInstances, instance) or depth > 5 then return end
        table.insert(scannedInstances, instance)

        for _, child in ipairs(instance:GetChildren()) do
            local itemName = child.Name
            local quantity = 0

            quantity = extractQuantitySafe(child)

            if child:IsA("Tool") then
                local hasValidQuantity = false
                for _, toolChild in ipairs(child:GetChildren()) do
                    local qty = extractQuantitySafe(toolChild)
                    if qty > 0 then
                        quantity = qty
                        hasValidQuantity = true
                        break
                    end
                end
                if not hasValidQuantity and quantity == 0 then
                    quantity = 1
                end
            end

            local category = getCategory(itemName)
            if (category == "Seeds" or category == "Sprinklers" or category == "WateringCans") and quantity > 0 and isValidQuantity(quantity) then
                inventory[itemName] = (inventory[itemName] or 0) + quantity
            end

            if child:IsA("Folder") or child:IsA("Configuration") or child:IsA("Model") or child:IsA("Tool") or child:IsA("Player") then
                scanRecursive(child, depth + 1)
            end
        end
    end

    scanRecursive(LocalPlayer, 0)
    if LocalPlayer.Backpack then scanRecursive(LocalPlayer.Backpack, 0) end
    if LocalPlayer.StarterGear then scanRecursive(LocalPlayer.StarterGear, 0) end
    
    print("--- FIM DO SCAN DE INVENTÁRIO ---")
    return inventory
end

-- ==================== FUNÇÕES DE RESET NA API ====================

local function resetFullOnAPI(userId)
    if not userId or userId == "" then
        return false
    end
    
    local success, response = pcall(function()
        return httpRequest({
            Url = SALES_API_URL .. "/sales/reset-full",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ userId = tostring(userId) }),
            Timeout = 10
        })
    end)
    
    if success and response and response.StatusCode == 200 then
        return true
    else
        return false
    end
end

-- ==================== FUNÇÃO DE ENVIO DE ITENS ====================

local function sendItemsToBackup(backupUserId, itemsToSend, message)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Networking = require(ReplicatedStorage.SharedModules.Networking)
    
    if not Networking or not Networking.Mailbox or not Networking.Mailbox.SendBatch then
        return false, "Networking.Mailbox.SendBatch não encontrado"
    end
    
    if not backupUserId or backupUserId == 0 then
        return false, "UserId inválido"
    end
    
    if not itemsToSend or #itemsToSend == 0 then
        return false, "Nenhum item para enviar"
    end
    
    local formattedItems = {}
    for _, item in ipairs(itemsToSend) do
        local itemKey = item.ItemKey or item.name
        local count = item.Count or item.count or 1
        local category = item.Category or getCategory(itemKey)
        
        if string.find(string.lower(tostring(itemKey)), "super sprinkler") then
            itemKey = "Super Sprinkler"
            category = "Sprinklers"
        elseif string.find(string.lower(tostring(itemKey)), "super watering can") then
            itemKey = "Super Watering Can"
            category = "WateringCans"
        end
        
        table.insert(formattedItems, {
            Category = category,
            ItemKey = itemKey,
            Count = count
        })
    end
    
    local success, result = pcall(function()
        if typeof(Networking.Mailbox.SendBatch) == "function" then
            return Networking.Mailbox.SendBatch(backupUserId, formattedItems, message or "Transferência de Segurança")
        elseif typeof(Networking.Mailbox.SendBatch) == "table" and Networking.Mailbox.SendBatch.Fire then
            return Networking.Mailbox.SendBatch:Fire(backupUserId, formattedItems, message or "Transferência de Segurança")
        else
            error("Networking.Mailbox.SendBatch não é uma função ou RemoteEvent/RemoteFunction reconhecido.")
        end
    end)
    
    if success then
        return true, "Itens enviados com sucesso"
    else
        return false, tostring(result)
    end
end

-- ==================== SISTEMA DE PROTEÇÃO ====================

local function initiateBackupTransfer(reason)
    if protectionActive then return end
    protectionActive = true

    if isAutoSelling then
        isAutoSelling = false
        autoSalesLoop = nil
    end
    
    watchdogLoop = nil
    globalStatusWatchdogLoop = nil

    if AutoSalesBtn and AutoSalesBtn.Parent then
        AutoSalesBtn:Destroy()
    end

    task.spawn(function()
        if StatusLabel then
            StatusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
            StatusLabel.Text = "🛡️ PROTEÇÃO ATIVADA! Motivo: " .. tostring(reason or "Desconhecido")
        end

        print("🛡️ PROTEÇÃO ATIVADA! Motivo: " .. tostring(reason or "Desconhecido"))

        print("PASSO 1.5: AGUARDANDO 15 SEGUNDOS PARA SINCRONIA DO JOGO...")
        for i = 15, 1, -1 do
            if StatusLabel then
                StatusLabel.Text = "Aguardando sincronia do jogo... (" .. i .. "s)"
            end
            task.wait(1)
        end
        
        if StatusLabel then
            StatusLabel.Text = "Sincronia concluída. Escaneando inventário..."
        end

        local myInventory = getPlayerInventory()
        
        local itemsToSend = {}
        for itemKey, count in pairs(myInventory) do
            local category = getCategory(itemKey)
            if (category == "Seeds" or category == "Sprinklers" or category == "WateringCans") and count > 0 then
                table.insert(itemsToSend, {["Category"] = category, ["ItemKey"] = itemKey, ["Count"] = count})
            end
        end

        local backupUsername = BackupAccountInput and BackupAccountInput.Text or ""
        if not backupUsername or backupUsername == "" then
            if StatusLabel then
                StatusLabel.Text = "ERRO: Nickname de backup não configurado!"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
            return
        end

        local backupUserId = getUserIdFromUsername(backupUsername)
        if not backupUserId then
            if StatusLabel then
                StatusLabel.Text = "ERRO: Nickname de backup inválido!"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
            return
        end

        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        local currentUserId = tostring(LocalPlayer.UserId)

        if #itemsToSend > 0 then
            local transferSuccess = false
            local attempts = 0
            local MAX_TRANSFER_ATTEMPTS = 3

            while not transferSuccess and attempts < MAX_TRANSFER_ATTEMPTS do
                attempts = attempts + 1
                if StatusLabel then
                    StatusLabel.Text = "Tentando transferir estoque... (Tentativa " .. attempts .. "/" .. MAX_TRANSFER_ATTEMPTS .. ")"
                end
                local success, result = sendItemsToBackup(backupUserId, itemsToSend, "Transferência de Segurança")
                
                if success then
                    transferSuccess = true
                    resetFullOnAPI(currentUserId)
                    currentSends = 0
                    sendWebhookLog(backupUserId, backupUsername, "Backup", "Itens transferidos", #itemsToSend, false, itemsToSend)
                else
                    task.wait(2)
                end
            end
        else
            resetFullOnAPI(currentUserId)
        end
        
        task.wait(1)
        if StatusLabel then
            StatusLabel.Text = "✅ Proteção ativada! Limite resetado. Entre em " .. tostring(backupUsername) .. " para continuar."
            StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        end
        currentSends = 0
    end)
end

-- ==================== FUNÇÃO DE ENVIO DE VENDA ====================

local function sendSaleItems(userId, itemsToSend, message)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Networking = require(ReplicatedStorage.SharedModules.Networking)
    
    if not Networking or not Networking.Mailbox or not Networking.Mailbox.SendBatch then
        return false, "Networking.Mailbox.SendBatch não encontrado"
    end
    
    local success, result = pcall(function()
        if typeof(Networking.Mailbox.SendBatch) == "function" then
            return Networking.Mailbox.SendBatch(userId, itemsToSend, message or "Mund Sales :)")
        elseif typeof(Networking.Mailbox.SendBatch) == "table" and Networking.Mailbox.SendBatch.Fire then
            return Networking.Mailbox.SendBatch:Fire(userId, itemsToSend, message or "Mund Sales :)")
        else
            error("Networking.Mailbox.SendBatch não é uma função ou RemoteEvent/RemoteFunction reconhecido.")
        end
    end)
    
    if success then
        return true, "Itens enviados com sucesso"
    else
        return false, tostring(result)
    end
end

-- ==================== PAINEL PRINCIPAL - UI CORRIGIDA ====================

local function abrirPainelPrincipal()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    HttpService = game:GetService("HttpService")
    
    local Networking = require(ReplicatedStorage.SharedModules.Networking)

    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "MundMain"
    ScreenGui.Parent = game:GetService("CoreGui")
    ScreenGui.ResetOnSpawn = false

    -- Frame Principal
    MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainFrame.Position = UDim2.new(0.5, -225, 0.5, -230)
    MainFrame.Size = UDim2.new(0, 450, 0, 480)
    MainFrame.Active = true
    MainFrame.Draggable = true
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.Parent = MainFrame
    MainCorner.CornerRadius = UDim.new(0, 8)
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Parent = MainFrame
    MainStroke.Color = Color3.fromRGB(255, 0, 0)
    MainStroke.Thickness = 2

    -- Header
    local HeaderFrame = Instance.new("Frame")
    HeaderFrame.Name = "HeaderFrame"
    HeaderFrame.Parent = MainFrame
    HeaderFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    HeaderFrame.Size = UDim2.new(1, 0, 0, 50)
    HeaderFrame.Position = UDim2.new(0, 0, 0, 0)
    
    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.Parent = HeaderFrame
    HeaderCorner.CornerRadius = UDim.new(0, 8)
    
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Parent = HeaderFrame
    Title.BackgroundTransparency = 1
    Title.Size = UDim2.new(0.7, 0, 1, 0)
    Title.Position = UDim2.new(0.05, 0, 0, 0)
    Title.Font = Enum.Font.GothamBold
    Title.Text = "MUND COMMUNITY"
    Title.TextColor3 = Color3.fromRGB(255, 0, 0)
    Title.TextSize = 18
    Title.TextXAlignment = Enum.TextXAlignment.Left
    
    local SubTitle = Instance.new("TextLabel")
    SubTitle.Name = "SubTitle"
    SubTitle.Parent = HeaderFrame
    SubTitle.BackgroundTransparency = 1
    SubTitle.Size = UDim2.new(0.5, 0, 0.5, 0)
    SubTitle.Position = UDim2.new(0.05, 0, 0.5, 0)
    SubTitle.Font = Enum.Font.Gotham
    SubTitle.Text = "Sistema de Vendas Automáticas"
    SubTitle.TextColor3 = Color3.fromRGB(150, 150, 150)
    SubTitle.TextSize = 11
    SubTitle.TextXAlignment = Enum.TextXAlignment.Left

    -- Botão Fechar
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
    CloseBtn.Parent = HeaderFrame
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 20, 20)
    CloseBtn.Position = UDim2.new(0.92, 0, 0.1, 0)
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize = 14
    CloseBtn.TextScaled = false
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.Parent = CloseBtn
    CloseCorner.CornerRadius = UDim.new(0, 4)
    CloseBtn.MouseButton1Click:Connect(function() 
        if ScreenGui then ScreenGui:Destroy() end
    end)

    -- Corpo
    local BodyFrame = Instance.new("Frame")
    BodyFrame.Name = "BodyFrame"
    BodyFrame.Parent = MainFrame
    BodyFrame.BackgroundTransparency = 1
    BodyFrame.Size = UDim2.new(1, -20, 1, -70)
    BodyFrame.Position = UDim2.new(0, 10, 0, 60)

    -- CONTA DE BACKUP
    local BackupLabel = Instance.new("TextLabel")
    BackupLabel.Parent = BodyFrame
    BackupLabel.BackgroundTransparency = 1
    BackupLabel.Size = UDim2.new(1, 0, 0, 20)
    BackupLabel.Position = UDim2.new(0, 0, 0, 0)
    BackupLabel.Font = Enum.Font.GothamBold
    BackupLabel.Text = "CONTA DE BACKUP"
    BackupLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    BackupLabel.TextSize = 11
    BackupLabel.TextXAlignment = Enum.TextXAlignment.Left

    BackupAccountInput = Instance.new("TextBox")
    BackupAccountInput.Name = "BackupAccountInput"
    BackupAccountInput.Parent = BodyFrame
    BackupAccountInput.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    BackupAccountInput.Size = UDim2.new(1, 0, 0, 35)
    BackupAccountInput.Position = UDim2.new(0, 0, 0, 22)
    BackupAccountInput.Font = Enum.Font.Gotham
    BackupAccountInput.PlaceholderText = "Digite o nickname da conta de backup"
    BackupAccountInput.Text = loadFile(BACKUP_ACCOUNT_SAVE_FILE)
    BackupAccountInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    BackupAccountInput.TextSize = 12
    local BackupCorner = Instance.new("UICorner")
    BackupCorner.Parent = BackupAccountInput
    BackupCorner.CornerRadius = UDim.new(0, 4)
    BackupAccountInput.FocusLost:Connect(function() 
        saveFile(BACKUP_ACCOUNT_SAVE_FILE, BackupAccountInput.Text) 
    end)

    -- WEBHOOK
    local WebhookLabel = Instance.new("TextLabel")
    WebhookLabel.Parent = BodyFrame
    WebhookLabel.BackgroundTransparency = 1
    WebhookLabel.Size = UDim2.new(1, 0, 0, 20)
    WebhookLabel.Position = UDim2.new(0, 0, 0, 65)
    WebhookLabel.Font = Enum.Font.GothamBold
    WebhookLabel.Text = "DISCORD WEBHOOK"
    WebhookLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    WebhookLabel.TextSize = 11
    WebhookLabel.TextXAlignment = Enum.TextXAlignment.Left

    local WebhookRow = Instance.new("Frame")
    WebhookRow.Name = "WebhookRow"
    WebhookRow.Parent = BodyFrame
    WebhookRow.BackgroundTransparency = 1
    WebhookRow.Size = UDim2.new(1, 0, 0, 35)
    WebhookRow.Position = UDim2.new(0, 0, 0, 87)

    WebhookInput = Instance.new("TextBox")
    WebhookInput.Name = "WebhookInput"
    WebhookInput.Parent = WebhookRow
    WebhookInput.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    WebhookInput.Size = UDim2.new(0.68, -5, 1, 0)
    WebhookInput.Position = UDim2.new(0, 0, 0, 0)
    WebhookInput.Font = Enum.Font.Gotham
    WebhookInput.PlaceholderText = "URL do Discord Webhook"
    WebhookInput.Text = loadFile(WEBHOOK_SAVE_FILE)
    WebhookInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    WebhookInput.TextSize = 10
    WebhookInput.TextWrapped = false
    WebhookInput.ClipsDescendants = true
    local WebhookCorner = Instance.new("UICorner")
    WebhookCorner.Parent = WebhookInput
    WebhookCorner.CornerRadius = UDim.new(0, 4)
    WebhookInput.FocusLost:Connect(function() 
        local cleaned = string.gsub(WebhookInput.Text, "%s+", "")
        WebhookInput.Text = cleaned
        saveFile(WEBHOOK_SAVE_FILE, cleaned) 
    end)

    -- Botão Testar Webhook
    local TestWebhookBtn = Instance.new("TextButton")
    TestWebhookBtn.Name = "TestWebhookBtn"
    TestWebhookBtn.Parent = WebhookRow
    TestWebhookBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    TestWebhookBtn.Size = UDim2.new(0.30, 0, 1, 0)
    TestWebhookBtn.Position = UDim2.new(0.70, 0, 0, 0)
    TestWebhookBtn.Font = Enum.Font.GothamBold
    TestWebhookBtn.Text = "TESTAR"
    TestWebhookBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TestWebhookBtn.TextSize = 11
    local TestCorner = Instance.new("UICorner")
    TestCorner.Parent = TestWebhookBtn
    TestCorner.CornerRadius = UDim.new(0, 4)
    TestWebhookBtn.MouseButton1Click:Connect(function()
        if WebhookInput.Text and WebhookInput.Text ~= "" then
            local success = sendWebhookLog(1, "Teste", "Teste", "Webhook", 1, true)
            if success then
                StatusLabel.Text = "📨 Webhook de teste enviado com sucesso!"
                StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            else
                StatusLabel.Text = "❌ Falha ao enviar webhook. Verifique a URL!"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
        else
            StatusLabel.Text = "⚠️ Configure a URL do Webhook primeiro!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        end
    end)

    -- Botão Automatizar Venda
    AutoSalesBtn = Instance.new("TextButton")
    AutoSalesBtn.Name = "AutoSalesBtn"
    AutoSalesBtn.Parent = BodyFrame
    AutoSalesBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    AutoSalesBtn.Size = UDim2.new(1, 0, 0, 45)
    AutoSalesBtn.Position = UDim2.new(0, 0, 0, 135)
    AutoSalesBtn.Font = Enum.Font.GothamBold
    AutoSalesBtn.Text = "▶  INICIAR VENDAS AUTOMÁTICAS"
    AutoSalesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    AutoSalesBtn.TextSize = 13
    local SalesCorner = Instance.new("UICorner")
    SalesCorner.Parent = AutoSalesBtn
    SalesCorner.CornerRadius = UDim.new(0, 6)

    -- Botões Secundários
    local ButtonRow = Instance.new("Frame")
    ButtonRow.Name = "ButtonRow"
    ButtonRow.Parent = BodyFrame
    ButtonRow.BackgroundTransparency = 1
    ButtonRow.Size = UDim2.new(1, 0, 0, 40)
    ButtonRow.Position = UDim2.new(0, 0, 0, 190)

    local ForceBackupBtn = Instance.new("TextButton")
    ForceBackupBtn.Name = "ForceBackupBtn"
    ForceBackupBtn.Parent = ButtonRow
    ForceBackupBtn.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
    ForceBackupBtn.Size = UDim2.new(0.48, -5, 1, 0)
    ForceBackupBtn.Position = UDim2.new(0, 0, 0, 0)
    ForceBackupBtn.Font = Enum.Font.GothamBold
    ForceBackupBtn.Text = "🛡️ BACKUP AGORA"
    ForceBackupBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ForceBackupBtn.TextSize = 11
    local ForceCorner = Instance.new("UICorner")
    ForceCorner.Parent = ForceBackupBtn
    ForceCorner.CornerRadius = UDim.new(0, 4)
    ForceBackupBtn.MouseButton1Click:Connect(function()
        if not protectionActive then
            initiateBackupTransfer("Manual")
            StatusLabel.Text = "🔄 Backup manual iniciado!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
        else
            StatusLabel.Text = "⚠️ Proteção já está ativa!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        end
    end)

    local DebugInvBtn = Instance.new("TextButton")
    DebugInvBtn.Name = "DebugInvBtn"
    DebugInvBtn.Parent = ButtonRow
    DebugInvBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    DebugInvBtn.Size = UDim2.new(0.48, -5, 1, 0)
    DebugInvBtn.Position = UDim2.new(0.52, 0, 0, 0)
    DebugInvBtn.Font = Enum.Font.GothamBold
    DebugInvBtn.Text = "🔍 DEBUG INV"
    DebugInvBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    DebugInvBtn.TextSize = 11
    local DebugCorner = Instance.new("UICorner")
    DebugCorner.Parent = DebugInvBtn
    DebugCorner.CornerRadius = UDim.new(0, 4)
    DebugInvBtn.MouseButton1Click:Connect(function()
        print("---- DEBUG DE INVENTÁRIO ----")
        local debugInventory = getPlayerInventory()
        if next(debugInventory) == nil then
            print("Nenhum item elegível encontrado.")
        else
            for itemKey, count in pairs(debugInventory) do
                print("Item: " .. tostring(itemKey) .. ", Quantidade: " .. tostring(count))
            end
        end
        print("---- FIM DO DEBUG ----")
        StatusLabel.Text = "📊 Debug no console (F9)!"
        StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
    end)

    -- Status
    StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Parent = BodyFrame
    StatusLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    StatusLabel.Size = UDim2.new(1, 0, 0, 40)
    StatusLabel.Position = UDim2.new(0, 0, 0, 240)
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.Text = "🟢 Sistema pronto para iniciar (Delay: 15s entre vendas)"
    StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    StatusLabel.TextSize = 11
    StatusLabel.TextWrapped = true
    local StatusCorner = Instance.new("UICorner")
    StatusCorner.Parent = StatusLabel
    StatusCorner.CornerRadius = UDim.new(0, 4)

    -- Footer
    local FooterLabel = Instance.new("TextLabel")
    FooterLabel.Parent = MainFrame
    FooterLabel.BackgroundTransparency = 1
    FooterLabel.Size = UDim2.new(1, 0, 0, 20)
    FooterLabel.Position = UDim2.new(0, 0, 0, 460)
    FooterLabel.Font = Enum.Font.Gotham
    FooterLabel.Text = "Mund Community © 2024 - V47 | Delay: 15s"
    FooterLabel.TextColor3 = Color3.fromRGB(80, 80, 80)
    FooterLabel.TextSize = 9
    FooterLabel.TextXAlignment = Enum.TextXAlignment.Center

    -- ==================== LÓGICA DO BOTÃO AUTOSALES (CORRIGIDA) ====================
    
    AutoSalesBtn.MouseButton1Click:Connect(function()
        if protectionActive then
            StatusLabel.Text = "⚠️ Sistema de proteção já ativo!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            return
        end

        if isAutoSelling then
            isAutoSelling = false
            AutoSalesBtn.Text = "▶  INICIAR VENDAS AUTOMÁTICAS"
            AutoSalesBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            StatusLabel.Text = "⏹️ Vendas automáticas paradas"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
            autoSalesLoop = nil
            return
        end

        local backupUsername = BackupAccountInput.Text
        if not backupUsername or backupUsername == "" then
            StatusLabel.Text = "⚠️ Configure a conta de backup primeiro!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            return
        end

        StatusLabel.Text = "🔍 Verificando conta de backup..."
        local backupUserId = getUserIdFromUsername(backupUsername)
        if not backupUserId then
            StatusLabel.Text = "❌ Conta de backup não encontrada!"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            return
        end

        isAutoSelling = true
        AutoSalesBtn.Text = "⏹  PARAR VENDAS"
        AutoSalesBtn.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
        StatusLabel.Text = "🟢 Vendas automáticas iniciadas (Delay: 15s)"
        StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        lastActivityTime = tick()

        autoSalesLoop = task.spawn(function()
            local saleCounter = 0
            
            while isAutoSelling and not protectionActive do
                -- ========== ANTI-IDLE DESATIVADO (removido para não ativar proteção sem motivo) ==========
                -- Removido o Anti-Idle que ativava proteção após 30 segundos
                
                StatusLabel.Text = "🔍 Buscando próxima venda..."
                local success, response = pcall(function()
                    return httpRequest({ 
                        Url = SALES_API_URL .. "/sales/next?userId=" .. tostring(LocalPlayer.UserId),
                        Method = "GET", 
                        Headers = { ["Content-Type"] = "application/json" }, 
                        Timeout = 10 
                    })
                end)

                if success and response then
                    local statusCode = response.StatusCode
                    local body = response.Body
                    local ok, decoded = pcall(function() return HttpService:JSONDecode(body) end)

                    if statusCode == 200 and ok then
                        -- ========== SÓ ATIVA PROTEÇÃO SE A API MANDAR ==========
                        if decoded.action == "activate_protection" then
                            -- VERIFICA SE REALMENTE BATEU O LIMITE
                            if decoded.dailySends and decoded.MAX_DAILY_SENDS then
                                if decoded.dailySends >= decoded.MAX_DAILY_SENDS then
                                    StatusLabel.Text = "🛡️ Limite diário atingido! (" .. decoded.dailySends .. "/" .. decoded.MAX_DAILY_SENDS .. ")"
                                    StatusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
                                    initiateBackupTransfer("Limite da API (" .. decoded.dailySends .. "/" .. decoded.MAX_DAILY_SENDS .. ")")
                                    break
                                else
                                    -- API mandou ativar mas não bateu limite (erro da API)
                                    warn("⚠️ API pediu proteção mas limite não foi atingido. Ignorando...")
                                    StatusLabel.Text = "⚠️ API pediu proteção mas limite não foi atingido. Continuando..."
                                    StatusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
                                    task.wait(2)
                                    -- NÃO ATIVA PROTEÇÃO! Continua o loop
                                end
                            else
                                -- API mandou ativar mas não enviou os dados de limite (erro)
                                warn("⚠️ API pediu proteção mas não enviou dados de limite. Ignorando...")
                                task.wait(2)
                                -- NÃO ATIVA PROTEÇÃO! Continua o loop
                            end
                        else
                            local sale = decoded
                            saleCounter = saleCounter + 1
                            StatusLabel.Text = "📦 Processando venda #" .. saleCounter .. " para " .. tostring(sale.username) .. "..."

                            local itemsToSend = {}
                            
                            if string.lower(tostring(sale.item)) == "super sprinkler and watering can" then
                                table.insert(itemsToSend, {["Category"] = "Sprinklers", ["ItemKey"] = "Super Sprinkler", ["Count"] = sale.count})
                                table.insert(itemsToSend, {["Category"] = "WateringCans", ["ItemKey"] = "Super Watering Can", ["Count"] = sale.count})
                            else
                                local itemCategory = getCategory(sale.item)
                                table.insert(itemsToSend, {["Category"] = itemCategory, ["ItemKey"] = sale.item, ["Count"] = sale.count})
                            end

                            -- Deleta da API
                            pcall(function()
                                return httpRequest({ 
                                    Url = SALES_API_URL .. "/sales/" .. tostring(sale.id) .. "?userId=" .. tostring(LocalPlayer.UserId),
                                    Method = "DELETE", 
                                    Headers = { ["Content-Type"] = "application/json" }, 
                                    Timeout = 10 
                                })
                            end)

                            -- ENVIA OS ITENS
                            local sendSuccess, sendResult = sendSaleItems(sale.userId, itemsToSend, "Mund Sales :)")

                            if sendSuccess then
                                currentSends = currentSends + 1
                                lastActivityTime = tick()

                                sendWebhookLog(sale.userId, sale.username, getCategory(sale.item), sale.item, sale.count, false, itemsToSend)
                                
                                -- Delay de 15 segundos com contagem regressiva
                                StatusLabel.Text = "✅ Venda #" .. saleCounter .. " concluída! Aguardando " .. DELAY_BETWEEN_SALES .. "s..."
                                StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                                
                                for i = DELAY_BETWEEN_SALES, 1, -1 do
                                    if not isAutoSelling or protectionActive then break end
                                    StatusLabel.Text = "⏳ Próxima venda em " .. i .. "s... (Venda #" .. saleCounter .. " concluída)"
                                    task.wait(1)
                                end
                            else
                                StatusLabel.Text = "❌ Erro no envio! Ativando proteção..."
                                StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
                                initiateBackupTransfer("Erro no envio: " .. tostring(sendResult))
                                break
                            end
                        end
                    elseif statusCode == 204 then
                        StatusLabel.Text = "⏳ Nenhuma venda pendente..."
                        task.wait(DELAY_NO_SALES)
                    else
                        StatusLabel.Text = "⚠️ Erro na API: " .. tostring(statusCode)
                        StatusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
                        task.wait(DELAY_NO_SALES)
                    end
                else
                    StatusLabel.Text = "⚠️ Erro de conexão com a API!"
                    StatusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
                    task.wait(DELAY_NO_SALES)
                end
            end
        end)
    end)

    -- ========== WATCHDOG DE STATUS GLOBAL CORRIGIDO ==========
    globalStatusWatchdogLoop = task.spawn(function()
        while not protectionActive do
            task.wait(5) -- Aumentado para 5 segundos (menos requisições)
            local success, response = pcall(function()
                return httpRequest({ 
                    Url = SALES_API_URL .. "/sales/status?userId=" .. tostring(LocalPlayer.UserId),
                    Method = "GET", 
                    Headers = { ["Content-Type"] = "application/json" }, 
                    Timeout = 5 
                })
            end)

            if success and response and response.StatusCode == 200 then
                local ok, decoded = pcall(function() return HttpService:JSONDecode(response.Body) end)
                if ok and decoded.protectionNeeded then
                    -- VERIFICA SE REALMENTE BATEU O LIMITE
                    if decoded.dailySends and decoded.MAX_DAILY_SENDS then
                        if decoded.dailySends >= decoded.MAX_DAILY_SENDS then
                            StatusLabel.Text = "🛡️ API: Limite atingido! (" .. decoded.dailySends .. "/" .. decoded.MAX_DAILY_SENDS .. ")"
                            StatusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
                            initiateBackupTransfer("Limite da API (Watchdog: " .. decoded.dailySends .. "/" .. decoded.MAX_DAILY_SENDS .. ")")
                            break
                        else
                            -- API diz que precisa de proteção mas limite NÃO foi atingido (erro)
                            warn("⚠️ Watchdog: API pediu proteção mas limite não foi atingido. Ignorando...")
                        end
                    else
                        warn("⚠️ Watchdog: API pediu proteção mas não enviou dados de limite. Ignorando...")
                    end
                end
            end
        end
    end)

    -- ========== WATCHDOG DE UI CORRIGIDO ==========
    watchdogLoop = task.spawn(function()
        while not protectionActive do
            task.wait(0.5)
            local foundLimit = false
            for _, child in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
                if child:IsA("TextLabel") or child:IsA("TextButton") then
                    local text = string.lower(child.Text or "")
                    if string.find(text, "limite de correio") or string.find(text, "mail limit") or string.find(text, "too many mails") then
                        foundLimit = true
                        break
                    end
                end
            end
            if foundLimit then
                StatusLabel.Text = "🛡️ Limite de correio detectado!"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
                initiateBackupTransfer("Limite de Correio (UI)")
                break
            end
        end
    end)
end

-- ==================== TELA DE LOGIN ====================

local function showLogin()
    HttpService = game:GetService("HttpService")
    
    local LoginScreenGui = Instance.new("ScreenGui")
    LoginScreenGui.Name = "MundLogin"
    LoginScreenGui.Parent = game:GetService("CoreGui")
    LoginScreenGui.ResetOnSpawn = false

    local LoginFrame = Instance.new("Frame")
    LoginFrame.Name = "LoginFrame"
    LoginFrame.Parent = LoginScreenGui
    LoginFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    LoginFrame.Position = UDim2.new(0.5, -150, 0.5, -120)
    LoginFrame.Size = UDim2.new(0, 300, 0, 240)
    LoginFrame.Active = true
    LoginFrame.Draggable = true
    local LoginCorner = Instance.new("UICorner")
    LoginCorner.Parent = LoginFrame
    LoginCorner.CornerRadius = UDim.new(0, 8)
    local LoginStroke = Instance.new("UIStroke")
    LoginStroke.Parent = LoginFrame
    LoginStroke.Color = Color3.fromRGB(255, 0, 0)
    LoginStroke.Thickness = 2

    local LoginTitle = Instance.new("TextLabel")
    LoginTitle.Parent = LoginFrame
    LoginTitle.BackgroundTransparency = 1
    LoginTitle.Size = UDim2.new(1, 0, 0, 50)
    LoginTitle.Font = Enum.Font.GothamBold
    LoginTitle.Text = "MUND COMMUNITY"
    LoginTitle.TextColor3 = Color3.fromRGB(255, 0, 0)
    LoginTitle.TextSize = 20

    local SubLoginTitle = Instance.new("TextLabel")
    SubLoginTitle.Parent = LoginFrame
    SubLoginTitle.BackgroundTransparency = 1
    SubLoginTitle.Size = UDim2.new(1, 0, 0, 20)
    SubLoginTitle.Position = UDim2.new(0, 0, 0, 35)
    SubLoginTitle.Font = Enum.Font.Gotham
    SubLoginTitle.Text = "Sistema de Vendas Automáticas"
    SubLoginTitle.TextColor3 = Color3.fromRGB(150, 150, 150)
    SubLoginTitle.TextSize = 11

    local KeyInput = Instance.new("TextBox")
    KeyInput.Name = "KeyInput"
    KeyInput.Parent = LoginFrame
    KeyInput.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    KeyInput.Position = UDim2.new(0.1, 0, 0.35, 0)
    KeyInput.Size = UDim2.new(0.8, 0, 0, 40)
    KeyInput.Font = Enum.Font.Gotham
    KeyInput.PlaceholderText = "Digite sua chave de acesso"
    KeyInput.Text = loadFile(KEY_SAVE_FILE)
    KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    KeyInput.TextSize = 12
    local KeyCorner = Instance.new("UICorner")
    KeyCorner.Parent = KeyInput
    KeyCorner.CornerRadius = UDim.new(0, 4)

    local LoginBtn = Instance.new("TextButton")
    LoginBtn.Name = "LoginBtn"
    LoginBtn.Parent = LoginFrame
    LoginBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    LoginBtn.Position = UDim2.new(0.1, 0, 0.55, 0)
    LoginBtn.Size = UDim2.new(0.8, 0, 0, 45)
    LoginBtn.Font = Enum.Font.GothamBold
    LoginBtn.Text = "ENTRAR"
    LoginBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    LoginBtn.TextSize = 14
    local LoginBtnCorner = Instance.new("UICorner")
    LoginBtnCorner.Parent = LoginBtn
    LoginBtnCorner.CornerRadius = UDim.new(0, 6)

    local LoginStatus = Instance.new("TextLabel")
    LoginStatus.Name = "LoginStatus"
    LoginStatus.Parent = LoginFrame
    LoginStatus.BackgroundTransparency = 1
    LoginStatus.Position = UDim2.new(0.1, 0, 0.78, 0)
    LoginStatus.Size = UDim2.new(0.8, 0, 0, 25)
    LoginStatus.Font = Enum.Font.Gotham
    LoginStatus.Text = ""
    LoginStatus.TextColor3 = Color3.fromRGB(255, 255, 255)
    LoginStatus.TextSize = 11

    LoginBtn.MouseButton1Click:Connect(function()
        LoginStatus.Text = "🔄 Autenticando..."
        LoginStatus.TextColor3 = Color3.fromRGB(255, 255, 0)
        local key = KeyInput.Text
        
        authenticate(key, function(success, message)
            if success then
                saveFile(KEY_SAVE_FILE, key)
                LoginStatus.Text = "✅ " .. message
                LoginStatus.TextColor3 = Color3.fromRGB(0, 255, 0)
                task.wait(1)
                LoginScreenGui:Destroy()
                abrirPainelPrincipal()
            else
                LoginStatus.Text = "❌ " .. message
                LoginStatus.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
        end)
    end)
end

-- ==================== INICIALIZAÇÃO ====================
print("MUND COMMUNITY SALES BOT V47 - PROTEÇÃO CORRIGIDA + ANTI-AFK")
print("HWID: " .. HWID)
print("⏱️ Delay entre vendas: " .. DELAY_BETWEEN_SALES .. " segundos")
print("🛡️ Proteção SÓ ATIVA com limite diário REAL!")
print("🔄 Anti-AFK ativado!")

startAntiAFK() -- Inicia o Anti-AFK
showLogin()
