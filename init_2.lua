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
    local __index
    local __namecall

    local instanceMembers = {}

    setreadonly(metatable, false)

    function hasvoid(len, ...)
        return table.pack(...).n < len
    end

    __namecall = hookfunction(metatable.__namecall, newcclosure(function(...)
        local self = ...
        if
            not hasvoid(1, ...)
                and checkcaller()
                and GetMember(self, getnamecallmethod())
        then
            return instanceMembers[self][getnamecallmethod()](...)
        else
            return __namecall(...)
        end
    end))

    __index = hookfunction(metatable.__index, newcclosure(function(...)
        local self, key = ...
        if
            not hasvoid(2, ...)
                and checkcaller()
                and GetMember(self, key)
        then
            return instanceMembers[self][key]
        else
            return __index(...)
        end
    end))

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

    Define("getinstancecache", function()
        return instances
    end)

    Define("getnilinstances", function()
        local list = {}
        for _,instance in pairs(getinstances()) do
            if (not instance.Parent) then
                table.insert(list, instance)
            end
        end
        return list
    end)
    
    Define("firesignal", function(signal, ...)
        for _,connection in ipairs(getconnections(signal)) do
            connection.Function(...)
        end
    end)

    Define("script", Instance.new("LocalScript"))

end


do
    -- Wrapping:
    local CoreGui = game:GetService("CoreGui")
    local CorePackages = game:GetService("CorePackages")
    local RunService = game:GetService("RunService")

    local functions = {
        hookfunction = hookfunction,
        getloadedmodules = getloadedmodules,
        require = getrenv().require,
        request = request,
        rconsoleinput = rconsoleinput,
        messagebox = messagebox
    }

    -- Auto wrap hook in newcclosure:
    DefineCClosure("hookfunction", "hookfunc", function(func, hook)
        if (iscclosure(func) and islclosure(hook)) then
            return functions.hookfunction(func, newcclosure(hook))
        else
            return functions.hookfunction(func, hook)
        end
    end)
    
    -- Spawn asynchronous function in new thread:
    Define("rconsoleinput", function()
        local result, hb
        hb = RunService.Heartbeat:Connect(function()
            hb:Disconnect()
            result = functions.rconsoleinput()
        end)
        while (type(result) ~= "string") do
            RunService.Heartbeat:Wait()
        end
        return result
    end)
    
    Define("messagebox", function(text, caption, flags)
        local result, hb
        hb = RunService.Heartbeat:Connect(function()
            hb:Disconnect()
            result = functions.messagebox(text, caption, flags)
        end)
        while (type(result) ~= "number") do
            RunService.Heartbeat:Wait()
        end
        return result
    end)
    
    Define("request", function(options, async)
        local result, hb
        hb = RunService.Heartbeat:Connect(function()
            hb:Disconnect()
            result = functions.request(options, async)
        end)
        while (type(result) ~= "table") do
            RunService.Heartbeat:Wait()
        end
        return result
    end)
    
    -- Unlock modules before requiring:
    DefineCClosure("require", function(moduleScript)
        if (typeof(moduleScript) == "Instance" and moduleScript:IsA("ModuleScript")) then
            local oldContext = getthreadcontext()
            setthreadcontext(2)
            local status, module = pcall(functions.require, moduleScript)
            setthreadcontext(oldContext)
            assert(status, module)
            return module
        else
            return functions.require(moduleScript)
        end
    end)
    
    -- Filter loaded modules:
    Define("getloadedmodules", function()
        local filteredModules = {}
        for _,obj in ipairs(functions.getloadedmodules()) do
            if (obj:IsDescendantOf(CoreGui) or obj:IsDescendantOf(CorePackages)) then continue end
            table.insert(filteredModules, obj)
        end
        return filteredModules
    end)
    
    DefineCClosure("hookmetamethod", function(object, method, hook)
        local metatable = getrawmetatable(object)

        assert(type(metatable) == "table",
            "invalid argument #1 to 'hookmetamethod' (object with metatable expected)")
        assert(type(method) == "string",
            string.format("invalid argument #2 to 'hookmetamethod' (string expected, got %s)", type(method)))
        assert(type(hook) == "function",
            string.format("invalid argument #3 to 'hookmetamethod' (function expected, got %s)", type(hook)))

        local hookMethod = metatable[method]
        assert(type(hookMethod) == "function",
             string.format("object does not have metamethod '%s'", method))

        if islclosure(hook) then hook = newcclosure(hook) end

        local needsArgs = (method == "__index" and 2) or (method == "__namecall" and 1) or (method == "__newindex" and 3) or 0

        local oldMethod

        local argHandler = newcclosure(function(...)
            if hasvoid(needsArgs, ...) then
                return oldMethod(...)
            end
            return hook(...)
        end)

        oldMethod = hookfunction(hookMethod, argHandler)

        return oldMethod
    end)
end


do
    -- Members:
    local httpGetAsync = game.HttpGetAsync
    local httpPostAsync = game.HttpPostAsync
    local KRNL_SAFE_CALL = KRNL_SAFE_CALL

    AddMember(game, { "HttpGet", "HttpGetAsync" }, function(self, url)
        return KRNL_SAFE_CALL(httpGetAsync, self, url)
    end)

    AddMember(game, { "HttpPost", "HttpPostAsync" }, function(self, ...)
        return KRNL_SAFE_CALL(httpPostAsync, self, ...)
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
    AddMember(game, { "RunService" }, game:GetService("RunService"))

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
    Define("hiddenUI", gethui)

    Define("isluau", function()
        return true
    end)
    
    Define("identifyexecutor", function()
        return "Krnl"
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
        
        crypt = {
            hash = sha384_hash;
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
    
    function Krnl:LoadAsync(url)
        return loadstring(game:HttpGetAsync(url))()
    end

    spawn(function()
        Krnl.WebSocket = Krnl:LoadAsync("https://raw.githubusercontent.com/michaeljuerobin/asdefhew4h4wh/main/websocket.lua")
        Define("WebSocket", Krnl.WebSocket)
            
        Krnl.SaveInstance = Krnl:LoadAsync("https://raw.githubusercontent.com/michaeljuerobin/asdefhew4h4wh/main/si.lua")
        Define("saveinstance", Krnl.SaveInstance.Save)
    end)
end

run_auto_execute_scripts()
run_teleport_queue_scripts()
