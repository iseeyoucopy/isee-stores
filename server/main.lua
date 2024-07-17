VORPcore = exports.vorp_core:GetCore()
local BccUtils = exports['bcc-utils'].initiate()
local discord = BccUtils.Discord.setup(Config.Webhook, Config.WebhookTitle, Config.WebhookAvatar)

-- Helper functions
function getItemDetails(itemName)
    for _, shop in pairs(Config.shops) do
        for _, item in pairs(shop.items) do
            if item.itemName == itemName then
                return item
            end
        end
    end
    return nil
end

function getWeaponDetails(weaponName)
    for _, shop in pairs(Config.shops) do
        for _, weapon in pairs(shop.weapons) do
            if weapon.weaponName == weaponName then
                return weapon
            end
        end
    end
    return nil
end

function getLevelFromXP(xp)
    return math.floor(xp / 1000)
end

function getPlayerXP(source)
    local Character = VORPcore.getUser(source).getUsedCharacter
    return Character.xp
end

-- Helper function to get the selling price of an item from the config
local function getItemSellPrice(itemName)
    for _, shop in pairs(Config.shops) do
        for _, item in pairs(shop.items) do
            if item.itemName == itemName and item.sellprice then
                return item.sellprice
            end
        end
    end
    return 0
end

-- Helper function to get the selling price of a weapon from the config
local function getWeaponSellPrice(weaponName)
    for _, shop in pairs(Config.shops) do
        for _, weapon in pairs(shop.weapons) do
            if weapon.weaponName == weaponName and weapon.sellprice then
                return weapon.sellprice
            end
        end
    end
    return 0
end

-- Purchase item event
RegisterServerEvent('isee-stores:purchaseItem')
AddEventHandler('isee-stores:purchaseItem', function(shopName, itemName, quantity, totalCost)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local level = getLevelFromXP(Character.xp)

    local shop = Config.shops[shopName]
    if not shop then
        VORPcore.NotifyObjective(_source, "Shop not found", 3000)
        return
    end

    local itemDetails = getItemDetails(itemName)
    if itemDetails then
        if level >= (itemDetails.levelRequired or 0) then
            local canCarry = exports.vorp_inventory:canCarryItem(source, itemName, quantity)
            if not canCarry then
                VORPcore.NotifyObjective(_source, "Nu poti cara mai multe " .. itemDetails.itemLabel .. ".", 4000)
                return
            end
            if Character.money >= totalCost then
                Character.removeCurrency(0, totalCost)
                exports.vorp_inventory:addItem(_source, itemName, quantity)
                VORPcore.NotifyObjective(_source, "Ai cumpărat " .. quantity .. "x " .. itemDetails.itemLabel .. " pentru " .. totalCost .. "$", 4000)
                discord:sendMessage("Name: " .. Character.firstname .. " " .. Character.lastname ..
                                    "\nIdentifier: " .. Character.identifier ..
                                    "\nBought: " .. itemDetails.itemLabel .. " " .. itemName ..
                                    "\nQuantity: " .. quantity ..
                                    "\nMoney: $" .. totalCost ..
                                    "\nShop: " .. shopName)
            else
                VORPcore.NotifyObjective(_source, "Nu ai destui bani", 4000)
            end
        else
            VORPcore.NotifyObjective(_source, "Trebuie să ai nivelul " .. itemDetails.levelRequired .. " pentru a cumpăra.", 4000)
        end
    end
end)

-- Purchase weapon event
RegisterServerEvent("isee-stores:buyweapon")
AddEventHandler("isee-stores:buyweapon", function(shopName, weaponName, amount, totalCost)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local level = getLevelFromXP(Character.xp)

    local shop = Config.shops[shopName]
    if not shop then
        VORPcore.NotifyObjective(_source, "Shop not found", 3000)
        return
    end

    local weaponDetails
    for _, weapon in pairs(shop.weapons) do
        if weapon.weaponName:upper() == weaponName:upper() then
            weaponDetails = weapon
            break
        end
    end

    if weaponDetails then
        print("Shop:", shopName) -- Debugging print
        print("Weapon:", weaponDetails.weaponLabel or weaponDetails.weaponName) -- Debugging print

        if level >= (weaponDetails.levelRequired or 0) then
            local canCarry = exports.vorp_inventory:canCarryWeapons(_source, amount, nil, weaponName:upper())
            if not canCarry then
                VORPcore.NotifyObjective(_source, "Nu poti avea mai multe arme", 3000)
                return
            end

            if Character.money >= totalCost then
                Character.removeCurrency(0, totalCost)
                local ammo = { ["nothing"] = 0 }
                local components = { ["nothing"] = 0 }

                local createdWeapons = 0
                for i = 1, amount do
                    local label = weaponDetails.weaponLabel or weaponDetails.weaponName

                    exports.vorp_inventory:createWeapon(_source, weaponDetails.weaponName, ammo, components, {}, function(success)
                        if success then
                            createdWeapons = createdWeapons + 1
                            if createdWeapons == amount then
                                VORPcore.NotifyObjective(_source, "Ai cumparat " .. amount .. " x " .. label .. " pentru " .. totalCost .. "$", 3000)
                                discord:sendMessage("Name: " .. Character.firstname .. " " .. Character.lastname ..
                                                    "\nBought: " .. label ..
                                                    "\nQuantity: " .. amount ..
                                                    "\nPrice: $" .. totalCost ..
                                                    "\nShop: " .. shopName)
                            end
                        else
                            VORPcore.NotifyObjective(_source, "Achizitie esuata pentru una dintre arme", 3000)
                        end
                    end, label)
                end
            else
                VORPcore.NotifyObjective(_source, "Nu ai destui bani", 3000)
            end
        else
            VORPcore.NotifyObjective(_source, "Trebuie sa ai nivelul " .. weaponDetails.levelRequired .. " pentru a cumpara.", 4000)
        end
    else
        VORPcore.NotifyObjective(_source, "Arma nu a fost gasita in configuratie", 4000)
    end
end)

-- Sell item event
RegisterServerEvent('isee-stores:sellItem')
AddEventHandler('isee-stores:sellItem', function(shopName, itemName, amount)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local playerItems = exports.vorp_inventory:getUserInventoryItems(_source)

    local shop = Config.shops[shopName]
    if not shop then
        VORPcore.NotifyObjective(_source, "Shop not found", 3000)
        return
    end

    -- Find the item in the player's inventory
    local itemToSell = nil
    for _, item in pairs(playerItems) do
        if item.name == itemName and item.count >= amount then
            itemToSell = item
            break
        end
    end

    if itemToSell then
        -- Check if the player can actually sell the items (negative amounts mean taking away)
        exports.vorp_inventory:canCarryItem(_source, itemName, -amount, function(canSell)
            if canSell then
                -- Calculate the money to give to the player
                local sellPrice = getItemSellPrice(itemName)
                if sellPrice and sellPrice > 0 then  -- Check if sell price is valid
                    local totalMoney = sellPrice * amount
                    -- Remove the items from the player's inventory
                    exports.vorp_inventory:subItem(_source, itemName, amount)
                    -- Add money to the player's account
                    Character.addCurrency(0, totalMoney) -- Assuming currency type 0 is cash
                    VORPcore.NotifyObjective(_source, "Ai vandut " .. amount .. "x " .. itemName .. " pentru $" .. totalMoney, 4000)
                    discord:sendMessage("Name: " .. Character.firstname .. " " .. Character.lastname ..
                                        "\nSold: " .. itemName ..
                                        "\nQuantity: " .. amount ..
                                        "\nEarned: $" .. totalMoney ..
                                        "\nShop: " .. shopName)
                else
                    VORPcore.NotifyObjective(_source, "Acest produs nu are pret " .. itemName, 4000)
                end
            else
                VORPcore.NotifyObjective(_source, "Can't process sale. Inventory issue with " .. itemName, 4000)
            end
        end)
    else
        VORPcore.NotifyObjective(_source, "Nu ai indeajuns " .. itemName .. " pentru a vinde.", 4000)
    end
end)

-- Sell weapon event
RegisterServerEvent('isee-stores:sellWeapon')
AddEventHandler('isee-stores:sellWeapon', function(shopName, weaponName, amount)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local playername = Character.firstname .. ' ' .. Character.lastname

    local shop = Config.shops[shopName]
    if not shop then
        VORPcore.NotifyObjective(_source, "Shop not found", 3000)
        return
    end

    -- Validate the amount
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        VORPcore.NotifyObjective(_source, "Cantitate invalidă", 3000)
        return
    end
    
    -- Get the player's weapon inventory
    exports.vorp_inventory:getUserInventoryWeapons(_source, function(playerWeapons)
        local weaponsToSell = {}
        local foundAmount = 0

        -- Iterate over the player's weapons to find the matching ones
        for _, weapon in ipairs(playerWeapons) do
            if weapon.name == weaponName then
                table.insert(weaponsToSell, weapon)
                foundAmount = foundAmount + 1
                if foundAmount >= amount then
                    break
                end
            end
        end

        -- Debug: Check if sufficient weapons to sell are found
        if foundAmount < amount then
            print("Insufficient weapons found: " .. tostring(weaponName))
            VORPcore.NotifyObjective(_source, "Nu ai destule " .. tostring(weaponName) .. " pentru a vinde.", 3000)
            return
        end

        -- Check if the player can carry fewer weapons
        exports.vorp_inventory:canCarryWeapons(_source, -amount, function(canSell)
            if not canSell then
                VORPcore.NotifyObjective(_source, "Nu se poate procesa vânzarea. Probleme cu inventarul pentru " .. tostring(weaponName), 3000)
                return
            end

            -- Get the sell price
            local sellPrice = getWeaponSellPrice(weaponName)
            if not sellPrice or sellPrice <= 0 then
                VORPcore.NotifyObjective(_source, "Nu este setat prețul pentru această armă", 3000)
                return
            end

            local totalMoney = sellPrice * amount

            -- Remove the weapons from the player's inventory and add currency
            local soldWeapons = 0
            for _, weapon in ipairs(weaponsToSell) do
                local weaponLabel = weapon.custom_label or weapon.label or weapon.name
                exports.vorp_inventory:subWeapon(_source, weapon.id, function(success)
                    if success then
                        soldWeapons = soldWeapons + 1
                        if soldWeapons == amount then
                            Character.addCurrency(0, totalMoney)
                            VORPcore.NotifyObjective(_source, "Ai vândut " .. amount .. " x " .. weaponLabel .. " pentru " .. totalMoney .. "$", 3000)
                            discord:sendMessage("Name: " .. playername ..
                                                "\nSold: " .. weaponLabel ..
                                                "\nQuantity: " .. amount ..
                                                "\nEarned: $" .. totalMoney ..
                                                "\nShop: " .. shopName)
                        end
                    else
                        VORPcore.NotifyObjective(_source, "Vânzare eșuată", 3000)
                    end
                end)
            end
        end, weaponName)
    end)
end)

-- Request player XP event
RegisterServerEvent('isee-stores:requestPlayerXP')
AddEventHandler('isee-stores:requestPlayerXP', function()
    local _source = source
    local xp = getPlayerXP(_source)
    TriggerClientEvent('isee-stores:receivePlayerXP', _source, xp)
end)

-- Request player level event
RegisterServerEvent('isee-stores:requestPlayerLevel')
AddEventHandler('isee-stores:requestPlayerLevel', function()
    local _source = source
    local xp = getPlayerXP(_source)
    local level = getLevelFromXP(xp)
    TriggerClientEvent('isee-stores:receivePlayerLevel', _source, level)
end)

-- Event to get user inventory and send it to the client
RegisterNetEvent('isee-stores:requestInventory')
AddEventHandler('isee-stores:requestInventory', function()
    local _source = source
    exports.vorp_inventory:getUserInventoryItems(_source, function(inventoryItems)
        -- Assuming inventoryItems is a table of item data
        TriggerClientEvent('isee-stores:displayInventoryItems', _source, inventoryItems)
    end)
end)

-- Function to generate unique serial numbers
function GenerateWeaponSerial()
    -- Implement your logic to generate a unique serial number
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local serial = "HOINARII-"
    for i = 1, 10 do
        local rand = math.random(1, #chars)
        serial = serial .. chars:sub(rand, rand)
    end
    return serial
end
