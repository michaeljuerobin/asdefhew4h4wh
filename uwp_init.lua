local Define, DefineCClosure do
    local GENV = getgenv()

    function Define(...)
        local aliases = table.pack(...)
        local value = table.remove(aliases, aliases.n)
        for _, key in ipairs(aliases) do
            GENV[key] = value
        end
        return value
    end

    function DefineCClosure(...)
        local aliases = table.pack(...)
        local value = newcclosure(table.remove(aliases, aliases.n))
        for _, key in ipairs(aliases) do
            GENV[key] = value
        end
        return value
    end
end

do
    Define("firesignal", function(signal, ...)
        for _, connection in ipairs(getconnections(signal)) do
            connection.Function(...)
        end
    end)
end

do
    -- Wrapping:
    local CoreGui = game:GetService("CoreGui")
    local CorePackages = game:GetService("CorePackages")
    local RunService = game:GetService("RunService")

    local functions = {
        require = getrenv().require
    }

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

    --[[DefineCClosure("hookmetamethod", function(object, method, hook, useArgGuard)
        if useArgGuard == nil then useArgGuard = true end

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

        if useArgGuard then
            local argHandler = newcclosure(function(...)
                if hasvoid(needsArgs, ...) then
                    return oldMethod(...)
                end
                return hook(...)
            end)

            oldMethod = hookfunction(hookMethod, argHandler)
        else
            oldMethod = hookfunction(hookMethod, hook)
        end

        return oldMethod
    end)]]
end

do
	local loadsaveinstance = loadsaveinstance
    getgenv().saveinstance = function(object, filename, options)
        object = object or game

        local SaveInstanceAPI = loadsaveinstance()
        SaveInstanceAPI.Init()
        SaveInstanceAPI.Save(object, filename, options)
    end

    getgenv().loadsaveinstance = nil

    getgenv().Krnl.WebSocket = WebSocket
end

-- Input
local VirtualInputManager = Instance.new("VirtualInputManager")
local GuiService = game:GetService("GuiService")

local VirtualInput = {}
local currentWindow = nil

function VirtualInput.setCurrentWindow(window)
    local old = currentWindow
    currentWindow = window
    return old
end

local function handleGuiInset(x, y)
    local guiOffset, _ = GuiService:GetGuiInset()
    return x + guiOffset.X, y + guiOffset.Y
end

function VirtualInput.sendMouseButtonEvent(x, y, button, isDown)
    x, y = handleGuiInset(x, y)
    VirtualInputManager:SendMouseButtonEvent(x, y, button, isDown, currentWindow, 0)
end

function VirtualInput.SendKeyEvent(isPressed, keyCode, isRepeated)
    VirtualInputManager:SendKeyEvent(isPressed, keyCode, isRepeated, currentWindow)
end

function VirtualInput.SendMouseMoveEvent(x, y)
    x, y = handleGuiInset(x, y)
    VirtualInputManager:SendMouseMoveEvent(x, y, currentWindow)
end

function VirtualInput.sendTextInputCharacterEvent(str)
    VirtualInputManager:sendTextInputCharacterEvent(str, currentWindow)
end

function VirtualInput.SendMouseWheelEvent(x, y, isForwardScroll)
    x, y = handleGuiInset(x, y)
    VirtualInputManager:SendMouseWheelEvent(x, y, isForwardScroll, currentWindow)
end

function VirtualInput.SendTouchEvent(touchId, state, x, y)
    x, y = handleGuiInset(x, y)
    VirtualInputManager:SendTouchEvent(touchId, state, x, y)
end

function VirtualInput.mouseWheel(vec2, num)
    local forward = false
    if num < 0 then
        forward = true
        num = -num
    end
    for _ = 1, num do
        VirtualInput.SendMouseWheelEvent(vec2.x, vec2.y, forward)
    end
end

function VirtualInput.touchStart(vec2)
    VirtualInput.SendTouchEvent(defaultTouchId, 0, vec2.x, vec2.y)
end

function VirtualInput.touchMove(vec2)
    VirtualInput.SendTouchEvent(defaultTouchId, 1, vec2.x, vec2.y)
end

function VirtualInput.touchStop(vec2)
    VirtualInput.SendTouchEvent(defaultTouchId, 2, vec2.x, vec2.y)
end

local function smoothSwipe(posFrom, posTo, duration)
    local passed = 0
    local started = false
    return function(dt)
        if not started then
            VirtualInput.touchStart(posFrom)
            started = true
        else
            passed = passed + dt
            if duration and passed < duration then
                local percent = passed / duration
                local pos = (posTo - posFrom) * percent + posFrom
                VirtualInput.touchMove(pos)
            else
                VirtualInput.touchMove(posTo)
                VirtualInput.touchStop(posTo)
                return true
            end
        end
        return false
    end
end

function VirtualInput.swipe(posFrom, posTo, duration, async)
    if async == true then
        asyncRun(smoothSwipe(posFrom, posTo, duration))
    else
        syncRun(smoothSwipe(posFrom, posTo, duration))
    end
end

function VirtualInput.tap(vec2)
    VirtualInput.touchStart(vec2)
    VirtualInput.touchStop(vec2)
end

function VirtualInput.click(vec2)
    VirtualInput.sendMouseButtonEvent(vec2.x, vec2.y, 0, true)
    VirtualInput.sendMouseButtonEvent(vec2.x, vec2.y, 0, false)
end

function VirtualInput.rightClick(vec2)
    VirtualInput.sendMouseButtonEvent(vec2.x, vec2.y, 1, true)
    VirtualInput.sendMouseButtonEvent(vec2.x, vec2.y, 1, false)
end

function VirtualInput.mouseLeftDown(vec2)
    VirtualInput.sendMouseButtonEvent(vec2.x, vec2.y, 0, true)
end

function VirtualInput.mouseLeftUp(vec2)
    VirtualInput.sendMouseButtonEvent(vec2.x, vec2.y, 0, false)
end

function VirtualInput.mouseRightDown(vec2)
    VirtualInput.sendMouseButtonEvent(vec2.x, vec2.y, 1, true)
end

function VirtualInput.mouseRightUp(vec2)
    VirtualInput.sendMouseButtonEvent(vec2.x, vec2.y, 1, false)
end

function VirtualInput.pressKey(keyCode)
    VirtualInput.SendKeyEvent(true, keyCode, false)
end

function VirtualInput.releaseKey(keyCode)
    VirtualInput.SendKeyEvent(false, keyCode, false)
end

function VirtualInput.hitKey(keyCode)
    VirtualInput.pressKey(keyCode)
    VirtualInput.releaseKey(keyCode)
end

function VirtualInput.mouseMove(vec2)
    VirtualInput.SendMouseMoveEvent(vec2.X, vec2.Y)
end

function VirtualInput.sendText(str)
    VirtualInput.sendTextInputCharacterEvent(str)
end

function nametoenum(name)
    return Enum.KeyCode[name]
end

local KeyCodes = {
    [0x08] = nametoenum("Backspace"),
    [0x09] = nametoenum("Tab"),
    [0x0C] = nametoenum("Clear"),
    [0x0D] = nametoenum("Return"),
    [0x10] = nametoenum("LeftShift"),
    [0x11] = nametoenum("LeftControl"),
    [0x12] = nametoenum("LeftAlt"),
    [0xA5] = nametoenum("RightAlt"),
    [0x13] = nametoenum("Pause"),
    [0x14] = nametoenum("CapsLock"),
    [0x1B] = nametoenum("Escape"),
    [0x20] = nametoenum("Space"),
    [0x21] = nametoenum("PageUp"),
    [0x22] = nametoenum("PageDown"),
    [0x23] = nametoenum("End"),
    [0x24] = nametoenum("Home"),
    [0x25] = nametoenum("Left"),
    [0x26] = nametoenum("Up"),
    [0x27] = nametoenum("Right"),
    [0x28] = nametoenum("Down"),
    [0x2A] = nametoenum("Print"),
    [0x2D] = nametoenum("Insert"),
    [0x2E] = nametoenum("Delete"),
    [0x2F] = nametoenum("Help"),
    [0x30] = nametoenum("Zero"),
    [0x31] = nametoenum("One"),
    [0x32] = nametoenum("Two"),
    [0x33] = nametoenum("Three"),
    [0x34] = nametoenum("Four"),
    [0x35] = nametoenum("Five"),
    [0x36] = nametoenum("Six"),
    [0x37] = nametoenum("Seven"),
    [0x38] = nametoenum("Eight"),
    [0x39] = nametoenum("Nine"),
    [0x41] = nametoenum("A"),
    [0x42] = nametoenum("B"),
    [0x43] = nametoenum("C"),
    [0x44] = nametoenum("D"),
    [0x45] = nametoenum("E"),
    [0x46] = nametoenum("F"),
    [0x47] = nametoenum("G"),
    [0x48] = nametoenum("H"),
    [0x49] = nametoenum("I"),
    [0x4A] = nametoenum("J"),
    [0x4B] = nametoenum("K"),
    [0x4C] = nametoenum("L"),
    [0x4D] = nametoenum("M"),
    [0x4E] = nametoenum("N"),
    [0x4F] = nametoenum("O"),
    [0x50] = nametoenum("P"),
    [0x51] = nametoenum("Q"),
    [0x52] = nametoenum("R"),
    [0x53] = nametoenum("S"),
    [0x54] = nametoenum("T"),
    [0x55] = nametoenum("U"),
    [0x56] = nametoenum("V"),
    [0x57] = nametoenum("W"),
    [0x58] = nametoenum("X"),
    [0x59] = nametoenum("Y"),
    [0x5A] = nametoenum("Z"),
    [0x5B] = nametoenum("LeftSuper"),
    [0x5C] = nametoenum("RightSuper"),
    [0x60] = nametoenum("KeypadZero"),
    [0x61] = nametoenum("KeypadOne"),
    [0x62] = nametoenum("KeypadTwo"),
    [0x63] = nametoenum("KeypadThree"),
    [0x64] = nametoenum("KeypadFour"),
    [0x65] = nametoenum("KeypadFive"),
    [0x66] = nametoenum("KeypadSix"),
    [0x67] = nametoenum("KeypadSeven"),
    [0x68] = nametoenum("KeypadEight"),
    [0x69] = nametoenum("KeypadNine"),
    [0x6A] = nametoenum("Asterisk"),
    [0x6B] = nametoenum("Plus"),
    [0x6D] = nametoenum("Minus"),
    [0x6E] = nametoenum("Period"),
    [0x6F] = nametoenum("Slash"),
    [0x70] = nametoenum("F1"),
    [0x71] = nametoenum("F2"),
    [0x72] = nametoenum("F3"),
    [0x73] = nametoenum("F4"),
    [0x74] = nametoenum("F5"),
    [0x75] = nametoenum("F6"),
    [0x76] = nametoenum("F7"),
    [0x77] = nametoenum("F8"),
    [0x78] = nametoenum("F9"),
    [0x79] = nametoenum("F10"),
    [0x7A] = nametoenum("F11"),
    [0x7B] = nametoenum("F12"),
    [0x7C] = nametoenum("F13"),
    [0x7D] = nametoenum("F14"),
    [0x7E] = nametoenum("F15"),
    [0x90] = nametoenum("NumLock"),
    [0x91] = nametoenum("ScrollLock"),
    [0xA0] = nametoenum("LeftShift"),
    [0xA1] = nametoenum("RightShift"),
    [0xA2] = nametoenum("LeftControl"),
    [0xA3] = nametoenum("RightControl"),
    [0xFE] = nametoenum("Clear"),
    [0xBB] = nametoenum("Equals"),
    [0xDB] = nametoenum("LeftBracket"),
    [0xDD] = nametoenum("RightBracket")
}

function get_keycode(key)
    local x = KeyCodes[key]

    if x then
        return x
    end

    return Enum.KeyCode.Unknown
end

getgenv().keypress = newcclosure(function(keyCode)
    if (typeof(keyCode) == "string") then
        VirtualInput.pressKey(get_keycode(tonumber(keyCode)))
    elseif (typeof(keyCode) == "number") then
        VirtualInput.pressKey(get_keycode(keyCode))
    else
        VirtualInput.pressKey(keyCode)
    end
end)

getgenv().keyrelease = newcclosure(function(keyCode)
    if (typeof(keyCode) == "string") then
        VirtualInput.releaseKey(get_keycode(tonumber(keyCode)))
    elseif (typeof(keyCode) == "number") then
        VirtualInput.releaseKey(get_keycode(keyCode))
    else
        VirtualInput.releaseKey(keyCode)
    end
end)

getgenv().mouse1click = newcclosure(function()
    VirtualInput.click(Vector2.new(game.Players.LocalPlayer:GetMouse().X, game.Players.LocalPlayer:GetMouse().Y))
end)

getgenv().mouse1press = newcclosure(function()
    VirtualInput.sendMouseButtonEvent(game.Players.LocalPlayer:GetMouse().X, game.Players.LocalPlayer:GetMouse().Y, 0, true)
end)

getgenv().mouse1release = newcclosure(function()
    VirtualInput.sendMouseButtonEvent(game.Players.LocalPlayer:GetMouse().X, game.Players.LocalPlayer:GetMouse().Y, 0, false)
end)

getgenv().mouse2press = newcclosure(function()
    VirtualInput.sendMouseButtonEvent(game.Players.LocalPlayer:GetMouse().X, game.Players.LocalPlayer:GetMouse().Y, 1, true)
end)

getgenv().mouse2release = newcclosure(function()
    VirtualInput.sendMouseButtonEvent(game.Players.LocalPlayer:GetMouse().X, game.Players.LocalPlayer:GetMouse().Y, 1, false)
end)

getgenv().mouse2click = newcclosure(function()
    VirtualInput.rightClick(Vector2.new(game.Players.LocalPlayer:GetMouse().X, game.Players.LocalPlayer:GetMouse().Y))
end)

getgenv().mousescroll = newcclosure(function(scroll)
    VirtualInput.mouseWheel(scroll, 1)
end)

getgenv().mousemoverel = newcclosure(function(x, y)
    VirtualInput.mouseMove(Vector2.new(x, y))
end)

getgenv().mousemoveabs = newcclosure(function(x, y)
    VirtualInput.mouseMove(Vector2.new(x, y))
end)

function left_click(x)
    if type(x) ~= "number" then
        error("bad argument (#1) to Input.LeftClick, expected number");
    end

    if (x == 1) then
        mouse1release()
    elseif (x == 2) then
        mouse1press()
    elseif (x == 3) then
        mouse1click()
    end
end

function right_click(x)
    if type(x) ~= "number" then
        error("bad argument (#1) to Input.RightClick, expected number");
    end

    if (x == 1) then
        mouse2release()
    elseif (x == 2) then
        mouse2press()
    elseif (x == 3) then
        mouse2click()
    end
end

function key_press(x)
    if type(x) ~= "number" then
        error("bad argument (#1) to Input.KeyPress, expected number");
    end

    keypress(x)
    keyrelease(x);
end

getgenv().Input = {
    LeftClick = left_click,
    RightClick = right_click,
    KeyPress = key_press,
    KeyDown = keypress,
    KeyUp = keyrelease
}

setreadonly(Input, true)
