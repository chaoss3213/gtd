local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

pcall(function()
    RunService:Set3dRenderingEnabled(false)
end)


local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CONFIG = {
    -- "auto" | "main" | "alt"
    ROLE = "auto",

    -- Tai khoan main: alt se xoay vong gui invite qua list nay theo thu tu.
    MAIN_ACCOUNTS = {
        "GreeneAriesh01",
        "Myloji19",
        -- "main_3",
    },

    -- Tai khoan alt hop le de main chap nhan.
    -- Neu de trong, main se chap nhan bat ky ai khong nam trong MAIN_ACCOUNTS.
    ALT_ACCOUNTS = {
        -- "alt_1",
        -- "alt_2",
    },

    TRADE_UNITS = {
        "unit_acid_plant",
        "unit_angel_clover",
        "unit_black_rose",
        "unit_christmas_bell",
        "unit_dark_spikes",
        "unit_evolution_flower",
        "unit_fire_branch",
        "unit_firework_billy",
        "unit_firework_plant",
        "unit_frozen_spike",
        "unit_green_lights",
        "unit_ice_dragon",
        "unit_ice_eyeball",
        "unit_ice_flower",
        "unit_ice_gem",
        "unit_ice_rafflesia",
        "unit_ice_sunflower",
        "unit_peppermint",
        "unit_rafflesia",
    },

    INVITE_WAIT_SECONDS = 7,
    LOOP_DELAY = 0.3,
    ADD_UNIT_MAX_PER_TYPE = 250,
    STOP_ALT_AFTER_FIRST_TRADE = true,
    AUTO_KICK_ALT_AFTER_TRADE = true,
    ALT_KICK_DELAY_SECONDS = 0,
    ALT_KICK_MESSAGE = "Alt trade done - reconnect if needed.",
}

local PATH = {
    TRADE_FRAME = { "GameGui", "Screen", "Middle", "Trade" },
    TERMS_ACCEPT = { "GameGui", "Screen", "Middle", "Trade", "Terms", "Items", "Buttons", "Items", "Accept" },
    TRADE_FINAL_ACCEPT = { "GameGui", "Screen", "Middle", "Trade", "Items", "Container", "Items", "Right", "Controls", "Items", "Buttons", "Accept" },
    TRADE_OPPONENT_RECEIVE_SCROLL = { "GameGui", "Screen", "Middle", "Trade", "Items", "Container", "Items", "Right", "Receive", "Items", "ScrollingFrame" },
    TRADE_INVENTORY_SCROLL = { "GameGui", "Screen", "Middle", "Trade", "Inventory", "Inventory", "Frame", "Items", "Items", "ScrollingFrame" },
    AMOUNT_ADD_CONFIRM = { "GameGui", "Screen", "Middle", "Trade", "AmountAdd", "Frame", "Frame", "Actions", "Items", "Add" },
}

local function normalizeName(name)
    return (string.lower(tostring(name or "")):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function listToSet(list)
    local set = {}
    for _, item in ipairs(list or {}) do
        local key = normalizeName(item)
        if key ~= "" then
            set[key] = true
        end
    end
    return set
end

local MAIN_SET = listToSet(CONFIG.MAIN_ACCOUNTS)
local ALT_SET = listToSet(CONFIG.ALT_ACCOUNTS)
local TRADE_UNIT_SET = listToSet(CONFIG.TRADE_UNITS)
local HAS_ALT_ALLOW_LIST = next(ALT_SET) ~= nil
local SELF_NAME_NORM = normalizeName(player.Name)
local SELF_DISPLAY_NORM = normalizeName(player.DisplayName)

local function hasSelfInSet(setTable)
    return setTable[SELF_NAME_NORM] == true or (SELF_DISPLAY_NORM ~= "" and setTable[SELF_DISPLAY_NORM] == true)
end

local function resolveRole()
    local forcedRole = normalizeName(CONFIG.ROLE or "auto")
    if forcedRole == "main" then
        return "main"
    end
    if forcedRole == "alt" then
        return "alt"
    end

    if hasSelfInSet(MAIN_SET) then
        return "main"
    end

    if HAS_ALT_ALLOW_LIST then
        if hasSelfInSet(ALT_SET) then
            return "alt"
        end
        return "main"
    end

    return "alt"
end

local ROLE = resolveRole()
local IS_MAIN = ROLE == "main"

local OTHER_MAIN_SET = {}
for mainName in pairs(MAIN_SET) do
    if mainName ~= SELF_NAME_NORM and mainName ~= SELF_DISPLAY_NORM then
        OTHER_MAIN_SET[mainName] = true
    end
end

local function log(message)
    print(string.format("[AutoTrade][%s] %s", player.Name, message))
end

local function kickSelf(reason)
    pcall(function()
        player:Kick(reason or "Auto kick")
    end)
end

local function haltAltExecution()
    while true do
        task.wait(60)
    end
end

local function clickButton(button)
    if not button then
        return false
    end

    local ok = false
    if typeof(firesignal) == "function" then
        ok = pcall(function()
            firesignal(button.MouseButton1Down)
            firesignal(button.MouseButton1Click)
            firesignal(button.MouseButton1Up)
        end)
        if ok then
            return true
        end
    end

    return pcall(function()
        button:Activate()
    end)
end

local function waitForDescendant(parent, pathArray, timeout)
    local start = tick()
    while tick() - start <= (timeout or 10) do
        local current = parent
        local ok = true
        for _, name in ipairs(pathArray) do
            current = current and current:FindFirstChild(name)
            if not current then
                ok = false
                break
            end
        end
        if ok and current then
            return current
        end
        task.wait(0.2)
    end
    return nil
end

local function getByPath(parent, pathArray)
    local current = parent
    for _, name in ipairs(pathArray) do
        current = current and current:FindFirstChild(name)
        if not current then
            return nil
        end
    end
    return current
end

local function getTradeFrame()
    return getByPath(playerGui, PATH.TRADE_FRAME)
end

local function getTermsAcceptButton()
    return getByPath(playerGui, PATH.TERMS_ACCEPT)
end

local function getFinalAcceptButton()
    return getByPath(playerGui, PATH.TRADE_FINAL_ACCEPT)
end

local function getTradeInventoryScroll()
    return getByPath(playerGui, PATH.TRADE_INVENTORY_SCROLL)
end

local function getOpponentReceiveScroll()
    return getByPath(playerGui, PATH.TRADE_OPPONENT_RECEIVE_SCROLL)
end

local function findDescendantByName(root, targetName)
    if not root then
        return nil
    end
    local queue = { root }
    local index = 1
    while index <= #queue do
        local current = queue[index]
        index += 1
        for _, child in ipairs(current:GetChildren()) do
            if child.Name == targetName then
                return child
            end
            table.insert(queue, child)
        end
    end
    return nil
end

local function findFirstTextButton(root)
    if not root then
        return nil
    end
    local queue = { root }
    local index = 1
    while index <= #queue do
        local current = queue[index]
        index += 1
        for _, child in ipairs(current:GetChildren()) do
            if child:IsA("TextButton") then
                return child
            end
            table.insert(queue, child)
        end
    end
    return nil
end

local function findAnyButtonByNames(root, nameSet)
    if not root then
        return nil
    end
    local queue = { root }
    local index = 1
    while index <= #queue do
        local current = queue[index]
        index += 1
        for _, child in ipairs(current:GetChildren()) do
            local childName = normalizeName(child.Name)
            if nameSet[childName] and (child:IsA("TextButton") or child:IsA("ImageButton")) then
                return child
            end
            table.insert(queue, child)
        end
    end
    return nil
end

local function findNameMentionInTexts(root, targetSet)
    if not root then
        return nil
    end
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
            local text = normalizeName(descendant.Text)
            if text ~= "" then
                for name in pairs(targetSet) do
                    if string.find(text, name, 1, true) then
                        return name
                    end
                end
            end
        end
    end
    return nil
end

local function waitForNameMentionInTexts(root, targetSet, timeout)
    local start = tick()
    while tick() - start <= (timeout or 1) do
        local found = findNameMentionInTexts(root, targetSet)
        if found then
            return found
        end
        task.wait(0.15)
    end
    return nil
end

local function closeCurrentTrade(tradeFrame)
    local closeNames = {
        close = true,
        cancel = true,
        decline = true,
        deny = true,
        reject = true,
        back = true,
    }
    local button = findAnyButtonByNames(tradeFrame, closeNames)
    if button then
        clickButton(button)
        return true
    end
    return false
end

local function waitUntilTradeOpens(timeout)
    return waitForDescendant(playerGui, PATH.TRADE_FRAME, timeout or 10)
end

local function waitUntilTradeCloses(timeout)
    local start = tick()
    while tick() - start <= (timeout or 12) do
        if not getTradeFrame() then
            return true
        end
        task.wait(0.2)
    end
    return false
end

local function clickTermsAcceptIfAny()
    local termsAccept = getTermsAcceptButton()
    if termsAccept then
        clickButton(termsAccept)
        task.wait(0.2)
        return true
    end
    return false
end

local function hasConfiguredUnitInOpponentOffer()
    local offerScroll = getOpponentReceiveScroll()
    if not offerScroll then
        return false
    end

    for _, descendant in ipairs(offerScroll:GetDescendants()) do
        local unitName = normalizeName(descendant.Name)
        if TRADE_UNIT_SET[unitName] then
            return true
        end
    end

    return false
end

local function addAllConfiguredUnitsToTrade()
    local tradeInventory = getTradeInventoryScroll()
    if not tradeInventory then
        log("Khong tim thay kho trade inventory.")
        return 0
    end

    local totalAdded = 0
    for _, unitName in ipairs(CONFIG.TRADE_UNITS) do
        local addedCount = 0
        for _ = 1, CONFIG.ADD_UNIT_MAX_PER_TYPE do
            local unitNode = findDescendantByName(tradeInventory, unitName)
            if not unitNode then
                break
            end

            local addButton = findFirstTextButton(unitNode)
            if not addButton then
                break
            end

            clickButton(addButton)
            task.wait(0.12)

            local addConfirm = waitForDescendant(playerGui, PATH.AMOUNT_ADD_CONFIRM, 0.8)
            if addConfirm then
                clickButton(addConfirm)
            end

            addedCount += 1
            task.wait(0.12)
        end

        if addedCount > 0 then
            log(string.format("Da them %s x%d vao trade.", unitName, addedCount))
            totalAdded += addedCount
        end
    end

    return totalAdded
end

local function finalizeTradeAsAlt(hasAddedAnyUnit)
    local sawTradeScreen = false
    local clickedFinalAccept = false
    local start = tick()

    while tick() - start <= 35 do
        local tradeFrame = getTradeFrame()
        if not tradeFrame then
            if sawTradeScreen and (clickedFinalAccept or hasAddedAnyUnit) then
                return true
            end
            return false
        end

        sawTradeScreen = true
        clickTermsAcceptIfAny()

        local finalAccept = getFinalAcceptButton()
        if finalAccept then
            clickButton(finalAccept)
            clickedFinalAccept = true
            task.wait(0.25)
        else
            task.wait(0.2)
        end
    end

    return false
end

local function getOnlineMainPlayers()
    local online = {}
    local playersByNormName = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        playersByNormName[normalizeName(plr.Name)] = plr
        local displayNorm = normalizeName(plr.DisplayName)
        if displayNorm ~= "" and not playersByNormName[displayNorm] then
            playersByNormName[displayNorm] = plr
        end
    end

    for _, mainName in ipairs(CONFIG.MAIN_ACCOUNTS) do
        local key = normalizeName(mainName)
        if key ~= SELF_NAME_NORM then
            local target = playersByNormName[key]
            if target then
                table.insert(online, target)
            end
        end
    end
    return online
end

local function sendInviteToTarget(targetPlayer)
    local remoteFunctions = ReplicatedStorage:FindFirstChild("RemoteFunctions")
    local inviteRemote = remoteFunctions and remoteFunctions:FindFirstChild("SendTradeInvite")
    if not inviteRemote then
        return false, "SendTradeInvite remote khong ton tai"
    end

    local ok, err = pcall(function()
        inviteRemote:InvokeServer(targetPlayer)
    end)
    if not ok then
        return false, tostring(err)
    end
    return true
end

local function tryInviteUntilTradeOpen()
    while true do
        local currentTrade = getTradeFrame()
        if currentTrade then
            return true
        end

        local candidates = getOnlineMainPlayers()
        if #candidates == 0 then
            log("Chua co main online trong server. Dang cho...")
            task.wait(2)
            continue
        end

        for _, target in ipairs(candidates) do
            local ok, err = sendInviteToTarget(target)
            if ok then
                log("Da gui trade invite toi main: " .. target.Name)
            else
                log("Gui invite loi (" .. target.Name .. "): " .. err)
            end

            local opened = waitUntilTradeOpens(CONFIG.INVITE_WAIT_SECONDS)
            if opened then
                log("Da vao giao dien trade voi " .. target.Name)
                return true
            end

            log("Main " .. target.Name .. " dang ban hoac chua nhan. Chuyen main tiep theo...")
            task.wait(0.2)
        end

        task.wait(0.5)
    end
end

local function runMainLoop()
    log("Role MAIN: chi chap nhan loi moi trade tu alt hop le.")
    if not HAS_ALT_ALLOW_LIST then
        log("ALT_ACCOUNTS dang rong -> main chap nhan invite khong thuoc danh sach main.")
    end

    while true do
        local tradeFrame = getTradeFrame()
        if not tradeFrame then
            task.wait(CONFIG.LOOP_DELAY)
            continue
        end

        local termsAccept = getTermsAcceptButton()
        if termsAccept then
            local inviter = nil
            if HAS_ALT_ALLOW_LIST then
                inviter = waitForNameMentionInTexts(tradeFrame, ALT_SET, 1.2)
            else
                local inviterMain = waitForNameMentionInTexts(tradeFrame, OTHER_MAIN_SET, 0.8)
                if not inviterMain then
                    inviter = "any_alt"
                end
            end

            if inviter then
                clickButton(termsAccept)
                log("Chap nhan loi moi trade tu alt: " .. inviter)
            else
                closeCurrentTrade(tradeFrame)
                log("Tu choi trade: nguoi gui khong nam trong ALT_ACCOUNTS.")
            end
            task.wait(0.4)
        else
            local finalAccept = getFinalAcceptButton()
            if finalAccept then
                if hasConfiguredUnitInOpponentOffer() then
                    clickButton(finalAccept)
                    task.wait(0.5)
                else
                    task.wait(0.2)
                end
            else
                task.wait(CONFIG.LOOP_DELAY)
            end
        end
    end
end

local function runAltLoop()
    log("Role ALT: tu dong gui invite toi MAIN_ACCOUNTS den khi vao duoc trade.")
    while true do
        tryInviteUntilTradeOpen()
        clickTermsAcceptIfAny()
        local totalAdded = addAllConfiguredUnitsToTrade()
        local completed = finalizeTradeAsAlt(totalAdded > 0)
        if completed then
            log("Trade da ket thuc.")
            if CONFIG.AUTO_KICK_ALT_AFTER_TRADE then
                local delaySeconds = tonumber(CONFIG.ALT_KICK_DELAY_SECONDS) or 0
                if delaySeconds > 0 then
                    task.wait(delaySeconds)
                end
                log("Trade xong, tien hanh kick alt.")
                kickSelf(CONFIG.ALT_KICK_MESSAGE)
                task.wait(0.4)
            end

            if CONFIG.STOP_ALT_AFTER_FIRST_TRADE then
                log("Dung script alt sau trade dau tien.")
                haltAltExecution()
                return
            end
        else
            log("Chua the accept hoac trade bi huy. Thu lai tu dau...")
        end
        task.wait(1)
    end
end

log("Role detect: " .. ROLE)
if IS_MAIN then
    runMainLoop()
else
    runAltLoop()
end
