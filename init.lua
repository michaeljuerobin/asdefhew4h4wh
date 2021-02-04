-- Krnl Init!
-- 0866
-- December 30, 2020



local player do
    -- Player handler:
    local Players = game:GetService("Players")

    repeat 
        player = Players.LocalPlayer
    until player

    player.OnTeleport:Connect(function(teleportState)
        if (teleportState == Enum.TeleportState.InProgress) then
            HANDLE_TELEPORT()
        end
    end)
end


local Define, DefineCClosure do
    local GENV = getgenv()

    function Define(...)
        local aliases = table.pack(...)
        local value = table.remove(aliases, aliases.n)
        for _,key in ipairs(aliases) do
            GENV[key] = value
        end
        return value
    end

    function DefineCClosure(...)
        local aliases = table.pack(...)
        local value = newcclosure(table.remove(aliases, aliases.n))
        for _,key in ipairs(aliases) do
            GENV[key] = value
        end
        return value
    end
end


local AddMember, GetMember do
    local metatable = getrawmetatable(game)
    local __index = metatable.__index
    local __namecall = metatable.__namecall

    local instanceMembers = {}

    setreadonly(metatable, false)

    metatable.__namecall = newcclosure(function(self, ...)
        if (checkcaller() and GetMember(self, getnamecallmethod())) then
            return instanceMembers[self][getnamecallmethod()](self, ...)
        else
            return __namecall(self, ...)
        end
    end)

    metatable.__index = newcclosure(function(self, index)
        if (checkcaller() and GetMember(self, index)) then
            return instanceMembers[self][index]
        else
            return __index(self, index)
        end
    end)

    function AddMember(instance, aliases, func)
        local memberList = instanceMembers[instance]

        if (not memberList) then
            memberList = {}
            instanceMembers[instance] = memberList
        end

        if (type(func) == "function" and islclosure(func)) then
            func = newcclosure(func)
        end

        for _,memberName in ipairs(aliases) do
            memberList[memberName] = func
        end
    end

    function GetMember(instance, memberName)
        return (instanceMembers[instance] and instanceMembers[instance][memberName])
    end

    setreadonly(metatable, true)

end


do
    -- File system:
    DefineCClosure("loadfile", function(file)
        return loadstring(readfile(file), file)
    end)

    DefineCClosure("dofile", function(file)
        return loadfile(file)(file)
    end)

end


do
    -- World:
    local instances
    for key, value in pairs(getreg()) do
        if (type(key) == "userdata" and type(value) == "table" and rawget(value, "__mode")) then
            instances = value
            break
        end
    end

    Define("getinstances", function()
        return instances
    end)

    Define("getnilinstances", function()
        local list = {}
        for _,instance in ipairs(instances) do
            if (not instance.Parent) then
                table.insert(list, instance)
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
    DefineCClosure("hookfunction", "hookfunc", function(func, hook)
        if (iscclosure(func) and islclosure(hook)) then
            return hookfunction(func, newcclosure(hook))
        else
            return hookfunction(func, hook)
        end
    end)

    -- Unlock modules before requiring:
    DefineCClosure("require", function(moduleScript)
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
    -- Members:
    local httpGetAsync = game.HttpGetAsync
    local httpPostAsync = game.HttpPostAsync

    AddMember(game, { "HttpGet" }, function(self, url)
        local networkMode = getnetworkmode()
        setnetworkmode(3)
        local result = httpGetAsync(self, url)
        setnetworkmode(networkMode)
        return result
    end)

    AddMember(game, { "HttpPost" }, function(self, ...)
        local networkMode = getnetworkmode()
        setnetworkmode(3)
        local result = httpPostAsync(self, ...)
        setnetworkmode(networkMode)
        return result
    end)

    AddMember(game, { "GetObjects" }, function(self, assetId)
        if (type(assetId) == "number") then
            assetId = "rbxassetid://" .. assetId
        end
        return { game:GetService("InsertService"):LoadLocalAsset(assetId) }
    end)

    AddMember(game, { "Players" }, game:GetService("Players"))
    AddMember(game, { "Lighting" }, game:GetService("Lighting"))
    AddMember(game, { "ReplicatedStorage" }, game:GetService("ReplicatedStorage"))
    AddMember(game, { "CoreGui" }, game:GetService("CoreGui"))

end


do
    -- Member blacklist:
    local MEMBER_BLACKLIST = {
        [game] = {
            "OpenVideosFolder",
            "OpenScreenshotsFolder",
        };

        [game:GetService("BrowserService")] = {
            "OpenBrowserWindow",
        };

        [game:GetService("MarketplaceService")] = {
            "PromptBundlePurchase",
            "PromptPurchase",
            "PromptSubscriptionCancellation",
            "PromptProductPurchase",
            "PromptGamePassPurchase",
            "PromptPremiumPurchase",
            "PromptSubscriptionPurchase",
        };
    }

    for instance, names in pairs(MEMBER_BLACKLIST) do
        AddMember(instance, names, error)
    end

end


do
    -- Functions & aliases:
    Define("bit", bit32)
    Define("checkclosure", iskrnlclosure)
    Define("http_request", request)

    Define("isluau", function()
        return true
    end)

    for key, value in pairs(debug) do
        Define(key, value)
    end

end


do
    -- Krnl global:
    local Krnl = Define("Krnl", {
        Base64 = {
            Encode = base64_encode;
            Decode = base64_decode;
        };

        Vendor = {
            Maid = "https://raw.githubusercontent.com/Quenty/NevermoreEngine/version2/Modules/Shared/Events/Maid.lua";
            Promise = "https://gist.github.com/richie0866/f7c56370664cd8b6d13b02e70529fc86/raw/6e945905b6a1106276cf8b128893c2b50997a00f/Promise.lua";
            Signal = "https://gist.githubusercontent.com/richie0866/98879ede8725238d6eb8523774ec31b9/raw/7a4a57334056de0fe84f602315ba5c45524b57d9/Signal.lua";
            Thread = "https://gist.githubusercontent.com/richie0866/89a30f80b1562678a2d554c18c0a022f/raw/b53d733b2a52788648008d3bd7e553ea286f1d1e/Thread.lua";
            Hook = "https://gist.githubusercontent.com/richie0866/dfff74c366c141a681b580f613f7962f/raw/d89456887e62a8d5a36da0317f25454c433fa0bb/Hook.lua";
        };
    })

    local modules = {}

    function Krnl:Require(moduleName)
        if (modules[moduleName]) then
            return modules[moduleName]
        elseif (self.Vendor[moduleName]) then
            local module = loadstring(game:HttpGetAsync(self.Vendor[moduleName]))()
            modules[moduleName] = module
            return module
        else
            error("Attempt to require an unsupported module (Krnl:Require(\"" .. tostring(moduleName) .. "\"))")
        end
    end
    
    -- Saveinstance
    loadstring(game:HttpGet("https://raw.githubusercontent.com/michaeljuerobin/asdefhew4h4wh/main/si.lua"))()
end
