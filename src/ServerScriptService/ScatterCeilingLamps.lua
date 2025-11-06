-- src/ServerScriptService/ScatterCeilingLamps.lua
-- CONVERTIDO A MODULESCRIPT
-- Es llamado por BackroomsGenerator y recibe el levelFolder
-- Lámparas centradas en el techo, 0/90/180/270°, sin chocar muros ni salirse del techo.
-- Etiqueta todas las luces con "AllowLight".

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local ScatterCeilingLamps = {}

-- ==================== CONFIG ====================
local LAMP_TEMPLATE_NAME = "Floor lamp"    -- plantilla a clonar (en Workspace o ReplicatedStorage)
local TEMPLATE_IN_REPLICATEDSTORAGE = false

local LEVEL_MODEL_NAME   = "Level0Model"
local TARGET_CEILING_NAME = "Ceiling"

local LAMP_COUNT = 50                       -- cuántas lámparas
local LAMP_OFFSET_FROM_CEILING = 0.5       -- separación desde cara inferior del techo (studs)
local LAMP_MIN_SPACING = 12                -- distancia mínima entre lámparas (centro a centro, XZ)
local LAMP_WALL_CLEARANCE = 1.5            -- separación mínima respecto a muros
local EDGE_MARGIN = 4                      -- margen mínimo con bordes del techo
local ROTATE_IN_90_STEPS = true            -- usar 0/90/180/270

local TAG_ALLOW_LIGHTS = true              -- etiqueta todos los Light con "AllowLight"
local OUTPUT_FOLDER_NAME = "CeilingLamps"  -- carpeta de salida (se limpia)
-- =================================================

-- (Se eliminaron el Singleton guard y la espera de LevelBuilt)

-- ============ Buscar techo y muros (MODIFICADO) ============
-- Ahora acepta el 'levelFolder' que le pasa el generador
local function findCeiling(levelFolder)
	if not levelFolder then return nil end
	
	local model = levelFolder:FindFirstChild(LEVEL_MODEL_NAME)
	if model then
		local p = model:FindFirstChild(TARGET_CEILING_NAME)
		if p and p:IsA("BasePart") then return p end
	end
	
	local p2 = levelFolder:FindFirstChild(TARGET_CEILING_NAME)
	if p2 and p2:IsA("BasePart") then return p2 end
	
	for _, d in ipairs(levelFolder:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == TARGET_CEILING_NAME then
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

-- ============ Plantilla ============
local lampTemplate
if TEMPLATE_IN_REPLICATEDSTORAGE then
	lampTemplate = ReplicatedStorage:FindFirstChild(LAMP_TEMPLATE_NAME, true)
else
	lampTemplate = workspace:FindFirstChild(LAMP_TEMPLATE_NAME, true)
end

-- Footprint base de la plantilla
local function getTemplateFootprintHalfXZ()
	if not lampTemplate then return 0, 0 end
	local size = lampTemplate:GetExtentsSize()
	return size.X * 0.5, size.Z * 0.5
end
local baseHX, baseHZ = getTemplateFootprintHalfXZ()

-- ============ Utils ============
local function tagAllLightsDeep(root)
	if not TAG_ALLOW_LIGHTS then return end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			if not CollectionService:HasTag(d, "AllowLight") then
				CollectionService:AddTag(d, "AllowLight")
			end
		end
	end
end

local function cloneLamp(outFolder)
	local clone = lampTemplate:Clone()
	clone.Parent = outFolder
	if clone:IsA("Model") then
		for _, p in ipairs(clone:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true end
		end
	elseif clone:IsA("BasePart") then
		clone.Anchored = true
	end
	tagAllLightsDeep(clone)
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

local function footprintHalfForYaw(yawStep)
	local swap = (yawStep % 2 == 1) -- 90 o 270
	local hx, hz = baseHX, baseHZ
	if swap then hx, hz = baseHZ, baseHX end
	return hx, hz
end

-- ============ FUNCIÓN PRINCIPAL DEL MÓDULO ============
function ScatterCeilingLamps.Run(levelFolder)
	
	print("[ScatterCeilingLamps] Módulo 'Run' llamado.")
	
	if not lampTemplate then
		warn(("[ScatterCeilingLamps] No se encontró la plantilla '%s'. Saliendo."):format(LAMP_TEMPLATE_NAME))
		return
	end

	-- ============ Buscar techo y muros (MODIFICADO) ============
	local ceiling = findCeiling(levelFolder) -- Usa el levelFolder
	if not ceiling then
		warn(("[ScatterCeilingLamps] No se encontró el techo '%s'. Saliendo."):format(TARGET_CEILING_NAME))
		return
	end

	local wallsRoot = levelFolder and (levelFolder:FindFirstChild(LEVEL_MODEL_NAME) or levelFolder) or workspace
	local wallRects = getWallsRectsXZ(wallsRoot)


	-- ============ Parent destino (MODIFICADO) ============
	local parentLevel = levelFolder or workspace -- Usa el levelFolder
	local outFolder = parentLevel:FindFirstChild(OUTPUT_FOLDER_NAME)
	if not outFolder then
		outFolder = Instance.new("Folder")
		outFolder.Name = OUTPUT_FOLDER_NAME
		outFolder.Parent = parentLevel
	else
		outFolder:ClearAllChildren()
	end


	-- ============ Área del techo ============
	local size = ceiling.Size
	local halfX, halfZ = size.X * 0.5, size.Z * 0.5
	local ceilCF = ceiling.CFrame

	local minX, maxX = -halfX, halfX
	local minZ, maxZ = -halfZ, halfZ

	local targetY = (ceiling.CFrame.Position.Y - (ceiling.Size.Y * 0.5)) - LAMP_OFFSET_FROM_CEILING
	local BASE_EDGE_MARGIN = math.max(EDGE_MARGIN, LAMP_MIN_SPACING * 0.5)

	-- ============ Muestreo sin gotos ============
	local rng = Random.new()
	local placed = 0
	local placedRects = {}
	local tries = math.max(LAMP_COUNT * 50, 100)

	while placed < LAMP_COUNT and tries > 0 do
		tries -= 1

		local yawStep = ROTATE_IN_90_STEPS and rng:NextInteger(0, 3) or 0
		local hx, hz = footprintHalfForYaw(yawStep)

		-- muestreamos respetando margen y footprint
		local x = rng:NextNumber(minX + BASE_EDGE_MARGIN + hx, maxX - BASE_EDGE_MARGIN - hx)
		local z = rng:NextNumber(minZ + BASE_EDGE_MARGIN + hz, maxZ - BASE_EDGE_MARGIN - hz)

		-- a mundo (debajo del techo, centrado en Y)
		local worldPos = (ceilCF * CFrame.new(x, -ceiling.Size.Y * 0.5 - LAMP_OFFSET_FROM_CEILING, z)).Position
		worldPos = Vector3.new(worldPos.X, targetY, worldPos.Z)

		local lampRect = { cx = worldPos.X, cz = worldPos.Z, hx = hx, hz = hz }

		-- validaciones
		local ok = true

		-- 1) separación entre lámparas
		if ok then
			for _, r in ipairs(placedRects) do
				if rectsOverlapXZ(lampRect, r, LAMP_MIN_SPACING * 0.5) then ok = false; break end
			end
		end

		-- 2) no chocar con muros
		if ok then
			for _, wr in ipairs(wallRects) do
				if rectsOverlapXZ(lampRect, wr, LAMP_WALL_CLEARANCE) then ok = false; break end
			end
		end

		-- 3) dentro del área útil del techo (por seguridad extra)
		if ok then
			if (x - hx) < (minX + EDGE_MARGIN) or (x + hx) > (maxX - EDGE_MARGIN)
				or (z - hz) < (minZ + EDGE_MARGIN) or (z + hz) > (maxZ - EDGE_MARGIN) then
				ok = false
			end
		end

		if ok then
			-- ¡Colocar!
			local lamp = cloneLamp(outFolder)
			local yaw = math.rad(90 * yawStep)
			pivotTo(CFrame.new(worldPos) * CFrame.Angles(0, yaw, 0), lamp)

			table.insert(placedRects, lampRect)
			placed += 1
		end
		-- si no está ok, simplemente sigue al siguiente intento
	end

	print(string.format("[ScatterCeilingLamps] Colocadas %d lámparas (solicitadas %d).", placed, LAMP_COUNT))

	-- ============ LÍNEAS CORREGIDAS (Llamada al SceneController) ============
	print("[ScatterCeilingLamps] Llamando al SceneController...")
	
	-- Asumiendo que SceneController también es un ModuleScript en la misma carpeta
	local success, sc = pcall(function()
		return require(script.Parent:WaitForChild("SceneController"))
	end)
	
	if success and sc then
		sc.StartTimeline()
	else
		warn("[ScatterCeilingLamps] No se pudo encontrar o requerir 'SceneController'.")
	end
	
end

return ScatterCeilingLamps