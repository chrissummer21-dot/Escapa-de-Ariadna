-- src/ServerScriptService/BackroomsGenerator.server.lua
-- MODIFICADO A MODULESCRIPT
-- Ahora es llamado por GameManager y ajusta su tamaño
-- según el número de jugadores.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- ========= Módulos del Backroom =========
local ModulesFolder = ReplicatedStorage:WaitForChild("Modules")
local BackroomsFolder = ModulesFolder:WaitForChild("Backrooms")
local Walls = require(BackroomsFolder:WaitForChild("Walls"))
local Floor = require(BackroomsFolder:WaitForChild("Floor"))
local Ceiling = require(BackroomsFolder:WaitForChild("Ceiling"))
local Door = require(BackroomsFolder:WaitForChild("Door"))
local Util = require(BackroomsFolder:WaitForChild("Util"))
local Validate = require(BackroomsFolder:WaitForChild("Validate"))

-- ========= Señales =========
local Signals = ReplicatedStorage:FindFirstChild("BackroomsSignals")
if not Signals then
	Signals = Instance.new("Folder")
	Signals.Name = "BackroomsSignals"
	Signals.Parent = ReplicatedStorage
end
local OpenExit = Signals:FindFirstChild("OpenExit")
if not OpenExit then
	OpenExit = Instance.new("BindableEvent")
	OpenExit.Name = "OpenExit"
	OpenExit.Parent = Signals
end
local LevelBuilt = Signals:FindFirstChild("LevelBuilt")
if not LevelBuilt then
	LevelBuilt = Instance.new("BindableEvent")
	LevelBuilt.Name = "LevelBuilt"
	LevelBuilt.Parent = Signals
end

-- Crear el Módulo
local BackroomsGenerator = {}

-- LA FUNCIÓN PRINCIPAL AHORA ES LLAMADA POR EL GAMEMANAGER
function BackroomsGenerator.Generate(playerCount)
	
	print(string.format("[Generator] Recibida orden de generar para %d jugadores.", playerCount))

	-- ========= CONFIG DINÁMICA =========
	local CONFIG = {
		CELL_SIZE = Vector2.new(22, 22),
		WALL_HEIGHT = 12,
		WALL_THICK = 1,
		ORIGIN = Vector3.new(0, 6, 0),
		SEED = nil,
		EXTRA_LOOPS = 12,
		ADD_FLOOR = true, FLOOR_THICK = 1, FLOOR_COLOR = Color3.fromRGB(235,235,235),
		ADD_CEILING = true, CEILING_THICK = 1, CEILING_COLOR = Color3.fromRGB(235,235,235),
		MAKE_MODEL = true,
		HIDE_BASEPLATE = true,
		DOOR_WIDTH = 6, DOOR_HEIGHT = 12, DOOR_THICK = 1,
		
		-- ==== TAMAÑO DINÁMICO ====
		GRID_W = 10,
		GRID_H = 10,
		KEYS_REQUIRED = 3,
		EXTRA_KEYS = 1,
	}

	if playerCount <= 2 then
		-- Tamaño base (10x10 = 100 celdas)
		CONFIG.GRID_W = 10
		CONFIG.GRID_H = 10
		CONFIG.KEYS_REQUIRED = 3
	elseif playerCount <= 8 then
		-- Tamaño doble (aprox. 14x14 = 196 celdas)
		CONFIG.GRID_W = 14
		CONFIG.GRID_H = 14
		CONFIG.KEYS_REQUIRED = 5
	else
		-- Tamaño triple (aprox. 17x17 = 289 celdas)
		CONFIG.GRID_W = 17
		CONFIG.GRID_H = 17
		CONFIG.KEYS_REQUIRED = 7
	end
	
	print(string.format("[Generator] Tamaño de grid seleccionado: %dx%d", CONFIG.GRID_W, CONFIG.GRID_H))

	-- ========= RNG =========
	local rng = CONFIG.SEED and Random.new(CONFIG.SEED) or Random.new()

	-- ========= Workspace prep =========
	if CONFIG.HIDE_BASEPLATE then
		local bp = workspace:FindFirstChild("Baseplate")
		if bp and bp:IsA("BasePart") then
			bp.Transparency = 1
			bp.CanCollide = false
		end
	end

	local levelFolder = workspace:FindFirstChild("Level0")
	if levelFolder then levelFolder:Destroy() end
	levelFolder = Instance.new("Folder")
	levelFolder.Name = "Level0"
	levelFolder.Parent = workspace

	local levelModel
	if CONFIG.MAKE_MODEL then
		levelModel = Instance.new("Model")
		levelModel.Name = "Level0Model"
		levelModel.Parent = levelFolder
	end
	
	-- ========= 1) PAREDES =========
	local build = Walls.Generate(CONFIG, rng, levelModel, levelFolder)
	
	-- ========= 2) PISO =========
	Floor.Place(CONFIG, build, levelModel, levelFolder)
	
	-- ========= 3) TECHO =========
	Ceiling.Place(CONFIG, build, levelModel, levelFolder)
	
	-- ========= 4) PUERTA DE LUZ =========
	Door.PlaceLightDoor(CONFIG, build, levelModel, levelFolder, {
		gap = 2,
		prompt = true,
		keysRequired = CONFIG.KEYS_REQUIRED,
		intensity = 2.5,
		range = 20,
		useSurfaceLight = true,
	})
	
	-- ========= 5) SPAWN INTERNO (Eliminado) =========
	-- ¡El GameManager se encarga ahora de teletransportar!
	-- PERO crearemos un SpawnLocation en (1,1) para los respawns
	
	local spawnCF
	do
		local center = Util.CellCenter(CONFIG, 1, 1) -- Celda (1,1) como punto de respawn
		local pos = center + Vector3.new(0, 2.5, 0)

		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "BackroomsRespawn"
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Enabled = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.CFrame = CFrame.new(pos)
		spawn.Parent = levelModel or levelFolder
		spawnCF = spawn.CFrame
	end
	
	-- ========= 6) Señal: nivel listo =========
	LevelBuilt:Fire()
	
	-- ========= 7) Validación =========
	do
		local okGrid, okPhys = Validate.EnsureAccessible(CONFIG, build, spawnCF)
		print(string.format("[Validate] Grid=%s | Phys=%s", okGrid and "OK" or "FAIL", okPhys and "OK" or "FAIL"))
	end

	print("[Backrooms] Generación completa.")

	-- ============ SPAWN DE ITEMS ============
	
	-- Llama al spawner de linternas
	require(script.Parent:WaitForChild("ScatterFlashlights")).Run()

	-- Llama al spawner de llaves
	local keyCount = (CONFIG.KEYS_REQUIRED or 3) + (CONFIG.EXTRA_KEYS or 0)
	require(script.Parent:WaitForChild("ScatterKeys")).Run(keyCount)
	
	-- Devolver datos útiles al GameManager
	return {
		LevelFolder = levelFolder,
		Config = CONFIG,
		Build = build,
		Util = Util, -- Pasamos Util para que GameManager pueda usar CellCenter
	}
end

return BackroomsGenerator