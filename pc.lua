local gpu = peripheral.find("directgpu")
if not gpu then error("No directgpu peripheral found") end

-- Твой IP из логов и порт 8089. В конце СЛЭШ НЕ НУЖЕН
local baseUrl = "http://26.222.210.23:8089" 
local fps = 11
local scale = 2 

local display = gpu.autoDetectAndCreateDisplayWithResolution(scale)
if not display or display == -1 then error("Failed to create display.") end
local info = gpu.getDisplayInfo(display)
local w, h = info.pixelWidth, info.pixelHeight

print("Getting file size...")
local sizeResponse = http.get(baseUrl .. "/size") 
if not sizeResponse then error("Can't connect to server") end
local totalSize = tonumber(sizeResponse.readAll())
sizeResponse.close()

if not totalSize then error("Failed to parse file size from server") end
print("Total GIF size: " .. totalSize .. " bytes")

local fullData = {}
local currentOffset = 0

while currentOffset < totalSize do
    print(string.format("Downloading chunk: %d / %d KB", currentOffset / 1024, totalSize / 1024))
    
    -- Запрос чанка
    local url = baseUrl .. "/chunk?offset=" .. currentOffset
    local response, err = http.get(url, nil, true)
    
    if not response then
        gpu.removeDisplay(display)
        error("Chunk error at " .. currentOffset .. ": " .. tostring(err))
    end
    
    local chunk = response.readAll()
    response.close()
    
    if chunk and #chunk > 0 then
        table.insert(fullData, chunk)
        currentOffset = currentOffset + #chunk
    else
        break
    end
    
    os.sleep(0.05)
end

print("Assembling in RAM...")
local gif = table.concat(fullData)
print("Playing...")

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
