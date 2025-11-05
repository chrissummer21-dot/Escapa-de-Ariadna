-- ServerScriptService/ScatterCeilingLamps.server.lua
-- Lámparas centradas en el techo, 0/90/180/270°, sin chocar muros ni salirse del techo.
-- Etiqueta todas las luces con "AllowLight". Singleton guard + carpeta propia.

local RunService = game:GetService("RunService")
if RunService:IsClient() then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- ==================== CONFIG ====================
local LAMP_TEMPLATE_NAME = "Floor lamp"    -- plantilla a clonar (en Workspace o ReplicatedStorage)
local TEMPLATE_IN_REPLICATEDSTORAGE = false

local LEVEL_FOLDER_NAME  = "Level0"
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
local WAIT_TIMEOUT_SECONDS = 5
-- =================================================

-- ============ Singleton guard ============
local flags = ReplicatedStorage:FindFirstChild("BackroomsFlags")
if not flags then
	flags = Instance.new("Folder")
	flags.Name = "BackroomsFlags"
	flags.Parent = ReplicatedStorage
end
if flags:FindFirstChild("ScatterLampsRan") then
	warn("[ScatterCeilingLamps] Ya corrió esta sesión; saliendo para evitar duplicados.")
	return
else
	local marker = Instance.new("BoolValue")
	marker.Name = "ScatterLampsRan"
	marker.Value = true
	marker.Parent = flags
end

-- ============ Señal opcional: LevelBuilt ============
local function waitForLevelBuiltSignal(timeout)
	local signals = ReplicatedStorage:FindFirstChild("BackroomsSignals")
	if not signals then return false end
	local evt = signals:FindFirstChild("LevelBuilt")
	if not evt or not evt:IsA("BindableEvent") then return false end
	local fired = false
	evt.Event:Connect(function() fired = true end)
	local t0 = os.clock()
	while not fired and (os.clock() - t0) < (timeout or WAIT_TIMEOUT_SECONDS) do
		task.wait(0.1)
	end
	return fired
end

-- ============ Buscar techo y muros ============
local function findCeiling()
	local level0 = workspace:FindFirstChild(LEVEL_FOLDER_NAME)
	if level0 then
		local model = level0:FindFirstChild(LEVEL_MODEL_NAME)
		if model then
			local p = model:FindFirstChild(TARGET_CEILING_NAME)
			if p and p:IsA("BasePart") then return p end
		end
		local p2 = level0:FindFirstChild(TARGET_CEILING_NAME)
		if p2 and p2:IsA("BasePart") then return p2 end
		for _, d in ipairs(level0:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == TARGET_CEILING_NAME then
				return d
			end
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
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

-- Espera señal y/o techo
waitForLevelBuiltSignal(WAIT_TIMEOUT_SECONDS * 0.5)
local function waitForCeiling(timeout)
	local t0 = os.clock()
	while (os.clock() - t0) < (timeout or WAIT_TIMEOUT_SECONDS) do
		local c = findCeiling()
		if c then return c end
		task.wait(0.2)
	end
	return nil
end

local ceiling = waitForCeiling(WAIT_TIMEOUT_SECONDS)
if not ceiling then
	warn(("[ScatterCeilingLamps] No se encontró el techo '%s'."):format(TARGET_CEILING_NAME))
	return
end

local level0 = workspace:FindFirstChild(LEVEL_FOLDER_NAME)
local wallsRoot = level0 and (level0:FindFirstChild(LEVEL_MODEL_NAME) or level0) or workspace
local wallRects = getWallsRectsXZ(wallsRoot)

-- ============ Plantilla ============
local lampTemplate
if TEMPLATE_IN_REPLICATEDSTORAGE then
	lampTemplate = ReplicatedStorage:FindFirstChild(LAMP_TEMPLATE_NAME, true)
else
	lampTemplate = workspace:FindFirstChild(LAMP_TEMPLATE_NAME, true)
end
if not lampTemplate then
	warn(("[ScatterCeilingLamps] No se encontró la plantilla '%s'."):format(LAMP_TEMPLATE_NAME))
	return
end

-- Footprint base de la plantilla
local function getTemplateFootprintHalfXZ()
	local size = lampTemplate:GetExtentsSize()
	return size.X * 0.5, size.Z * 0.5
end
local baseHX, baseHZ = getTemplateFootprintHalfXZ()

-- ============ Parent destino ============
local parentLevel = workspace:FindFirstChild(LEVEL_FOLDER_NAME) or workspace
local outFolder = parentLevel:FindFirstChild(OUTPUT_FOLDER_NAME)
if not outFolder then
	outFolder = Instance.new("Folder")
	outFolder.Name = OUTPUT_FOLDER_NAME
	outFolder.Parent = parentLevel
else
	outFolder:ClearAllChildren()
end

-- ============ Utils ============
local function tagAllLightsDeep(root)
	if not TAG_ALLOW_LIGHTS then return end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			if not CollectionService:HasTag(d, "AllowLight") then
				CollectionService:AddTag(d, "AllowLight")
			end
			d.Enabled = true
		end
	end
end

local function cloneLamp()
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
		local lamp = cloneLamp()
		local yaw = math.rad(90 * yawStep)
		pivotTo(CFrame.new(worldPos) * CFrame.Angles(0, yaw, 0), lamp)

		table.insert(placedRects, lampRect)
		placed += 1
	end
	-- si no está ok, simplemente sigue al siguiente intento
end

print(string.format("[ScatterCeilingLamps] Colocadas %d lámparas (solicitadas %d).", placed, LAMP_COUNT))
