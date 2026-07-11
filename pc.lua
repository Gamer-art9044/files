local gpu = peripheral.find("directgpu")
if not gpu then error("No directgpu peripheral found") end

-- Обрати внимание, протокол теперь ws://
local ws_url = "ws://26.222.210.23:8080"
local scale = 2

local display = gpu.autoDetectAndCreateDisplayWithResolution(scale)
if not display or display == -1 then
    error("Failed to create display.")
end

local info = gpu.getDisplayInfo(display)
local w = info.pixelWidth
local h = info.pixelHeight

print("Connecting to WebSocket...")
local ws, err = http.websocket(ws_url)

if not ws then
    gpu.removeDisplay(display)
    error("WebSocket connection failed: " .. tostring(err))
end

print("Streaming! Press any key to stop.")

local is_running = true

local function streamLoop()
    while is_running do
        -- Получаем бинарное сообщение из сокета (true включает бинарный режим)
        local msg = ws.receive(nil, true)
        
        if msg then
            pcall(function()
                -- Скармливаем 1 кадр напрямую в GPU
                if gpu.loadGIFFrame then
                    gpu.loadGIFFrame(display, msg, 0, 0, 0, w, h)
                end
            end)
            gpu.updateDisplay(display)
            
            -- КРИТИЧЕСКИ ВАЖНО ДЛЯ ОЗУ: удаляем переменную и чистим память
            msg = nil
        else
            -- Соединение разорвано сервером
            break
        end
    end
end

local function waitForKey()
    os.pullEvent("key")
    is_running = false
    ws.close()
end

-- Крутим стрим и проверку клавиатуры параллельно
parallel.waitForAny(streamLoop, waitForKey)

-- Очистка видеокарты при закрытии
if gpu.stopGIF then pcall(gpu.stopGIF, display) end
pcall(gpu.removeDisplay, display)
print("Stopped.")
