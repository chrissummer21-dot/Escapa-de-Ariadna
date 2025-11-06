-- StarterPlayerScripts/FlashlightTracker.client.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- Crea la UI básica
local function ensureGui()
	local pg = player:WaitForChild("PlayerGui")
	local gui = pg:FindFirstChild("FlashlightHUD")
	if gui then return gui end

	gui = Instance.new("ScreenGui")
	gui.Name = "FlashlightHUD"
	gui.ResetOnSpawn = false
	gui.Parent = pg

	local frame = Instance.new("Frame")
	frame.Name = "Container"
	frame.Size = UDim2.new(0, 260, 0, 160)
	frame.Position = UDim2.new(1, -270, 0, 80) -- esquina superior derecha
	frame.BackgroundTransparency = 0.2
	frame.BackgroundColor3 = Color3.fromRGB(20,20,20)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -10, 0, 24)
	title.Position = UDim2.new(0, 10, 0, 6)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.new(1,1,1)
	title.Text = "Linternas (ID / Batería)"
	title.Parent = frame

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, -10, 1, -40)
	list.Position = UDim2.new(0, 10, 0, 34)
	list.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	return gui
end

local gui = ensureGui()
local list = gui.Container.List

-- Diccionario de entradas por Id
local entries = {}

local function shortId(id)
	-- retorna últimos 6 caracteres para mostrar corto
	if typeof(id) == "string" and #id >= 6 then
		return string.sub(id, #id-5)
	end
	return tostring(id)
end

local function createEntry(tool)
	local id = tool:GetAttribute("Id")
	local maxB = tool:GetAttribute("MaxBattery") or 100
	if not id then return end
	if entries[id] then return end

	local item = Instance.new("Frame")
	item.Name = id
	item.Size = UDim2.new(1, 0, 0, 24)
	item.BackgroundTransparency = 0.3
	item.BackgroundColor3 = Color3.fromRGB(35,35,35)
	item.BorderSizePixel = 0
	item.Parent = list

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -10, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.new(1,1,1)
	label.Text = string.format("...  |  ...%%")
	label.Parent = item

	local function refresh()
		local b = tool:GetAttribute("Battery") or 0
		label.Text = string.format("%s  |  %d%%", shortId(id), math.floor((b / (maxB > 0 and maxB or 100)) * 100 + 0.5))
	end

	-- Suscribirse a cambios
	local conn = tool:GetAttributeChangedSignal("Battery"):Connect(refresh)

	-- Guardar
	entries[id] = {frame = item, conn = conn, tool = tool, refresh = refresh}
	refresh()
end

local function removeEntryById(id)
	local e = entries[id]
	if not e then return end
	if e.conn then e.conn:Disconnect() end
	if e.frame then e.frame:Destroy() end
	entries[id] = nil
end

local function trackTool(tool)
	-- Sólo linternas
	if not tool:GetAttribute("IsFlashlight") then return end
	if not tool:GetAttribute("Id") then return end
	createEntry(tool)

	-- Limpieza al destruir
	tool.Destroying:Connect(function()
		local id = tool:GetAttribute("Id")
		if id then removeEntryById(id) end
	end)
end

-- Escanear al inicio
local function scanAll()
	-- Backpack
	local bp = player:WaitForChild("Backpack")
	for _, t in ipairs(bp:GetChildren()) do
		if t:IsA("Tool") then trackTool(t) end
	end
	-- Equipadas en Character
	local char = player.Character or player.CharacterAdded:Wait()
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") then trackTool(t) end
	end
end

scanAll()

-- Eventos para nuevas herramientas
local bp = player:WaitForChild("Backpack")
bp.ChildAdded:Connect(function(ch)
	if ch:IsA("Tool") then task.defer(trackTool, ch) end
end)
bp.ChildRemoved:Connect(function(ch)
	if ch:IsA("Tool") then
		local id = ch:GetAttribute("Id")
		if id then removeEntryById(id) end
	end
end)

player.CharacterAdded:Connect(function(char)
	-- Cuando respawnea, volver a listar
	task.wait(0.5)
	scanAll()
end)
