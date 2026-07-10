local gpu = peripheral.find("directgpu")
if not gpu then error("No directgpu peripheral found") end
 
-- Настройки сети и файла
local url = "http://26.249.231.240:8089/am.gif" -- Укажите ваш IP и порт
local fps = 11
local scale = 2 
 
-- Размер одного чанка в байтах (1 МБ = 1048576 байт)
-- Оптимально для CC:Tweaked, чтобы не спамить запросами и не превышать лимит
local chunkSize = 1024 * 1024 
 
-- Автоматически создаем дисплей
local display = gpu.autoDetectAndCreateDisplayWithResolution(scale)
if not display or display == -1 then
    error("Failed to create display.")
end
 
local info = gpu.getDisplayInfo(display)
local w, h = info.pixelWidth, info.pixelHeight
 
print("Display connected: " .. w .. "x" .. h)
print("Downloading " .. url .. " via chunking...")
 
-- Функция для скачивания файла частями
local function downloadLargeFile(fileUrl)
    local fullData = {}
    local startByte = 0
    local isFinished = false
 
    while not isFinished do
        local endByte = startByte + chunkSize - 1
        -- Формируем заголовок Range для запроса конкретного куска файла
        local headers = {
            ["Range"] = string.format("bytes=%d-%d", startByte, endByte)
        }
 
        -- Третий аргумент true включает бинарный режим чтения
        local response, err = http.get(fileUrl, headers, true)
 
        if not response then
            error("Chunk download failed at byte " .. startByte .. ": " .. tostring(err))
        end
 
        -- Читаем текущий чанк
        local chunk = response.readAll()
        local responseHeaders = response.getResponseCode()
        response.close()
 
        if chunk and #chunk > 0 then
            table.insert(fullData, chunk)
 
            -- Если код ответа 206 (Partial Content), значит файл еще не кончился
            -- Если код 200, значит сервер проигнорировал Range и прислал файл целиком
            if responseHeaders == 200 then
                print("Server doesn't support Range. Downloaded full file.")
                return chunk
            end
 
            print(string.format("Downloaded chunk: %d - %d bytes", startByte, startByte + #chunk - 1))
            startByte = startByte + #chunk
        else
            isFinished = true
        end
 
        -- Короткая пауза, чтобы CC не ругался на слишком долгую работу без перерыва (Too long without yielding)
        os.sleep(0.05)
    end
 
    -- Собираем все чанки в одну бинарную строку
    return table.concat(fullData)
end
 
-- Запускаем потоковое скачивание
local success, gif = pcall(downloadLargeFile, url)
if not success then
    gpu.removeDisplay(display)
    error("Download error: " .. tostring(gif))
end
 
print("Total size in memory: " .. #gif .. " bytes. Starting playback...")
 
-- Запуск анимации
local ok, err = pcall(function()
    if gpu.loadGIFRegionBytes then
        return gpu.loadGIFRegionBytes(display, gif, 0, 0, w, h, fps)
    elseif gpu.loadGIFRegion then
        return gpu.loadGIFRegion(display, gif, 0, 0, w, h, fps)
    elseif gpu.loadGIFFullscreen then
        return gpu.loadGIFFullscreen(display, gif, fps)
    else
        return gpu.loadGIFFrame(display, gif, 0, 0, 0, w, h)
    end
end)
 
if not ok then
    print("GIF start failed:", err)
    gpu.removeDisplay(display)
    return
end
 
gpu.updateDisplay(display)
 
print("Press any key to stop.")
os.pullEvent("key")
 
if gpu.stopGIF then pcall(gpu.stopGIF, display) end
pcall(gpu.removeDisplay, display)
print("Stopped")
