-- client.lua
VORPcore = exports.vorp_core:GetCore()
local BccUtils = exports['bcc-utils'].initiate()
local FeatherMenu = exports['feather-menu'].initiate()

-- Register and configure the ISEEStoresMainMenu with FeatherMenu
ISEEStoresMainMenu = FeatherMenu:RegisterMenu('isee-stores:mainmenu', {
    top = '5%',
    left = '5%',
    ['720width'] = '500px',
    ['1080width'] = '600px',
    ['2kwidth'] = '700px',
    ['4kwidth'] = '900px',
    style = {},
    contentslot = {
      style = {
        ['height'] = '350px',
        ['min-height'] = '250px'
      }
    },
    draggable = true
  }, {
    opened = function()
        DisplayRadar(false)
    end,
    closed = function()
        DisplayRadar(true)
    end,
})

local CreatedBlip = {}
local CreatedNPC = {}
local BuyStore
local SellStore
local PromptGroup

CreateThread(function()
    StartPrompts()
    -- Setup blips and NPCs based on configuration
    if Config.ShopBlips then
        for shopName, shop in pairs(Config.shops) do
            local shopBlip = BccUtils.Blips:SetBlip(shop.blipName, shop.blipSprite, 1, shop.npcPos.x, shop.npcPos.y, shop.npcPos.z)
            CreatedBlip[#CreatedBlip + 1] = shopBlip
        end
    end

    if Config.ShopNPC then
        for shopName, shop in pairs(Config.shops) do
            local shopNPC = BccUtils.Ped:Create(shop.npcModel, shop.npcPos.x, shop.npcPos.y, shop.npcPos.z, -1, 'world', false)
            CreatedNPC[#CreatedNPC + 1] = shopNPC
            shopNPC:Freeze(true)
            shopNPC:SetHeading(shop.npcHeading)
            shopNPC:Invincible(true)
        end
    end

    while true do
        Wait(0)
        local playerCoords = GetEntityCoords(PlayerPedId())
        for shopName, shop in pairs(Config.shops) do
            local dist = #(playerCoords - shop.npcPos)
            if dist < shop.sDistance then
                PromptSetActiveGroupThisFrame(PromptGroup, CreateVarString(10, 'LITERAL_STRING', shop.promptName))
                if PromptHasStandardModeCompleted(BuyStore) then
                    OpenBuyMenu(shopName)
                end
                if PromptHasStandardModeCompleted(SellStore) then
                    OpenSellMenu(shopName)
                end
            else
                PromptSetEnabled(BuyStore, true)
                PromptSetEnabled(SellStore, true)
            end
        end
    end
end)

function OpenBuyMenu(shopName)
    BuyCategoriesMenu(shopName)
end

function OpenSellMenu(shopName)
    SellCategoriesMenu(shopName)
end

local function generateHtmlContent(entry, imgPath, levelText, price, isAvailable, isWeapon)
    local color = isAvailable and "black" or "red"
    local priceText = isAvailable and "$" .. tostring(price) or "Indisponibil"
    local label = isWeapon and entry.weaponLabel or entry.itemLabel

    return '<div style="display: flex; align-items: center; width: 100%; color: ' .. color .. ';">' ..
           '<img src="' .. imgPath .. '" style="width: 32px; height: 32px; margin-right: 10px;">' ..
           '<div style="text-align: center; flex-grow: 1;">' .. label .. " - " .. priceText .. 
           '<br><span style="font-size: smaller; color: gray;">' .. levelText .. '</span></div>' ..
           '</div>'
end

function BuyCategoriesMenu(shopName)
    local shopDetails = Config.shops[shopName]
    local categoriesPage = ISEEStoresMainMenu:RegisterPage('buycategories:page')

    categoriesPage:RegisterElement('header', {
        value = _U('storeCategory'),
        slot = "header"
    })

    categoriesPage:RegisterElement('line', {
        value = "",
        slot = "header"
    })

    local buyCategories = {}

    -- Handle item categories
    for _, item in ipairs(shopDetails.items) do
        if not buyCategories[item.category] then
            buyCategories[item.category] = true
            categoriesPage:RegisterElement('button', {
                label = item.category,
                slot = "content",
                sound = {
                    action = "SELECT",
                    soundset = "RDRO_Character_Creator_Sounds"
                },
            }, function()
                BuyMenu(shopName, item.category)
            end)
        end
    end

    -- Handle weapon categories
    local weaponCategories = {}
    for _, weapon in ipairs(shopDetails.weapons) do
        if not weaponCategories[weapon.category] then
            weaponCategories[weapon.category] = true
            categoriesPage:RegisterElement('button', {
                label = weapon.category,
                slot = "content",
                sound = {
                    action = "SELECT",
                    soundset = "RDRO_Character_Creator_Sounds"
                },
            }, function()
                BuyMenu(shopName, weapon.category)
            end)
        end
    end

    ISEEStoresMainMenu:Open({
        startupPage = categoriesPage
    })
end

function BuyMenu(shopName, category)
    local shopDetails = Config.shops[shopName]
    local itemsPage = ISEEStoresMainMenu:RegisterPage('buyitems:page')

    itemsPage:RegisterElement('header', {
        value = category,
        slot = "header"
    })

    itemsPage:RegisterElement('line', {
        slot = "header",
        style = {}
    })

    -- Handle items
    for _, item in ipairs(shopDetails.items) do
        if item.category == category then
            local imgPath = 'nui://vorp_inventory/html/img/items/' .. item.itemName .. '.png'
            local levelText = item.levelRequired and ("Level: " .. item.levelRequired) or ""
            local htmlContent

            if item.buyprice then  -- Check if buyprice exists
                htmlContent = generateHtmlContent(item, imgPath, levelText, item.buyprice, true, false)
                itemsPage:RegisterElement('button', {
                    html = htmlContent,
                    slot = "content"
                }, function()
                    RequestQuantity(item, category, shopName, true, false)
                end)
            else
                htmlContent = generateHtmlContent(item, imgPath, levelText, item.buyprice, false, false)
                itemsPage:RegisterElement('button', {
                    html = htmlContent,
                    slot = "content"
                }, function()
                    VORPcore.NotifyObjective("Acest produs este indisponibil la cumparare", 4000)
                end)
            end
        end
    end

    -- Handle weapons
    for _, weapon in ipairs(shopDetails.weapons) do
        if weapon.category == category then
            local imgPath = 'nui://vorp_inventory/html/img/items/' .. weapon.weaponasitem .. '.png'
            local levelText = weapon.levelRequired and ("Level: " .. weapon.levelRequired) or ""
            local htmlContent

            if weapon.buyprice then
                htmlContent = generateHtmlContent(weapon, imgPath, levelText, weapon.buyprice, true, true)
                itemsPage:RegisterElement('button', {
                    html = htmlContent,
                    slot = "content"
                }, function()
                    RequestQuantity(weapon, category, shopName, true, true)
                end)
            else
                htmlContent = generateHtmlContent(weapon, imgPath, levelText, weapon.buyprice, false, true)
                itemsPage:RegisterElement('button', {
                    html = htmlContent,
                    slot = "content"
                }, function()
                    VORPcore.NotifyObjective("Acest produs este indisponibil la cumparare", 4000)
                end)
            end
        end
    end

    itemsPage:RegisterElement('line', {
        slot = "footer",
        style = {}
    })

    itemsPage:RegisterElement('button', {
        label = _U('storeBackCategory'),
        slot = "footer"
    }, function()
        BuyCategoriesMenu(shopName)
    end)

    itemsPage:RegisterElement('bottomline', {
        slot = "footer",
        style = {}
    })

    ISEEStoresMainMenu:Open({
        startupPage = itemsPage
    })
end

function SellCategoriesMenu(shopName)
    local shopDetails = Config.shops[shopName]
    local SellCategoriesPage = ISEEStoresMainMenu:RegisterPage('sellcategory:menu')
    SellCategoriesPage:RegisterElement('header', {
        value = _U('storeCategory'),
        slot = "header"
    })

    SellCategoriesPage:RegisterElement('line', {
        slot = "header",
        style = {}
    })

    local sellCategories = {}
    for _, item in ipairs(shopDetails.items) do
        if not sellCategories[item.category] then
            sellCategories[item.category] = true
            SellCategoriesPage:RegisterElement('button', {
                label = item.category,
                slot = "content",
                sound = {
                    action = "SELECT",
                    soundset = "RDRO_Character_Creator_Sounds"
                },
            }, function()
                SellMenu(shopName, item.category)
            end)
        end
    end

    for _, weapon in ipairs(shopDetails.weapons) do
        if not sellCategories[weapon.category] then
            sellCategories[weapon.category] = true
            SellCategoriesPage:RegisterElement('button', {
                label = weapon.category,
                slot = "content",
                sound = {
                    action = "SELECT",
                    soundset = "RDRO_Character_Creator_Sounds"
                },
            }, function()
                SellMenu(shopName, weapon.category)
            end)
        end
    end

    SellCategoriesPage:RegisterElement('bottomline', {
        slot = "footer",
        style = {}
    })

    ISEEStoresMainMenu:Open({
        startupPage = SellCategoriesPage
    })
end

function SellMenu(shopName, category)
    local shopDetails = Config.shops[shopName]
    local categoryPage = ISEEStoresMainMenu:RegisterPage('sell:category')
    categoryPage:RegisterElement('header', {
        value = category,
        slot = "header"
    })

    categoryPage:RegisterElement('line', {
        slot = "header",
        style = {}
    })

    -- Handle items
    for _, item in ipairs(shopDetails.items) do
        if item.category == category then
            local imgPath = 'nui://vorp_inventory/html/img/items/' .. item.itemName .. '.png'
            local levelText = item.levelRequired and ("Level: " .. item.levelRequired) or ""
            local htmlContent

            if item.sellprice then  -- Check if sellprice exists
                htmlContent = generateHtmlContent(item, imgPath, levelText, item.sellprice, true, false)
                categoryPage:RegisterElement('button', {
                    html = htmlContent,
                    slot = "content"
                }, function()
                    RequestQuantity(item, category, shopName, false, false)
                end)
            else
                htmlContent = generateHtmlContent(item, imgPath, levelText, item.sellprice, false, false)
                categoryPage:RegisterElement('button', {
                    html = htmlContent,
                    slot = "content"
                }, function()
                    VORPcore.NotifyObjective("Acest produs este indisponibil la vanzare.", 4000)
                end)
            end
        end
    end

    -- Handle weapons
    for _, weapon in ipairs(shopDetails.weapons) do
        if weapon.category == category then
            local imgPath = 'nui://vorp_inventory/html/img/items/' .. weapon.weaponasitem .. '.png'
            local levelText = weapon.levelRequired and ("Level: " .. weapon.levelRequired) or ""
            local htmlContent

            if weapon.sellprice then  -- Check if sellprice exists
                htmlContent = generateHtmlContent(weapon, imgPath, levelText, weapon.sellprice, true, true)
                categoryPage:RegisterElement('button', {
                    html = htmlContent,
                    slot = "content"
                }, function()
                    RequestQuantity(weapon, category, shopName, false, true)
                end)
            else
                htmlContent = generateHtmlContent(weapon, imgPath, levelText, weapon.sellprice, false, true)
                categoryPage:RegisterElement('button', {
                    html = htmlContent,
                    slot = "content"
                }, function()
                    VORPcore.NotifyObjective("Acest produs este indisponibil la vanzare.", 4000)
                end)
            end
        end
    end

    categoryPage:RegisterElement('line', {
        slot = "footer",
        style = {}
    })

    categoryPage:RegisterElement('button', {
        label = _U('storeBackCategory'),
        slot = "footer",
        style = {
            -- Additional styles can be added here
        },
        sound = {
            action = "SELECT",
            soundset = "RDRO_Character_Creator_Sounds"
        }
    }, function()
        SellCategoriesMenu(shopName)
    end)

    categoryPage:RegisterElement('bottomline', {
        slot = "footer",
        style = {}
    })

    ISEEStoresMainMenu:Open({
        startupPage = categoryPage
    })
end

function RequestQuantity(entry, category, shopName, isBuying, isWeapon)
    local playerLevel = GetPlayerLevel()
    local levelRequired = entry.levelRequired or 0

    if levelRequired > playerLevel then
        VORPcore.NotifyObjective("You need to be level " .. levelRequired .. " to " .. (isBuying and "purchase" or "sell") .. " this " .. (isWeapon and "weapon" or "item") .. ".", 4000)
        return
    end

    if isBuying and not entry.buyprice then
        VORPcore.NotifyObjective("Acest produs este indisponibil la cumparare", 4000)
        return
    end

    local inputPage = ISEEStoresMainMenu:RegisterPage('entry:quantity')
    local quantity = 1 -- Default quantity, can be updated by the input

    inputPage:RegisterElement('header', {
        value = _U(isBuying and 'storeQty' or 'storeQty'),
        slot = "header"
    })

    inputPage:RegisterElement('line', {
        slot = "header",
        style = {}
    })

    inputPage:RegisterElement('input', {
        label = _U('storeQty'),
        slot = "content",
        type = "number",
        default = 1,
        min = 1,
        max = entry.quantity -- Assuming you have item/weapon quantity available
    }, function(data)
        local inputQty = tonumber(data.value)
        if inputQty and inputQty > 0 then
            quantity = inputQty
        else
            VORPcore.NotifyObjective(_U('storeInvalidQty'), 4000)
            quantity = nil
        end
    end)

    inputPage:RegisterElement('button', {
        label = _U(isBuying and 'storeBuy' or 'storeSell'),
        style = {
            -- Additional styles can be added here
        },
        sound = {
            action = "SELECT",
            soundset = "RDRO_Character_Creator_Sounds"
        }
    }, function()
        if quantity then
            if isBuying then
                ProcessPurchase(shopName, entry, quantity, isWeapon)
            else
                ProcessSale(shopName, entry, quantity, isWeapon)
            end
            if isBuying then
                BuyMenu(shopName, category)
            else
                SellMenu(shopName, category)
            end
        else
            VORPcore.NotifyObjective(_U('storeValidQty'), 4000)
        end
    end)

    inputPage:RegisterElement('line', {
        slot = "footer",
        style = {}
    })

    inputPage:RegisterElement('button', {
        label = _U('BackToItems'),
        slot = "footer",
        style = {
            -- Additional styles can be added here
        },
        sound = {
            action = "SELECT",
            soundset = "RDRO_Character_Creator_Sounds"
        }
    }, function()
        if isBuying then
            BuyMenu(shopName, category)
        else
            SellMenu(shopName, category)
        end
    end)

    inputPage:RegisterElement('bottomline', {
        slot = "footer",
        style = {}
    })

    ISEEStoresMainMenu:Open({
        startupPage = inputPage
    })
end

RegisterNetEvent('isee-stores:receivePlayerLevel')
AddEventHandler('isee-stores:receivePlayerLevel', function(level)
    playerLevel = level
end)

function GetPlayerLevel()
    return playerLevel
end

function ProcessPurchase(shopName, entry, quantity, isWeapon)
    local totalCost = entry.buyprice * quantity
    if quantity and quantity > 0 then
        if isWeapon then
            TriggerServerEvent('isee-stores:buyweapon', shopName, entry.weaponName, quantity, totalCost)
        else
            TriggerServerEvent('isee-stores:purchaseItem', shopName, entry.itemName, quantity, totalCost)
        end
    else
        VORPcore.NotifyObjective("Invalid quantity. Purchase request not sent.")
    end
end

function ProcessSale(shopName, entry, quantity, isWeapon)
    if quantity and quantity > 0 then
        if isWeapon then
            TriggerServerEvent('isee-stores:sellWeapon', shopName, entry.weaponName, quantity)
        else
            TriggerServerEvent('isee-stores:sellItem', shopName, entry.itemName, quantity)
        end
    else
        VORPcore.NotifyObjective("Invalid quantity. Sale request not sent.")
    end
end

function RequestInventory()
    TriggerServerEvent('isee-stores:requestInventory')
end

RegisterNetEvent('isee-stores:displayInventoryItems')
AddEventHandler('isee-stores:displayInventoryItems', function(inventoryItems)
    OpenSellMenu(inventoryItems)
end)

function StartPrompts()
    PromptGroup = GetRandomIntInRange(0, 0xffffff) -- Ensure a unique prompt group is created

    BuyStore = PromptRegisterBegin()
    PromptSetControlAction(BuyStore, Config.keys.buy)
    PromptSetText(BuyStore, CreateVarString(10, 'LITERAL_STRING', _U('storeBuy')))
    PromptSetVisible(BuyStore, true)
    PromptSetStandardMode(BuyStore, true)
    PromptSetGroup(BuyStore, PromptGroup)
    PromptRegisterEnd(BuyStore)

    SellStore = PromptRegisterBegin()
    PromptSetControlAction(SellStore, Config.keys.sell)
    PromptSetText(SellStore, CreateVarString(10, 'LITERAL_STRING', _U('storeSell')))
    PromptSetVisible(SellStore, true)
    PromptSetStandardMode(SellStore, true)
    PromptSetGroup(SellStore, PromptGroup)
    PromptRegisterEnd(SellStore)
end

local playerLevel = 0

RegisterNetEvent('isee-stores:receivePlayerLevel')
AddEventHandler('isee-stores:receivePlayerLevel', function(level)
    playerLevel = level
end)

function GetPlayerLevel()
    TriggerServerEvent('isee-stores:requestPlayerLevel')
    return playerLevel
end

-- CleanUp on Resource Restart
RegisterNetEvent('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for _, npcs in ipairs(CreatedNPC) do
            npcs:Remove()
        end
        for _, blips in ipairs(CreatedBlip) do
            blips:Remove()
        end
    end
end)
