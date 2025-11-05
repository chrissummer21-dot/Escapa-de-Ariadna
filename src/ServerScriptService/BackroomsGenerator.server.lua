-- ServerScriptService/BackroomsGenerator.server.lua
-- Orquestador modular del Backrooms:
-- 1) Walls -> 2) Floor -> 3) Ceiling -> 4) Door
-- + Spawn interno que luego "desaparece"
-- + SeÃ±al LevelBuilt para scripts que dependan del nivel
-- + ValidaciÃ³n de accesibilidad (grid + fÃ­sica)

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

if RunService:IsClient() then return end

-- ========= CONFIG =========
local CONFIG = {
	GRID_W = 10, GRID_H = 10,
	CELL_SIZE = Vector2.new(22, 22),

	WALL_HEIGHT = 12,
	WALL_THICK  = 1,

	-- Elevar todo para no chocar con Baseplate
	ORIGIN = Vector3.new(0, 6, 0),

	SEED = nil,           -- fija una semilla (nÃºmero) para layouts reproducibles
	EXTRA_LOOPS = 12,     -- rompe muros internos extra (sin perforar bordes)

	-- Piso / techo
	ADD_FLOOR = true,  FLOOR_THICK = 1,  FLOOR_COLOR = Color3.fromRGB(235,235,235),
	ADD_CEILING = true, CEILING_THICK = 1, CEILING_COLOR = Color3.fromRGB(235,235,235),

	-- Escena
	MAKE_MODEL = true,
	HIDE_BASEPLATE = true,

	-- TamaÃ±o por defecto de la puerta de luz (usado por Door.lua)
	DOOR_WIDTH = 6,
	DOOR_HEIGHT = 12,
	DOOR_THICK = 1,
}

-- ========= RNG =========
local rng = CONFIG.SEED and Random.new(CONFIG.SEED) or Random.new()

-- ========= Asegurar jerarquÃ­a en ReplicatedStorage =========
local ModulesFolder = ReplicatedStorage:FindFirstChild("Modules")
if not ModulesFolder then
	ModulesFolder = Instance.new("Folder")
	ModulesFolder.Name = "Modules"
	ModulesFolder.Parent = ReplicatedStorage
end

local BackroomsFolder = ModulesFolder:FindFirstChild("Backrooms")
if not BackroomsFolder then
	BackroomsFolder = Instance.new("Folder")
	BackroomsFolder.Name = "Backrooms"
	BackroomsFolder.Parent = ModulesFolder
end

-- SeÃ±ales
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

-- ========= Requires (mÃ³dulos) =========
local Walls    = require(BackroomsFolder:WaitForChild("Walls"))
local Floor    = require(BackroomsFolder:WaitForChild("Floor"))
local Ceiling  = require(BackroomsFolder:WaitForChild("Ceiling"))
local Door     = require(BackroomsFolder:WaitForChild("Door"))
local Util     = require(BackroomsFolder:WaitForChild("Util"))
local Validate = require(BackroomsFolder:WaitForChild("Validate"))

-- ========= 1) PAREDES =========
local build = Walls.Generate(CONFIG, rng, levelModel, levelFolder)
-- build: grid, entranceEdge/Cell, exitEdge/Cell, totalW/totalD, parent

-- ========= 2) PISO =========
Floor.Place(CONFIG, build, levelModel, levelFolder)

-- ========= 3) TECHO =========
Ceiling.Place(CONFIG, build, levelModel, levelFolder)

-- ========= 4) PUERTA DE LUZ (blanca, Neon) SIN perforar muros =========
Door.PlaceLightDoor(CONFIG, build, levelModel, levelFolder, {
	gap = 2,              -- separa la puerta hacia el interior del backroom
	prompt = true,        -- interacciÃ³n manual; si luego solo por tareas, usa false y OpenExit:Fire()
	intensity = 2.5,      -- luz suave
	range = 20,
	useSurfaceLight = true,
})

-- ========= 5) Spawn interno + respawn =========
local function inwardOffset(edge, halfX, halfZ)
	if edge == "N" then return Vector3.new(0, 0,  halfZ - 2)
	elseif edge == "S" then return Vector3.new(0, 0, -halfZ + 2)
	elseif edge == "W" then return Vector3.new( halfX - 2, 0, 0)
	elseif edge == "E" then return Vector3.new(-halfX + 2, 0, 0) end
	return Vector3.new(0,0,0)
end

local spawnCF
do
	if build and build.entranceCell then
		local center = Util.CellCenter(CONFIG, build.entranceCell.X, build.entranceCell.Z)
		local pos = center + inwardOffset(build.entranceEdge, CONFIG.CELL_SIZE.X*0.5, CONFIG.CELL_SIZE.Y*0.5) + Vector3.new(0, 2.5, 0)

		local spawn = workspace:FindFirstChild("BackroomsSpawn") or Instance.new("SpawnLocation")
		spawn.Name = "BackroomsSpawn"
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Enabled = true
		spawn.BrickColor = BrickColor.new("New Yeller")

		-- Hacerlo "desaparecer": invisible y sin colisiÃ³n, pero sigue activo para respawns
		spawn.Transparency = 1
		spawn.CanCollide = false

		spawn.CFrame = CFrame.new(pos)
		spawn.Parent = levelModel or levelFolder
		spawnCF = spawn.CFrame

		-- Teleport inicial de jugadores actuales
		for _,plr in ipairs(Players:GetPlayers()) do
			if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
				plr.Character.HumanoidRootPart.CFrame = spawn.CFrame + Vector3.new(0, 2, 0)
			end
		end

		-- Teleport en futuros joins/respawns
		Players.PlayerAdded:Connect(function(plr)
			plr.CharacterAdded:Connect(function(char)
				local hrp = char:WaitForChild("HumanoidRootPart")
				task.wait()
				hrp.CFrame = spawn.CFrame + Vector3.new(0, 2, 0)
			end)
		end)
	end
end

-- ========= 6) SeÃ±al: nivel listo (Ãºtil para lÃ¡mparas, etc.) =========
LevelBuilt:Fire()

-- ========= 7) ValidaciÃ³n de accesibilidad (grid + fÃ­sica) =========
do
	local okGrid, okPhys = Validate.EnsureAccessible(CONFIG, build, spawnCF)
	print(string.format("[Validate] Grid=%s | Phys=%s", okGrid and "OK" or "FAIL", okPhys and "OK" or "FAIL"))

	-- (Opcional) Si falla lo fÃ­sico, puedes abrir la puerta automÃ¡ticamente:
	-- if okGrid and not okPhys then
	--     OpenExit:Fire()
	-- end
end

print(string.format(
	"[Backrooms] OK | Grid=%dx%d | Cell=(%.1f,%.1f) | WallH=%d | Modules: Wallsâ†’Floorâ†’Ceilingâ†’Door | Spawn invisible",
	CONFIG.GRID_W, CONFIG.GRID_H, CONFIG.CELL_SIZE.X, CONFIG.CELL_SIZE.Y, CONFIG.WALL_HEIGHT
	))
