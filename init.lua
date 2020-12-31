-- Krnl Init!
-- 0866
-- December 30, 2020

--[[
    
]]


local Players = game:GetService("Players")


local player do
    -- Player handler:
    repeat 
        player = Players.LocalPlayer
    until player

    player.OnTeleport:Connect(function(teleportState)
        if (teleportState == Enum.TeleportState.InProgress) then
            HANDLE_TELEPORT()
        end
    end)
end


local Define do
    local GENV = getgenv()

    function Define(...)
        local aliases = table.pack(...)
        local value = table.remove(aliases, aliases.n)
    
        value = (type(value) == "function" and newcclosure(value) or value)
    
        for _,key in ipairs(aliases) do
            GENV[key] = value
        end
    end
end


local AddMethod, GetMethod do
    local metatable = getrawmetatable(game)
    local __index = metatable.__index
    local __namecall = metatable.__namecall

    local instanceMethods = {}

    setreadonly(metatable, false)

    metatable.__namecall = newcclosure(function(self, ...)
        if (
            checkcaller()
            and instanceMethods[self]
            and instanceMethods[self][getnamecallmethod()]
        ) then
            return instanceMethods[self][getnamecallmethod()](self, ...)
        else
            return __namecall(self, ...)
        end
    end)

    metatable.__index = newcclosure(function(self, ...)
        if (
            checkcaller()
            and instanceMethods[self]
            and instanceMethods[self][getnamecallmethod()]
        ) then
            return instanceMethods[self][getnamecallmethod()]
        else
            return __index(self, ...)
        end
    end)

    function AddMethod(instance, ...)
        local aliases = table.pack(...)
        local func = table.remove(aliases, aliases.n)

        local methodList = (instanceMethods[instance] or {})

        for _,methodName in ipairs(aliases) do
            methodList[methodName] = func
        end
    end

    function GetMethod(instance, methodName)
        return (instanceMethods[instance] and instanceMethods[instance][methodName])
    end

end


do
    -- File system:
    Define("loadfile", function(file)
        assert(isfile(file), "Argument #1 'file' must be a file")
        return loadstring(readfile(file), file)
    end)

    Define("dofile", function(file)
        assert(isfile(file), "Argument #1 'file' must be a file")
        return loadfile(file)(file)
    end)

end


do
    -- World:
    Define("getnilinstances", function()
        local list = {}
        for _,instance in ipairs(getinstances()) do
            if (instance.Parent == nil) then
                table.insert(instance, list)
            end
        end
        return list
    end)
    
    Define("firesignal", function(signal, ...)
        for _,connection in ipairs(getconnections(signal)) do
            connection:Fire(...)
        end
    end)

    Define("script", Instance.new("LocalScript"))

end


do
    -- Wrapping:
    local CoreGui = game:GetService("CoreGui")
    local CorePackages = game:GetService("CorePackages")

    local hookfunction = hookfunction
    local require = require
    local getloadedmodules = getloadedmodules

    -- Auto wrap hook in newcclosure:
    Define("hookfunction", "hookfunc", function(func, hook)
        if (iscclosure(func) and islclosure(hook)) then
            return hookfunction(func, newcclosure(hook))
        else
            return hookfunction(func, hook)
        end
    end)

    -- Unlock modules before requiring:
    Define("require", function(moduleScript)
        if (not checkcaller()) then
            return require(moduleScript)
        end
        unlockModule(moduleScript)
        local module = require(moduleScript)
        lockModule(moduleScript)
        return module
    end)
    
    -- Filter loaded modules:
    Define("getloadedmodules", function()
        local filteredModules = {}
        for _,obj in ipairs(getloadedmodules()) do
            if (obj:IsDescendantOf(CoreGui) or obj:IsDescendantOf(CorePackages)) then continue end
            table.insert(filteredModules, obj)
        end
        return filteredModules
    end)

end


do
    -- Methods:
    local httpGetAsync = game.HttpGetAsync
    local httpPostAsync = game.HttpPostAsync

    AddMethod(game, "HttpGetAsync", "HttpGet", function(self, url)
        local networkMode = getnetworkmode()
        setnetworkmode(3)
        httpGetAsync(self, url)
        setnetworkmode(networkMode)
    end)

    AddMethod(game, "HttpPostAsync", "HttpPost", function(self, url)
        local networkMode = getnetworkmode()
        setnetworkmode(3)
        httpPostAsync(self, url)
        setnetworkmode(networkMode)
    end)

    AddMethod(game, "GetObjects", function(self, assetId)
        return { game:GetService("InsertService"):LoadLocalAsset(assetId) }
    end)

    AddMethod(
        game:GetService("MarketplaceService"),
        "PromptBundlePurchase",
        "PromptPurchase",
        "PromptSubscriptionCancellation",
        "PromptProductPurchase",
        "PromptGamePassPurchase",
        "PromptPremiumPurchase",
        "PromptSubscriptionPurchase",
        function()
        end
    )

end


do
    -- Aliases:
    Define("bit", bit32)
    Define("checkclosure", iskrnlclosure)
    Define("http_request", request)

    for key, value in pairs(debug) do
        Define(key, value)
    end

end
