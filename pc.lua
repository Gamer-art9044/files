local gpu = peripheral.find("directgpu")
if not gpu then error("No directgpu peripheral found") end

local baseUrl = "http://26.249.231.240:8089" 
local scale = 2 

local display = gpu.autoDetectAndCreateDisplayWithResolution(scale)
if not display or display == -1 then error("Failed to create display.") end
local info = gpu.getDisplayInfo(display)
local w, h = info.pixelWidth, info.pixelHeight

print("Display connected: " .. w .. "x" .. h)
print("Requesting video stream info...")

local infoResponse = http.get(baseUrl .. "/info")
if not infoResponse then error("Server unreachable") end
local meta = infoResponse.readAll()
infoResponse.close()

local totalFrames, videoFps = meta:match("([^,]+),([^,]+)")
totalFrames = tonumber(totalFrames)
local fps = tonumber(videoFps) or 20
local delay = 1 / fps

print(string.format("Video: %d frames @ %.2f FPS", totalFrames, fps))
print("Playing... Press 'q' to stop.")

local currentFrame = 0

-- Асинхронный цикл рендеринга
while true do
    -- Проверяем нажатие клавиши БЕЗ блокировки потока (через os.util / быстрый пул)
    local event, key = os.pullEventRaw()
    if event == "char" and key == "q" then
        pcall(gpu.removeDisplay, display)
        print("Stopped by user.")
        break
    end

    local url = baseUrl .. "/frame?num=" .. currentFrame
    
    -- Пытаемся скачать кадр
    local response = http.get(url, nil, true)
    
    if response then
        local frameData = response.readAll()
        response.close()
        
        pcall(function()
            gpu.loadGIFFrame(display, frameData, 0, 0, 0, w, h)
        end)
        gpu.updateDisplay(display)
        
        currentFrame = currentFrame + 1
    else
        -- Если у друга просел интернет — не виснем, а ждем чуть-чуть и пробуем снова
        print("Network lag, retrying frame " .. currentFrame)
        os.sleep(0.1)
    end

    -- Небольшая динамическая пауза, чтобы не спамить сервер, если пинг нулевой
    os.sleep(delay)
end
