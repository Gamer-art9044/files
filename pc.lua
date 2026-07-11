local gpu = peripheral.find("directgpu")
if not gpu then error("No directgpu peripheral found") end

local server_url = "http://26.249.231.240:8080/media/am.gif"
local fps = 11
local scale = 2

local display = gpu.autoDetectAndCreateDisplayWithResolution(scale)
if not display or display == -1 then
    error("Failed to create display. Check cords.")
end

local info = gpu.getDisplayInfo(display)
local w, h = info.pixelWidth, info.pixelHeight

print("Downloading GIF from server...")

-- Скачиваем медиа по сети в бинарном режиме
local response = http.get(server_url, nil, true)
if not response then
    error("Failed to connect to server")
end

local gif_bytes = response.readAll()
response.close()

print("Downloaded " .. #gif_bytes .. " bytes. Starting playback...")

local ok, err = pcall(function()
    if gpu.loadGIFRegionBytes then
        return gpu.loadGIFRegionBytes(display, gif_bytes, 0, 0, w, h, fps)
    elseif gpu.loadGIFFullscreen then
        return gpu.loadGIFFullscreen(display, gif_bytes, fps)
    else
        return gpu.loadGIFFrame(display, gif_bytes, 0, 0, 0, w, h)
    end
end)

if not ok then
    print("Playback error: " .. tostring(err))
else
    gpu.updateDisplay(display)
    print("Press any key to stop.")
    os.pullEvent("key")
end

-- Очистка
if gpu.stopGIF then pcall(gpu.stopGIF, display) end
pcall(gpu.removeDisplay, display)
print("Stopped")
