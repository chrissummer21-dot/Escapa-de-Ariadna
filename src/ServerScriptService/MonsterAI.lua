-- src/ServerScriptService/MonsterAI.lua
-- CONVERTIDO A MODULESCRIPT
-- Es llamado por BackroomsGenerator cuando el nivel está listo.
-- IA para "La Niña" que caza al jugador en la oscuridad y huye de la luz.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SimplePath = require(ReplicatedStorage:WaitForChild("SimplePath"))

-- Crear el módulo
local MonsterAI = {}

-- ==================== CONFIGURACIÓN DE IA ====================
local CONFIG = {
	-- 1) Modelo del Monstruo
	MONSTER_TEMPLATE_NAME = "Monster",

	-- 2) Tiempos
	INITIAL_SPAWN_WAIT = 35,
	RESPAWN_DELAY_MIN = 3,
	RESPAWN_DELAY_MAX = 3,
	FADE_OUT_DURATION = 1.0,

	-- 3) Combate y Movimiento
	CHASE_SPEED =40,
	FLEE_SPEED = 25,
	DAMAGE_AMOUNT = 25,
	ATTACK_COOLDOWN = 2,

	-- 4) Spawn
	MIN_SPAWN_FROM_PLAYER = 50,
	MAX_SPAWN_FROM_PLAYER = 100,

	-- 5) Detección de Luz
	FLASHLIGHT_RANGE = 60,
	FLASHLIGHT_ANGLE = 240,
	CEILING_LIGHT_RANGE_MULTIPLIER = 1.2,

	-- 6) SimplePath / Agente
	AGENT = {
		AgentRadius = 2.5,
		AgentHeight = 6,
		AgentCanJump = false,
		WaypointSpacing = 4,
	},

	-- 7) Comportamiento de persecución
	REFRESH_TARGET = 0.25,   -- refresco de destino (0.25–0.5)
	LOS_SPEED_BOOST = 8,     -- acelerón si hay línea de visión directa
	LOS_MAX_WALKSPEED = 32,  -- tope de velocidad con boost
	HIP_HEIGHT = 2.0         -- ayuda a subir umbrales/escalones bajos
}
-- ==========================================================

local MONSTER_TEMPLATE = ReplicatedStorage:FindFirstChild(CONFIG.MONSTER_TEMPLATE_NAME)

-- Variables de estado del módulo
local monster: Model? = nil
local aiState = "Idle" -- "Idle", "Chasing", "Fleeing"
local targetPlayer: Player? = nil
local lastAttackTime = 0

-- Variables de entorno (se asignan en Start)
local moduleLevelFolder = nil
local moduleFloorPart: BasePart? = nil
local moduleCeilingLampsFolder: Instance? = nil

local lightRaycastParams = RaycastParams.new()
lightRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
lightRaycastParams.FilterDescendantsInstances = {}

-- ---------- UTILIDADES (MODIFICADAS) ----------
local function findFloor(): BasePart?
	if moduleFloorPart then return moduleFloorPart end
	if not moduleLevelFolder then return nil end -- Guard
	
	local model = moduleLevelFolder:FindFirstChild("Level0Model")
	local floorName = "Floor"
	if model then
		local p = model:FindFirstChild(floorName)
		if p and p:IsA("BasePart") then moduleFloorPart = p; return p end
	end
	
	local p2 = moduleLevelFolder:FindFirstChild(floorName)
	if p2 and p2:IsA("BasePart") then moduleFloorPart = p2; return p2 end
	
	warn("[MonsterAI] No se encontró 'Floor' en Level0.")
	return nil
end

local function getClosestPlayer(fromPosition: Vector3): Player?
	local closestDist = math.huge
	local closestPlayer = nil
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hum and hum.Health > 0 and hrp then
			local dist = (hrp.Position - fromPosition).Magnitude
			if dist < closestDist then
				closestDist = dist
				closestPlayer = player
			end
		end
	end
	return closestPlayer
end

local function primaryPosition(model: Model): Vector3?
	if model.PrimaryPart then return model.PrimaryPart.Position end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then return d.Position end
	end
	return nil
end

local function hasLineOfSight(fromPos: Vector3, toPos: Vector3): boolean
	local dir = (toPos - fromPos)
	local ray = workspace:Raycast(fromPos, dir, lightRaycastParams)
	return (not ray) or (ray.Instance and monster and ray.Instance:IsDescendantOf(monster))
end

-- ---------- LUZ (MODIFICADA) ----------
local function isPositionLitByCeiling(pos: Vector3): boolean
	if not moduleCeilingLampsFolder then
		if not moduleLevelFolder then return false end
		moduleCeilingLampsFolder = moduleLevelFolder:FindFirstChild("CeilingLamps")
		if not moduleCeilingLampsFolder then return false end
	end
	
	for _, lampModel in ipairs(moduleCeilingLampsFolder:GetChildren()) do
		if lampModel:IsA("Model") or lampModel:IsA("BasePart") then
			local light = lampModel:FindFirstChildWhichIsA("Light")
			if light and light.Enabled then
				local lightRange = (light:IsA("SpotLight") and light.Range) or (light:IsA("PointLight") and light.Range) or 30
				lightRange = lightRange * CONFIG.CEILING_LIGHT_RANGE_MULTIPLIER
				local lightPos: Vector3?
				if light:IsA("SpotLight") then
					lightPos = light.WorldPosition
				else
					lightPos = lampModel:IsA("Model") and primaryPosition(lampModel) or (lampModel :: BasePart).Position
				end
				if lightPos and (pos - lightPos).Magnitude < lightRange then
					return true
				end
			end
		end
	end
	return false
end

local function isMonsterLit(): boolean
	if not monster or not monster.PrimaryPart then return false end
	local monsterPos = monster.PrimaryPart.Position

	if isPositionLitByCeiling(monsterPos) then
		return true
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if not char then continue end
		local tool = char:FindFirstChildOfClass("Tool")
		if tool and tool.Name == "Flashlight" then
			local handle = tool:FindFirstChild("Handle")
			local spotLight = handle and handle:FindFirstChild("SpotLight")
			if spotLight and handle:GetAttribute("IsOn") == true then
				local lightCF = handle.CFrame
				local lightPos = lightCF.Position
				local dist = (monsterPos - lightPos).Magnitude
				if dist <= CONFIG.FLASHLIGHT_RANGE then
					local dirToMonster = (monsterPos - lightPos).Unit
					local lightLook = lightCF:VectorToWorldSpace(Vector3.FromNormalId(spotLight.Face))
					local angleThreshold = math.cos(math.rad(CONFIG.FLASHLIGHT_ANGLE / 2))
					if dirToMonster:Dot(lightLook) > angleThreshold then
						local ray = workspace:Raycast(lightPos, dirToMonster * dist, lightRaycastParams)
						if not ray or (ray.Instance and monster and ray.Instance:IsDescendantOf(monster)) then
							targetPlayer = player
							return true
						end
					end
				end
			end
		end
	end
	return false
end

-- ---------- SPAWN ----------
local function findDarkSpawnPoint(): Vector3?
	local floor = findFloor()
	if not floor then return nil end
	local player = getClosestPlayer(floor.Position)
	if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return nil
	end

	local playerPos = player.Character.HumanoidRootPart.Position
	local floorSize = floor.Size
	local floorCF = floor.CFrame
	local halfX, halfZ = floorSize.X * 0.5, floorSize.Z * 0.5
	local rng = Random.new()

	for i = 1, 20 do
		local x = rng:NextNumber(-halfX * 0.9, halfX * 0.9)
		local z = rng:NextNumber(-halfZ * 0.9, halfZ * 0.9)
		local spawnPos = (floorCF * CFrame.new(x, floorSize.Y * 0.5 + 3, z)).Position
		local distToPlayer = (spawnPos - playerPos).Magnitude
		local distOK = distToPlayer >= CONFIG.MIN_SPAWN_FROM_PLAYER and distToPlayer <= CONFIG.MAX_SPAWN_FROM_PLAYER
		if distOK and not isPositionLitByCeiling(spawnPos) then
			return spawnPos
		end
		if i % 10 == 0 then task.wait() end
	end
	return nil
end

-- ---------- COMBATE ----------
local function onMonsterTouch(hit: BasePart)
	if aiState ~= "Chasing" or (os.clock() - lastAttackTime) < CONFIG.ATTACK_COOLDOWN then
		return
	end
	local parent = hit and hit.Parent
	if not parent then return end
	local player = Players:GetPlayerFromCharacter(parent)
	if player and player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			lastAttackTime = os.clock()
			humanoid:TakeDamage(CONFIG.DAMAGE_AMOUNT)
			print("[MonsterAI] ¡Ataque!")
		end
	end
end

local function connectTouchDamage(mon: Model)
	for _, part in ipairs(mon:GetChildren()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				if monster == mon then
					onMonsterTouch(hit)
				end
			end)
		end
	end
end

-- ---------- DESPAWN ----------
local currentPathFollower: any = nil

local function despawnMonster()
	if not monster or aiState == "Fleeing" then return end

	-- Detener SimplePath antes de desaparecer
	if currentPathFollower then
		pcall(function() currentPathFollower:Stop() end)
		currentPathFollower = nil
	end

	print("[MonsterAI] ¡Huyendo de la luz!")
	aiState = "Fleeing"
	local monsterToFade = monster

	-- Detén el movimiento
	local hum = monsterToFade:FindFirstChildOfClass("Humanoid")
	if hum and monsterToFade:FindFirstChild("HumanoidRootPart") then
		hum:MoveTo(monsterToFade.HumanoidRootPart.Position)
	end

	-- Desactivar colisiones y hacer fade-out
	for _, part in ipairs(monsterToFade:GetDescendants()) do
		if part:IsA("BasePart") then part.CanCollide = false end
	end
	local tweenInfo = TweenInfo.new(CONFIG.FADE_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, part in ipairs(monsterToFade:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("Decal") then
			TweenService:Create(part, tweenInfo, {Transparency = 1}):Play()
		end
	end

	task.delay(CONFIG.FADE_OUT_DURATION, function()
		if monsterToFade then
			monsterToFade:Destroy()
			if monster == monsterToFade then monster = nil end
		end
		targetPlayer = nil
		aiState = "Idle"
		local respawnWait = Random.new():NextNumber(CONFIG.RESPAWN_DELAY_MIN, CONFIG.RESPAWN_DELAY_MAX)
		print(string.format("[MonsterAI] Desapareció. Reaparecerá en %.1f seg.", respawnWait))
		task.wait(respawnWait)
		spawnMonster() -- ¡Reinicia el ciclo!
	end)
end

-- ---------- SPAWN + FOLLOW (MODIFICADO) ----------
function spawnMonster()
	if not moduleLevelFolder then 
		warn("[MonsterAI] Intento de spawn sin levelFolder. Abortando.")
		return 
	end
	if monster or aiState ~= "Idle" then return end
	if not MONSTER_TEMPLATE then
		warn("[MonsterAI] ¡ERROR! No se encontró plantilla de monstruo. Abortando.")
		return
	end

	local spawnPos = findDarkSpawnPoint()
	if not spawnPos then return end

	print("[MonsterAI] ¡Apareciendo!")
	local mon = MONSTER_TEMPLATE:Clone()
	monster = mon
	lightRaycastParams.FilterDescendantsInstances = {monster} -- excluye al propio monstruo en raycasts

	mon:SetPrimaryPartCFrame(CFrame.new(spawnPos))
	mon.Parent = moduleLevelFolder -- ¡Usa la variable del módulo!

	local hum = mon:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = CONFIG.CHASE_SPEED
		hum.AutoRotate = true
		hum.HipHeight = CONFIG.HIP_HEIGHT
	end

	connectTouchDamage(mon)
	aiState = "Chasing"

	-- SimplePath follower
	local sp = SimplePath.new(mon, CONFIG.AGENT)

	-- Callbacks opcionales
	if sp.Blocked then
		sp.Blocked:Connect(function(_idx) end)
	end
	if sp.Stuck then
		sp.Stuck:Connect(function() end)
	end

	-- Loop de persecución
	task.spawn(function()
		currentPathFollower = sp
		while aiState == "Chasing" and monster == mon and mon.Parent and mon.PrimaryPart do
			local target = getClosestPlayer(mon.PrimaryPart.Position)
			if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
				despawnMonster()
				break
			end

			local targetHRP = target.Character.HumanoidRootPart

			if isMonsterLit() then
				despawnMonster()
				break
			end

			if hum then
				if hasLineOfSight(mon.PrimaryPart.Position, targetHRP.Position) then
					hum.WalkSpeed = math.clamp(CONFIG.CHASE_SPEED + CONFIG.LOS_SPEED_BOOST, 0, CONFIG.LOS_MAX_WALKSPEED)
				else
					hum.WalkSpeed = CONFIG.CHASE_SPEED
				end
			end

			sp:Run(targetHRP)

			task.wait(CONFIG.REFRESH_TARGET)
		end

		-- Limpieza por si salimos del bucle
		if currentPathFollower == sp then
			pcall(function() sp:Stop() end)
			currentPathFollower = nil
		end
	end)
end

-- ============ FUNCIÓN PRINCIPAL DEL MÓDULO ============
function MonsterAI.Start(levelFolder)
	if not MONSTER_TEMPLATE then
		warn(string.format("[MonsterAI] ¡ERROR! No se encontró '%s' en ReplicatedStorage. El módulo no se iniciará.", CONFIG.MONSTER_TEMPLATE_NAME))
		return
	end
	
	print("[MonsterAI] Módulo iniciado. Guardando levelFolder.")
	moduleLevelFolder = levelFolder
	moduleFloorPart = nil -- Resetear cache
	moduleCeilingLampsFolder = nil -- Resetear cache

	-- Chequeo rápido de luz/despawn (Movido aquí)
	RunService.Heartbeat:Connect(function()
		if aiState == "Chasing" and isMonsterLit() then
			despawnMonster()
		end
	end)

	-- Inicio (spawn inicial diferido) (Movido aquí)
	task.spawn(function()
		print(string.format("[MonsterAI] La Niña aparecerá en %d segundos...", CONFIG.INITIAL_SPAWN_WAIT))
		findFloor() -- Carga el floor part
		moduleCeilingLampsFolder = moduleLevelFolder:FindFirstChild("CeilingLamps") -- Carga las lámparas
		task.wait(CONFIG.INITIAL_SPAWN_WAIT)
		spawnMonster()
	end)

	print("[MonsterAI] Script de IA (SimplePath) cargado y listeners activados.")
end


return MonsterAI