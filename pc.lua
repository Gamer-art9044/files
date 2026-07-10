local gpu = peripheral.find("directgpu")
if not gpu then error("No directgpu peripheral found") end

local wsUrl = "ws://26.249.231.240:8089" 
local fps = 11
local scale = 2 

local display = gpu.autoDetectAndCreateDisplayWithResolution(scale)
if not display or display == -1 then error("Failed to create display.") end
local info = gpu.getDisplayInfo(display)
local w, h = info.pixelWidth, info.pixelHeight

print("Display connected: " .. w .. "x" .. h)
print("Connecting to WebSocket...")

local ws, err = http.websocket(wsUrl)
if not ws then 
    gpu.removeDisplay(display)
    error("WebSocket failed: " .. tostring(err)) 
end

print("Connected! Downloading GIF via Handshake...")

local fullData = {}
local totalBytes = 0

while true do
    -- Запрашиваем следующий кусок данных у питона
    ws.send("next")
    
    local message, isBinary = ws.receive()
    
    if not message then
        print("[-] Connection lost during download")
        break
    end
    
    -- Проверяем текстовый маркер окончания файла
    if message == "EOF" then
        print("[+] All chunks received successfully!")
        break
    end
    
    table.insert(fullData, message)
    totalBytes = totalBytes + #message
    print("Received: " .. math.floor(totalBytes / 1024) .. " KB")
    
    -- Небольшой yield, чтобы разгрузить поток Java/Lua
    os.sleep(0.01)
end

ws.close()

print("Assembling GIF in RAM...")
local gif = table.concat(fullData)
fullData = nil -- Освобождаем массив из памяти, оставляем только строку
print("Starting playback of " .. #gif .. " bytes...")

-- Запуск анимации
local ok, err = pcall(function()
    if gpu.loadGIFRegionBytes then return gpu.loadGIFRegionBytes(display, gif, 0, 0, w, h, fps)
    elseif gpu.loadGIFRegion then return gpu.loadGIFRegion(display, gif, 0, 0, w, h, fps)
    elseif gpu.loadGIFFullscreen then return gpu.loadGIFFullscreen(display, gif, fps)
    else return gpu.loadGIFFrame(display, gif, 0, 0, 0, w, h) end
end)

if not ok then
    print("Error:", err)
    gpu.removeDisplay(display)
    return
end

gpu.updateDisplay(display)
os.pullEvent("key")

if gpu.stopGIF then pcall(gpu.stopGIF, display) end
pcall(gpu.removeDisplay, display)
print("Stopped")
