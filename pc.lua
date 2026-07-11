local gpu = peripheral.find("directgpu")
if not gpu then error("No directgpu peripheral found") end

local server_url = "http://26.249.231.240:8080/frame/"
local scale = 2 -- Масштаб пикселей
local fps = 20  -- Желаемый FPS для стрима

-- Автоматически создаем дисплей
local display = gpu.autoDetectAndCreateDisplayWithResolution(scale)
if not display or display == -1 then
    error("Failed to create display. Check your monitor and modem cords.")
end

local info = gpu.getDisplayInfo(display)
local w = info.pixelWidth
local h = info.pixelHeight

print("Display connected: " .. w .. "x" .. h)
print("Starting live HTTP stream... Press any key to stop.")

local frame_idx = 0
local is_running = true

-- Функция отрисовки стрима
local function streamLoop()
    while is_running do
        local response = http.get(server_url .. tostring(frame_idx), nil, true)
        
        if response then
            -- Читаем байты кадра напрямую в оперативную память Lua
            local raw_bytes = response.readAll()
            response.close()
            
            -- Отправляем байты сразу в GPU, проверяя доступные методы
            pcall(function()
                if gpu.loadGIFRegionBytes then
                    gpu.loadGIFRegionBytes(display, raw_bytes, 0, 0, w, h, fps)
                elseif gpu.loadGIFRegion then
                    gpu.loadGIFRegion(display, raw_bytes, 0, 0, w, h, fps)
                else
                    -- Для однокадрового GIF индекс кадра = 0
                    gpu.loadGIFFrame(display, raw_bytes, 0, 0, 0, w, h)
                end
            end)
            
            gpu.updateDisplay(display)
            frame_idx = frame_idx + 1
        else
            -- Кадры закончились, начинаем сначала
            frame_idx = 0
        end
        
        os.sleep(1 / fps)
    end
end

-- Функция ожидания нажатия клавиши для выхода
local function waitForKey()
    os.pullEvent("key")
    is_running = false
end

-- Запускаем стриминг и отслеживание клавиатуры параллельно
parallel.waitForAny(streamLoop, waitForKey)

-- Корректная очистка при выходе
if gpu.stopGIF then pcall(gpu.stopGIF, display) end
pcall(gpu.removeDisplay, display)
print("Stream stopped. Display removed.")
