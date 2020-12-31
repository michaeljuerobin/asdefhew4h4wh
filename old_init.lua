--|| Setup Teleport Handler:
local LocalPlayer
repeat 
    LocalPlayer = game:GetService("Players").LocalPlayer
until LocalPlayer ~= nil

LocalPlayer.OnTeleport:Connect(function(TeleportState)
    if TeleportState == Enum.TeleportState.InProgress then
        HANDLE_TELEPORT()
    end
end)

--|| Variables:
local InsertService = game:GetService("InsertService")
local MarketPlaceService = game:GetService("MarketplaceService")
local CorePackages = game:GetService("CorePackages")
local CoreGui = game:GetService("CoreGui")
local ScriptContext = game:GetService("ScriptContext")
local LogService = game:GetService("LogService")

local metatable = getrawmetatable(game);
setreadonly(metatable, false);

local index = metatable.__index;
local namecall = metatable.__namecall;

getgenv().script = Instance.new('LocalScript')

--|| Cross-Program Support:

getgenv().isluau = function() return true; end;
getgenv().is_luau = isluau
getgenv().checkclosure = iskrnlclosure
getgenv().http_request = request

getgenv().loadfile = newcclosure(function(name)
    return loadstring(readfile(name))
end)

getgenv().dofile = newcclosure(function(name)
    return loadstring(readfile(name))()
end)

local ohookfunction = hookfunction
getgenv().hookfunction = newcclosure(function(f1, f2)
    if iscclosure(f1) and islclosure(f2) then
        return ohookfunction(f1, newcclosure(f2))
    end
    return ohookfunction(f1, f2)
end)

getgenv().bit = getgenv().bit32

getgenv().firesignal = newcclosure(function(signal, ...)
	local connections = getconnections(signal)
	for _, connection in ipairs(connections) do
		connection:Fire(...)
	end
end)

getgenv().hookfunc = getgenv().hookfunction

local oglm = getloadedmodules
getgenv().getloadedmodules = function()
    local ret = {}
    local modules = oglm()

    for i, v in next, modules do
        if not (v:IsDescendantOf(CorePackages)) and not (v:IsDescendantOf(CoreGui)) then
            table.insert(ret, v)
        end
    end

    return ret
end

for k,v in next, debug do
    getgenv()[k] = v
end

local oldreq = getgenv().require
getgenv().require = newcclosure(function(module)
    if(checkcaller()) then
        if(typeof(module) == "Instance" and module:IsA("ModuleScript")) then
            unlockModule(module)
            local data = oldreq(module)
            lockModule(module)
            return data
        elseif(type(module) == "number") then
            return oldreq(module);
        else
            return error("Attempt to call require with invalid argument(s).");
        end;
    end;

    return oldreq(module);
end)

HttpPost = newcclosure(function(self, ...)
    return game:HttpPostAsync(...)
end)

HttpGet = newcclosure(function(self, ...)
	local args = table.pack(...)
    return game:HttpGetAsync(args[1])
end)

GetObjects = newcclosure(function(self, id)
    if type(id) == "number" then
        return { InsertService:LoadLocalAsset("rbxassetid://"..tostring(id)) }
    end
    return { InsertService:LoadLocalAsset(id) }
end)

    local instanceCache, instanceCacheKey

    local function getinstancecache()
        if (not instanceCache) then
            for k, tbl in pairs(getreg()) do
                if (type(k) == "userdata" and type(tbl) == "table" and rawget(tbl, "__mode")) then
                    instanceCache = tbl
                    instanceCacheKey = k
                    break
                end
            end
        end
        return instanceCache, instanceCacheKey
    end

    getgenv().getinstancecachekey = (function()
        for i, v in next, getreg() do
            if type(i) == "userdata" and type(v) == "table" then
                if rawget(v, "__mode") then
                    return i
                end
            end
        end
    end)

    getgenv().getnilinstances = (function()
        local nilinstances = {}
        local tab = getreg()[getinstancecachekey()]
        for i, v in next, tab do
            if not v.Parent then
                table.insert(nilinstances, v)
            end
        end
        return nilinstances
    end)

    getgenv().getinstances = (function()
        return getreg()[getinstancecachekey()]
    end)

--|| Runtime:

metatable.__namecall = newcclosure(function(self, ...)
    if(checkcaller()) then
        local method = getnamecallmethod()
        if self == game then
            if method == 'GetObjects' then
                return GetObjects(self, ...)
            elseif method == 'HttpGet' then
                return HttpGet(self, ...)
            elseif method == 'HttpPost' then
                return game:HttpPostAsync(...)
            elseif method == 'OpenVideosFolder' or method == 'OpenScreenshotsFolder' then
                return error("Illegal function "..method)
            end
        end

        if self == MarketPlaceService then
            if method:lower():match("purchase") then
                return error("Illegal function " .. method)
            end
        end
    end;
    return namecall(self, ...)
end)

metatable.__index = newcclosure(function(t, v)
    if(checkcaller()) then
        if t == game then
            if type(v) == "string" then
                if v == 'GetObjects' then
                    return GetObjects
                elseif v == 'HttpGet' then
                    return HttpGet
                elseif v == 'HttpPost' then
                    return game.HttpPostAsync
                elseif v == 'OpenVideosFolder' or v == 'OpenScreenshotsFolder' then
                    return error("Illegal function " .. v)
				elseif v == "Players" then
					return game:GetService("Players")
				elseif v == "ReplicatedStorage" then
					return game:GetService("ReplicatedStorage")
                end
            end
        end

        if t == MarketPlaceService then
            if type(v) == 'string' and v:lower():match("purchase") then
                return error("Illegal function " .. v)
            end
        end
    end;
    return index(t, v)
end)

setreadonly(metatable, true)

do
    -- Community modules:
    local resources = {
        Maid = "https://raw.githubusercontent.com/Quenty/NevermoreEngine/version2/Modules/Shared/Events/Maid.lua";
        Promise = "https://raw.githubusercontent.com/Sleitnick/Knit/main/src/Knit/Util/Promise.lua";
        Signal = "https://gist.githubusercontent.com/richie0866/98879ede8725238d6eb8523774ec31b9/raw/7a4a57334056de0fe84f602315ba5c45524b57d9/Signal.lua";
        Thread = "https://raw.githubusercontent.com/Sleitnick/Knit/main/src/Knit/Util/Thread.lua";
        Simulation = "https://gist.githubusercontent.com/richie0866/152b1491856bdca1bdc89d2ff0bfe871/raw/9b7e25f5531743615d77d83855b13fdac002088f/Simulation.lua";
        Hook = "https://gist.githubusercontent.com/richie0866/dfff74c366c141a681b580f613f7962f/raw/d89456887e62a8d5a36da0317f25454c433fa0bb/Hook.lua";
    }

    local Krnl = {
		base64 = {
			encode = getgenv().base64_encode,
			decode = getgenv().base64_decode
		}
	}

	do
        local modules = {}

        --[[
            Runs the given URL's contents as a chunk.
        ]]
        function Krnl:Fetch(url, ...)
            return loadstring(game:HttpGetAsync(url))(...)
        end

        --[[
            Gets the source URL of a module.
        ]]
        function Krnl:GetURL(moduleName)
            return resources[moduleName]
        end

        --[[
            Returns a Krnl module. Will yield on the
            first call of a specific module.
        ]]
        function Krnl:Get(moduleName)
            if (modules[moduleName]) then
                return modules[moduleName]
            elseif (resources[moduleName]) then
                local module = self:Fetch(resources[moduleName])
                modules[moduleName] = module
                return module
            else
                error(("Attempt to fetch an unsupported module (Krnl:Get(\"%s\"))"):format(tostring(moduleName)))
            end
        end
    end

    getgenv().Krnl = Krnl

end

loadstring(game:HttpGet("https://krnl.rocks/scripts/saveinstance.lua"))();
