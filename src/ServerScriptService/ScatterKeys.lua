-- src/ServerScriptService/ScatterKeys.lua
-- Spawnea una cantidad específica de llaves en el suelo del laberinto.
-- Es una copia modificada de ScatterFlashlights.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- ==================== CONFIG ====================
local TOOL_TEMPLATE_NAME = "Key" -- ¡IMPORTANTE! Debe existir una Tool llamada "Key"
local TEMPLATE_IN_REPLICATEDSTORAGE = true

local LEVEL_FOLDER_NAME = "Level0"
local LEVEL_MODEL_NAME = "Level0Model"
local TARGET_FLOOR_NAME = "Floor" 

-- (La cantidad se pasa ahora como argumento en la función Run)

local FLOAT_ABOVE_FLOOR = 2.5 -- Altura a la que spawnea (ligeramente diferente a las linternas)
local ITEM_MIN_SPACING = 100 
local ITEM_WALL_CLEARANCE = 2 
local EDGE_MARGIN = 5 
local ROTATE_IN_90_STEPS = false -- Las llaves no necesitan rotación aleatoria

local OUTPUT_FOLDER_NAME = "WorldTools" -- Las ponemos en la misma carpeta que las linternas
-- =================================================

-- Crear el Módulo
local ScatterKeys = {}

-- ============ Buscar Suelo y Muros ============
-- (Estas funciones auxiliares son idénticas a ScatterFlashlights)
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
		warn("[ScatterKeys] ADVERTENCIA: Plantilla 'Key' no tiene un 'Handle' (BasePart).")
		return clone
	end
	
	handle.Anchored = false -- Dejar que la física de Roblox funcione
	handle.CanCollide = true

	return clone
end

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
	local swap = (yawStep % 2 == 1) and ROTATE_IN_90_STEPS
	local hx, hz = baseHX, baseHZ
	if swap then hx, hz = baseHZ, baseHX end
	return hx, hz
end

-- ============ FUNCIÓN PRINCIPAL DEL MÓDULO ============
-- Modificada para aceptar la cantidad de llaves como argumento
function ScatterKeys.Run(countToSpawn)
	
	local ITEM_COUNT = countToSpawn or 3 -- Si no se especifica, spawnea 3 por defecto
	print(string.format("[ScatterKeys] Módulo ejecutado (Run). Spawneando %d llaves.", ITEM_COUNT))

	-- 1. Buscar Suelo y Muros
	local floor = findFloor()
	if not floor then
		warn(("[ScatterKeys] ¡FALLO! No se encontró el suelo '%s'. Saliendo."):format(TARGET_FLOOR_NAME))
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
		warn(("[ScatterKeys] ¡FALLO! No se encontró la plantilla de herramienta '%s' en ReplicatedStorage. Saliendo."):format(TOOL_TEMPLATE_NAME))
		return
	end

	-- 3. Footprint base
	local function getTemplateFootprintHalfXZ()
		local handle = toolTemplate:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			local size = handle.Size
			return size.X * 0.5, size.Z * 0.5
		end
		warn("[ScatterKeys] ADVERTENCIA: No se encontró 'Handle' en la plantilla. Usando footprint 1x1.")
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
			warn("[ScatterKeys] ¡Error crítico! Faltan datos de tamaño. Saliendo del bucle.")
			break
		end
		
		local minBoundX = minX + BASE_EDGE_MARGIN + hx
		local maxBoundX = maxX - BASE_EDGE_MARGIN - hx
		local minBoundZ = minZ + BASE_EDGE_MARGIN + hz
		local maxBoundZ = maxZ - BASE_EDGE_MARGIN - hz

		if minBoundX >= maxBoundX or minBoundZ >= maxBoundZ then
			warn("[ScatterKeys] ADVERTENCIA: El área de spawn es demasiado pequeña para los márgenes. No se pueden colocar más items.")
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
			local tool = cloneTool(toolTemplate)
			local yaw = math.rad(90 * yawStep)
			pivotTo(CFrame.new(worldPos) * CFrame.Angles(0, yaw, 0), tool)
			tool.Parent = outFolder -- Ponerla en el mundo

			table.insert(placedRects, itemRect)
			placed += 1
		end
		
		if tries % 100 == 0 then
			task.wait() 
		end
	end

	print(string.format("[ScatterKeys] Colocadas %d llaves (solicitadas %d).", placed, ITEM_COUNT))
end

-- Devolver el módulo
return ScatterKeys