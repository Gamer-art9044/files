local gpu = peripheral.find("directgpu")
if not gpu then error("No directgpu peripheral found") end

local baseUrl = "http://26.249.231.240:8089" 
local fps = 11
local scale = 2 
local delay = 1 / fps

local display = gpu.autoDetectAndCreateDisplayWithResolution(scale)
if not display or display == -1 then error("Failed to create display.") end
local info = gpu.getDisplayInfo(display)
local w, h = info.pixelWidth, info.pixelHeight

print("Display connected: " .. w .. "x" .. h)
print("Requesting GIF info...")

-- Узнаем сколько всего кадров
local infoResponse = http.get(baseUrl .. "/info")
if not infoResponse then error("Server unreachable") end
local totalFrames = tonumber(infoResponse.readAll())
infoResponse.close()

print("Total frames to play: " .. totalFrames)
print("Playing... Press 'Ctrl+T' or any key to stop (if os.pullEvent is active).")

local currentFrame = 0

-- Запускаем таймер для удержания FPS
local timer = os.startTimer(delay)

while true do
    -- Качаем ОДИН кадр. Весит понт, качается мгновенно
    local url = baseUrl .. "/frame?num=" .. currentFrame
    local response = http.get(url, nil, true)'
    print("loading: " .. url)
    
    if response then
        local frameData = response.readAll()
        response.close()
        
        -- Рендерим кадр на экран через DirectGPU
        pcall(function()
            -- Передаем кадр. Номер кадра в самом моде ставим 0, так как шлем поодиночке
            gpu.loadGIFFrame(display, frameData, 0, 0, 0, w, h)
        end)
        gpu.updateDisplay(display)
    end
    
    currentFrame = currentFrame + 1
    
    -- Ждем события таймера, чтобы держать ровный FPS (и давать CC переводить дух)
    local event, id
    repeat
        event, id = os.pullEvent()
        if event == "key" then
            -- Если нажали клавишу - стопаем
            pcall(gpu.removeDisplay, display)
            print("Playback stopped by user.")
            return
        end
    until event == "timer"
    
    timer = os.startTimer(delay)
end
