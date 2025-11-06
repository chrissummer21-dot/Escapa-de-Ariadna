-- src/ServerScriptService/ScatterFlashlights.lua
-- VERSIÓN SIMPLE: Solo distribuye las herramientas.
-- No añade lógica de pickup, deja que la herramienta se encargue.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- ==================== CONFIG ====================
local TOOL_TEMPLATE_NAME = "Flashlight"
local TEMPLATE_IN_REPLICATEDSTORAGE = true

local LEVEL_FOLDER_NAME = "Level0"
local LEVEL_MODEL_NAME = "Level0Model"
local TARGET_FLOOR_NAME = "Floor" 

local ITEM_COUNT = 4 
local FLOAT_ABOVE_FLOOR = 3.0 -- A qué altura aparecen (antes de caer)
local ITEM_MIN_SPACING = 20 
local ITEM_WALL_CLEARANCE = 2 
local EDGE_MARGIN = 5 
local ROTATE_IN_90_STEPS = true

local OUTPUT_FOLDER_NAME = "WorldTools"
-- =================================================

-- Crear el Módulo
local ScatterFlashlights = {}

-- ============ Buscar Suelo y Muros ============
local function findFloor()
	local level0 = workspace:FindFirstChild(LEVEL_FOLDER_NAME)
	if level0 then
		local model = level0:FindFirstChild(LEVEL_MODEL_NAME)
		if model then
			local p = model:FindFirstChild(TARGET_FLOOR_NAME)
			if p and p:IsA("BasePart") then return p end
		end
		local p2 = level0:FindFirstChild(TARGET_FLOOR_NAME)
		if p2 and p2:IsA("BasePart") then return p2 end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == TARGET_FLOOR_NAME then
			return d
		end
	end
	return nil
end

local function getWallsRectsXZ(root)
	local rects = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Wall" then
			local cf = d.CFrame
			local sz = d.Size
			table.insert(rects, {
				cx = cf.Position.X,
				cz = cf.Position.Z,
				hx = sz.X * 0.5,
				hz = sz.Z * 0.5,
			})
		end
	end
	return rects
end

-- ============ Utils (VERSIÓN SÚPER SIMPLE) ============
local function cloneTool(toolTemplate)
	local clone = toolTemplate:Clone()
	local handle = clone:FindFirstChild("Handle")
	
	if not (handle and handle:IsA("BasePart")) then
		warn("[ScatterFlashlights] ADVERTENCIA: Plantilla 'Flashlight' no tiene un 'Handle' (BasePart).")
		return clone
	end
	
	-- Configurar la linterna
	handle.Anchored = false -- ¡NO ANCLADO! Dejará que la física y el pickup de Roblox funcionen.
	handle.CanCollide = true  -- Default para herramientas.

	-- Apagar la luz de la linterna
	local spotLight = handle:FindFirstChildOfClass("SpotLight")
	if spotLight then
		spotLight.Enabled = false
	end

	-- ¡SIN LÓGICA DE .TOUCHED!
	-- ¡SIN LÓGICA DE MOCHILA!
	-- ¡SIN LÓGICA DE CanCollide=false!

	return clone
end

-- (Las funciones pivotTo, rectsOverlapXZ, y footprintHalfForYaw no cambian)
local function pivotTo(cf, modelOrPart)
	if modelOrPart:IsA("Model") then
		modelOrPart:PivotTo(cf)
	else
		modelOrPart.CFrame = cf
	end
end

local function rectsOverlapXZ(a, b, extra)
	extra = extra or 0
	return (math.abs(a.cx - b.cx) <= (a.hx + b.hx + extra))
		and (math.abs(a.cz - b.cz) <= (a.hz + b.hz + extra))
end

local function footprintHalfForYaw(baseHX, baseHZ, yawStep)
	local swap = (yawStep % 2 == 1) -- 90 o 270
	local hx, hz = baseHX, baseHZ
	if swap then hx, hz = baseHZ, baseHX end
	return hx, hz
end

-- ============ FUNCIÓN PRINCIPAL DEL MÓDULO ============
function ScatterFlashlights.Run()
	print("[ScatterFlashlights] Módulo ejecutado (Run).")

	-- 1. Buscar Suelo y Muros
	local floor = findFloor()
	if not floor then
		warn(("[ScatterFlashlights] ¡FALLO! No se encontró el suelo '%s'. Saliendo."):format(TARGET_FLOOR_NAME))
		return
	end
	
	local level0 = workspace:FindFirstChild(LEVEL_FOLDER_NAME)
	local wallsRoot = level0 and (level0:FindFirstChild(LEVEL_MODEL_NAME) or level0) or workspace
	local wallRects = getWallsRectsXZ(wallsRoot)

	-- 2. Plantilla
	local toolTemplate
	if TEMPLATE_IN_REPLICATEDSTORAGE then
		toolTemplate = ReplicatedStorage:FindFirstChild(TOOL_TEMPLATE_NAME, true)
	else
		toolTemplate = workspace:FindFirstChild(TOOL_TEMPLATE_NAME, true)
	end
	if not toolTemplate then
		warn(("[ScatterFlashlights] ¡FALLO! No se encontró la plantilla de herramienta '%s' en ReplicatedStorage. Saliendo."):format(TOOL_TEMPLATE_NAME))
		return
	end

	-- 3. Footprint base (Función interna)
	local function getTemplateFootprintHalfXZ()
		local handle = toolTemplate:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			local size = handle.Size
			return size.X * 0.5, size.Z * 0.5
		end
		warn("[ScatterFlashlights] ADVERTENCIA: No se encontró 'Handle' en la plantilla. Usando footprint 1x1.")
		return 1, 1 -- fallback
	end
	local baseHX, baseHZ = getTemplateFootprintHalfXZ()

	-- 4. Parent destino
	local parentLevel = workspace:FindFirstChild(LEVEL_FOLDER_NAME) or workspace
	local outFolder = parentLevel:FindFirstChild(OUTPUT_FOLDER_NAME)
	if not outFolder then
		outFolder = Instance.new("Folder")
		outFolder.Name = OUTPUT_FOLDER_NAME
		outFolder.Parent = parentLevel
	else
		outFolder:ClearAllChildren()
	end

	-- 5. Área del Suelo
	local size = floor.Size
	local halfX, halfZ = size.X * 0.5, size.Z * 0.5
	local floorCF = floor.CFrame

	local minX, maxX = -halfX, halfX
	local minZ, maxZ = -halfZ, halfZ

	local targetY = (floor.CFrame.Position.Y + (floor.Size.Y * 0.5)) + FLOAT_ABOVE_FLOOR
	local BASE_EDGE_MARGIN = math.max(EDGE_MARGIN, ITEM_MIN_SPACING * 0.5)

	-- 6. Muestreo (Spawning)
	local rng = Random.new()
	local placed = 0
	local placedRects = {}
	local tries = math.max(ITEM_COUNT * 50, 100)

	while placed < ITEM_COUNT and tries > 0 do
		tries -= 1

		local yawStep = ROTATE_IN_90_STEPS and rng:NextInteger(0, 3) or 0
		local hx, hz = footprintHalfForYaw(baseHX, baseHZ, yawStep)

		if not hx or not hz or not minX or not maxX or not minZ or not maxZ then
			warn("[ScatterFlashlights] ¡Error crítico! Faltan datos de tamaño. Saliendo del bucle.")
			break
		end
		
		local minBoundX = minX + BASE_EDGE_MARGIN + hx
		local maxBoundX = maxX - BASE_EDGE_MARGIN - hx
		local minBoundZ = minZ + BASE_EDGE_MARGIN + hz
		local maxBoundZ = maxZ - BASE_EDGE_MARGIN - hz

		if minBoundX >= maxBoundX or minBoundZ >= maxBoundZ then
			warn("[ScatterFlashlights] ADVERTENCIA: El área de spawn es demasiado pequeña para los márgenes. No se pueden colocar más items.")
			break 
		end

		local x = rng:NextNumber(minBoundX, maxBoundX)
		local z = rng:NextNumber(minBoundZ, maxBoundZ)

		local worldPos = (floorCF * CFrame.new(x, (floor.Size.Y * 0.5) + FLOAT_ABOVE_FLOOR, z)).Position
		worldPos = Vector3.new(worldPos.X, targetY, worldPos.Z)

		local itemRect = { cx = worldPos.X, cz = worldPos.Z, hx = hx, hz = hz }

		local ok = true
		for _, r in ipairs(placedRects) do
			if rectsOverlapXZ(itemRect, r, ITEM_MIN_SPACING * 0.5) then ok = false; break end
		end
		if ok then
			for _, wr in ipairs(wallRects) do
				if rectsOverlapXZ(itemRect, wr, ITEM_WALL_CLEARANCE) then ok = false; break end
			end
		end

		if ok then
			-- ¡Colocar!
			local tool = cloneTool(toolTemplate)
			local yaw = math.rad(90 * yawStep)
			
			-- Usamos PivotTo (o CFrame) para posicionar la herramienta ANTES de que caiga.
			pivotTo(CFrame.new(worldPos) * CFrame.Angles(0, yaw, 0), tool)
			tool.Parent = outFolder -- Ponerla en el mundo

			table.insert(placedRects, itemRect)
			placed += 1
		end
		
		if tries % 100 == 0 then
			task.wait() 
		end
	end

	print(string.format("[ScatterFlashlights] Colocadas %d linternas (solicitadas %d).", placed, ITEM_COUNT))
end

-- Devolver el módulo
return ScatterFlashlights