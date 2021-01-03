-- SaveInstance
-- 0866
-- January 01, 2021

local SaveInstance = {}

SaveInstance.BufferSize = 5632
SaveInstance.DecompileScripts = false
SaveInstance.SaveRemovedInstances = true
SaveInstance.SavePlayer = true

SaveInstance._scriptCache = {}

local encodeBase64 = assert(Krnl.Base64.Encode, "No base64 encoder found")
local gethiddenproperty = gethiddenproperty or error

local IGNORE_LIST = {
    [game:GetService("CoreGui")] = true;
    [game:GetService("CorePackages")] = true;
    [game:GetService("Players")] = true;
    [game:GetService("Chat"):FindFirstChild("ChatModules")] = true;
    [game:GetService("Chat"):FindFirstChild("ClientChatModules")] = true;
    [game:GetService("Chat"):FindFirstChild("ChatServiceRunner")] = true;
    [game:GetService("Chat"):FindFirstChild("ChatScript")] = true;
}

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")


--[[
    Loads the Roblox API dump
]]
local ApiDump do
    local version = game:HttpGetAsync("http://setup.roblox.com/versionQTStudio")
    local apiDumpJSON = game:HttpGetAsync("http://setup.roblox.com/" .. version .. "-API-Dump.json")
    ApiDump = HttpService:JSONDecode(apiDumpJSON)
end


--[[
    Maps canonical properties to their serialized forms
    and adds hidden serialized properties
]]
do
    local serializedForms = {
        BasePart = {
            Size = "size";
            Color = "Color";
        };

        Fire = {
            Size = "size_xml";
        };
    }

    local serializedProperties = {
        Model = {
            ModelInPrimary = {
                MemberType = "Property";
                Serialization = {
                    CanSave = true;
                };
                ValueType = {
                    Name = "CFrame";
                };
            };

            ModelMeshCFrame = {
                MemberType = "Property";
                Serialization = {
                    CanSave = true;
                };
                ValueType = {
                    Name = "CFrame";
                };
            };

            ModelMeshSize = {
                MemberType = "Property";
                Serialization = {
                    CanSave = true;
                };
                ValueType = {
                    Name = "Vector3";
                };
            };
        };

        MeshPart = {
            PhysicsData = {
                MemberType = "Property";
                Serialization = {
                    CanSave = true;
                };
                ValueType = {
                    Name = "BinaryString";
                };
            };
            
            InitialSize = {
                MemberType = "Property";
                Serialization = {
                    CanSave = true;
                };
                ValueType = {
                    Name = "Vector3";
                };
            };
        };

        UnionOperation = {
            AssetId = {
                MemberType = "Property";
                Serialization = {
                    CanSave = true;
                };
                ValueType = {
                    Name = "Content";
                };
            };
            
            ChildData = {
                MemberType = "Property";
                Serialization = {
                    CanSave = true;
                };
                ValueType = {
                    Name = "BinaryString";
                };
            };
            
            FormFactor = {
                MemberType = "Property";
                Serialization = {
                    CanSave = true;
                };
                ValueType = {
                    Category = "Enum";
                    Name = "FormFactor";
                };
            };
            
            InitialSize = {
                MemberType = "Property";
                Serialization = {
                    CanSave = true;
                };
                ValueType = {
                    Name = "Vector3";
                };
            };
            
            MeshData = {
                MemberType = "Property";
                Serialization = {
                    CanSave = true;
                };
                ValueType = {
                    Name = "BinaryString";
                };
            };
            
            PhysicsData = {
                MemberType = "Property";
                Serialization = {
                    CanSave = true;
                };
                ValueType = {
                    Name = "BinaryString";
                };
            };
        };

        Terrain = {
            SmoothGrid = {
                MemberType = "Property";
                Serialization = {
                    CanSave = true;
                };
                ValueType = {
                    Name = "BinaryString";
                };
            };
        };
    }

    for _,class in ipairs(ApiDump.Classes) do
        if (serializedForms[class.Name]) then
            local map = serializedForms[class.Name]

            for _,member in ipairs(class.Members) do
                if (map[member.Name]) then
                    member.SerializedName = map[member.Name]
                    member.Serialization.CanSave = true
                end
            end
        end

        if (serializedProperties[class.Name]) then
            local members = serializedProperties[class.Name]

            for memberName, member in pairs(members) do
                member.Name = memberName
                table.insert(class.Members, member)
            end
        end
    end
end


--[[
    Makes a new ApiDump.Classes dictionary and inherits superclasses
]]
local Classes = {} do
    for _,class in ipairs(ApiDump.Classes) do
        class.Properties = {}
        
        for _,member in ipairs(class.Members) do
            if (member.MemberType == "Property" and member.Serialization.CanSave) then
                table.insert(class.Properties, member)
            end
        end

        Classes[class.Name] = class
    end

    -- Inherit properties:
    for _,class in ipairs(ApiDump.Classes) do
        if (Classes[class.Superclass]) then

            for _,property in ipairs(Classes[class.Superclass].Properties) do
                table.insert(class.Properties, property)
            end
        end
    end
end


function SaveInstance.EscapeForm(str)
    local entityMap = { ["<"]="lt", [">"]="gt", ["&"]="amp", ["\""]="quot", ["'"]="apos" }
    return str:gsub("[><&\"']", function(s)
        return ("&" .. entityMap[s] .. ";")
    end)
end


function SaveInstance.CacheScripts(parent)
    if (not SaveInstance.DecompileScripts) then return end

    assert(typeof(parent) == "Instance", "Argument #1 'parent' must be a valid Instance")

    local jobCount = 0

    local function Cache(instance)
        if (IGNORE_LIST[instance]) then return end

        if (instance:IsA("LocalScript") or instance:IsA("ModuleScript")) then
            jobCount += 1
            spawn(function()
                local ok, result = pcall(decompile, instance)
                if (ok) then
                    SaveInstance._scriptCache[instance] = result
                end
                jobCount -= 1
            end)
        end

        for _,child in ipairs(instance:GetChildren()) do
            Cache(child)
        end
    end

    Cache(parent)

    while (jobCount > 0) do
        RunService.Heartbeat:Wait()
    end
end


function SaveInstance.Save(parent: Instance)

    parent = parent or game

    local file = parent:GetFullName() .. "-Save-" .. game.PlaceId do
        if (parent.Parent == game or parent == game) then
            file ..= ".rbxlx"
        else
            file ..= ".rbxmx"
        end
    end

    local buffer = {}
    local bufferSize = 0

    local instanceIds = {}
    local instanceCount = 0

    local function Flush()
        appendfile(file, table.concat(buffer))
        table.clear(buffer)
        bufferSize = 0
    end

    local function Insert(entry)
        bufferSize += 1
        buffer[bufferSize] = entry
    end
    
    local function Identify(instance)
        local id = instanceIds[instance]
        if (id) then
            return id
        else
            instanceCount += 1
            instanceIds[instance] = "RBX" .. instanceCount
            return "RBX" .. instanceCount
        end
    end

    local function Serialize(instance, children)
        if (instance == game) then return end

        if (bufferSize > SaveInstance.BufferSize) then
            Flush()
        end

        local className = instance.ClassName
        if (className == "PlayerScripts" or className == "PlayerGui") then
            className = "Folder"
        end

        Insert("<Item class=\"" .. className .. "\" referent=\"" .. Identify(instance) .. "\">\n<Properties>")

        for _,property in ipairs(Classes[instance.ClassName] and Classes[instance.ClassName].Properties or {}) do
            local propertyType = property.ValueType.Name
            local propertyCategory = property.ValueType.Category
            
            local success, value = pcall(function() return instance[property.Name] end)
            if (not success) then
                success, value = pcall(gethiddenproperty, instance, property.Name)
                if (not success) then
                    continue
                end
            end
            
            local propertyName = property.SerializedName or property.Name
            
            if (propertyCategory == "Class") then
                Insert(
                    "<Ref name=\"" .. propertyName .. "\">" ..
                    (value and Identify(value) or "null") ..
                    "</Ref>"
                )

            elseif (propertyType == "CFrame") then
                local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
                Insert(
                    "<CoordinateFrame name=\"" .. propertyName .. "\">" ..
                    "\n<X>" .. x .. "</X>\n<Y>" .. y .. "</Y>\n<Z>" .. z .. "</Z>\n<R00>" ..
                    r00 .. "</R00>\n<R01>" .. r01 .. "</R01>\n<R02>" .. r02 .. "</R02>\n<R10>" ..
                    r10 .. "</R10>\n<R11>" .. r11 .. "</R11>\n<R12>" .. r12 .. "</R12>\n<R20>" ..
                    r20 .. "</R20>\n<R21>" .. r21 .. "</R21>\n<R22>" .. r22 .. "</R22>\n" ..
                    "</CoordinateFrame>"
                )

            elseif (propertyType == "Vector3") then
                Insert(
                    "<Vector3 name=\"" .. propertyName .. "\">" ..
                    "\n<X>" .. value.X .. "</X>\n<Y>" .. value.Y .. "</Y>\n<Z>" .. value.Z .. "</Z>\n" ..
                    "</Vector3>"
                )

            elseif (propertyType == "Vector2") then
                Insert(
                    "<Vector2 name=\"" .. propertyName .. "\">" ..
                    "\n<X>" .. value.X .. "</X>\n<Y>" .. value.Y .. "</Y>\n" ..
                    "</Vector2>"
                )

            elseif (propertyType == "Color3") then
                Insert(
                    "<Color3 name=\"" .. propertyName .. "\">" ..
                    "\n<R>" .. value.R .. "</R>\n<G>" .. value.G .. "</G>\n<B>" .. value.B .. "</B>\n" ..
                    "</Color3>"
                )

            elseif (propertyType == "UDim") then
                Insert(
                    "<UDim name=\"" .. propertyName .. "\">" ..
                    "\n<S>" .. value.Scale .. "</S>\n<O>" .. value.Offset .. "</O>\n" ..
                    "</UDim>"
                )

            elseif (propertyType == "UDim2") then
                Insert(
                    "<UDim2 name=\"" .. propertyName .. "\">" ..
                    "\n<XS>" .. value.X.Scale .. "</XS>\n<XO>" .. value.X.Offset .. "</XO>\n<YS>" ..
                    value.Y.Scale .. "</YS>\n<YO>" .. value.Y.Offset .. "</YO>\n" ..
                    "</UDim2>"
                )

            elseif (propertyType == "Rect") then
                Insert(
                    "<Rect name=\"" .. propertyName .. "\">" ..
                    "\n<min>\n<X>" .. value.Min.X .. "</X>\n<Y>" .. value.Min.Y .. "</Y>\n</min>\n<max>\n<X>" ..
                    value.Max.X .. "</X>\n<Y>" .. value.Max.Y .. "</Y>\n</max>\n" ..
                    "</Rect>"
                )

            elseif (propertyType == "Content") then
                Insert(
                    "<Content name=\"" .. propertyName .. "\">" ..
                    "<url>" .. value .. "</url>" ..
                    "</Content>"
                )

            elseif (propertyType == "BinaryString") then
                Insert(
                    "<BinaryString name=\"" .. propertyName .. "\">" ..
                    "<![CDATA[" .. encodeBase64(value) .. "]]>" ..
                    "</BinaryString>"
                )

            elseif (propertyType == "ProtectedString") then
                Insert(
                    "<ProtectedString name=\"" .. propertyName .. "\">" ..
                    "<![CDATA[" .. (SaveInstance._scriptCache[instance] or value) .. "]]>" ..
                    "</ProtectedString>"
                )

            elseif (propertyCategory == "Enum") then
                Insert(
                    "<token name=\"" .. propertyName .. "\">" ..
                    value.Value ..
                    "</token>"
                )

            else
                Insert(
                    "<" .. type(value) .. " name=\"" .. propertyName .. "\">" ..
                    SaveInstance.EscapeForm(tostring(value)) ..
                    "</" .. type(value) .. ">"
                )
            end
        end

        Insert("</Properties>")

        for _,child in ipairs(children or instance:GetChildren()) do
            Serialize(child)
        end

        Insert("</Item>")
    end

    SaveInstance.CacheScripts(parent)

    writefile(file, "<roblox xmlns:xmime=\"http://www.w3.org/2005/05/xmlmime\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:noNamespaceSchemaLocation=\"http://www.roblox.com/roblox.xsd\" version=\"4\">\n<External>null</External>\n<External>nil</External>")

    if (parent == game) then
        for _,service in ipairs(game:GetChildren()) do
            if (IGNORE_LIST[service]) then continue end
            Serialize(service)
        end
    else
        Serialize(parent)
    end

    if (SaveInstance.SaveRemovedInstances) then
        local removedInstanceFolder = Instance.new("Folder")
        removedInstanceFolder.Name = "RemovedInstances"

        Serialize(removedInstanceFolder, getnilinstances())
    end

    if (SaveInstance.SavePlayer) then
        local player = game:GetService("Players").LocalPlayer

        local playerFolder = Instance.new("Folder")
        playerFolder.Name = "LocalPlayer"

        SaveInstance.CacheScripts(player)

        Serialize(playerFolder, player:GetChildren())
    end

    Insert("<SharedStrings>\n</SharedStrings>\n</roblox>")
    Flush()

end

getgenv().saveinstance = SaveInstance.Save
