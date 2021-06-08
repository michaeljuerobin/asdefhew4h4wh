local Signal = Krnl:Require("Signal")

local WebSocket = {}
WebSocket.__index = WebSocket
WebSocket.ClassName = "WebSocket"

function WebSocket:Close()
    close_socket(self)
end

function WebSocket:Send(message)
    assert(type(message) == "string", "string expected")
    send_socket(self, message)
end

function WebSocket.connect(url)
    assert(type(url) == "string", "string expected")
    local self = setmetatable({
        _connected = false
    }, WebSocket)
    
    --TODO: MAKE THIS NOT ASS
    local ready_state
    spawn(function()
        ready_state = assign_socket(self, url)
        self._connected = true
    end)
    repeat wait() until self._connected
    
    assert(ready_state == 1, "Failed to connect to WebSocket")

    self.OnMessage = Signal.new()
    self.OnClose = Signal.new()
    return self
end

return WebSocket
