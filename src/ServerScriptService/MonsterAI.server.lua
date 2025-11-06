-- src/ServerScriptService/MonsterAI.server.lua
-- IA para "La Niña" que caza al jugador en la oscuridad
-- y huye de la luz (linternas y lámparas).
-- Versión limpia (sin logs de debug).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService") 

-- ==================== CONFIGURACIÓN DE IA ====================
local CONFIG = {
	-- 1. Modelo del Monstruo
	MONSTER_TEMPLATE_NAME = "Monster", 

	-- 2. Tiempos
	INITIAL_SPAWN_WAIT = 35,  
	RESPAWN_DELAY_MIN = 10,   
	RESPAWN_DELAY_MAX = 10,   
	FADE_OUT_DURATION = 1.0, 

	-- 3. Combate y Movimiento
	CHASE_SPEED = 18,         
	FLEE_SPEED = 25,          
	DAMAGE_AMOUNT = 25,       
	ATTACK_COOLDOWN = 2,      

	-- 4. Spawn
	MIN_SPAWN_FROM_PLAYER = 60, 
	MAX_SPAWN_FROM_PLAYER = 150, 
	
	-- 5. Detección de Luz
	FLASHLIGHT_RANGE = 60,
	FLASHLIGHT_ANGLE = 60, -- (Ángulo más ancho)
	CEILING_LIGHT_RANGE_MULTIPLIER = 1.2 
}
-- ==========================================================

local MONSTER_TEMPLATE = ReplicatedStorage:FindFirstChild(CONFIG.MONSTER_TEMPLATE_NAME)
if not MONSTER_TEMPLATE then
	warn(string.format("[MonsterAI] ¡ERROR CRÍTICO! No se encuentra la plantilla del monstruo en ReplicatedStorage con el nombre: '%s'. La IA no funcionará.", CONFIG.MONSTER_TEMPLATE_NAME))
	return
end

local monster = nil
local aiState = "Idle" -- "Idle", "Chasing", "Fleeing"
local targetPlayer = nil
local lastAttackTime = 0
local path = nil

local levelFolder = workspace:WaitForChild("Level0")
local floorPart = nil
local ceilingLampsFolder = nil

local lightRaycastParams = RaycastParams.new()
lightRaycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- --- SECCIÓN 1: UTILIDADES (Buscar Suelo, Jugadores) ---
local function findFloor()
	if floorPart then return floorPart end
	local model = levelFolder:FindFirstChild("Level0Model")
	local floorName = "Floor"
	if model then
		local p = model:FindFirstChild(floorName)
		if p and p:IsA("BasePart") then floorPart = p; return p end
	end
	local p2 = levelFolder:FindFirstChild(floorName)
	if p2 and p2:IsA("BasePart") then floorPart = p2; return p2 end
	warn("[MonsterAI] ¡FALLO EN SPAWN! No se encontró el suelo ('Floor') en workspace.Level0.")
	return nil
end
local function getClosestPlayer(fromPosition)
	local closestDist = math.huge
	local closestPlayer = nil
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") and char.Humanoid.Health > 0 then
			local dist = (char.HumanoidRootPart.Position - fromPosition).Magnitude
			if dist < closestDist then
				closestDist = dist
				closestPlayer = player
			end
		end
	end
	return closestPlayer
end

-- --- SECCIÓN 2: LÓGICA DE SPAWN (Aparición) ---
local function findDarkSpawnPoint()
	local floor = findFloor()
	if not floor then return nil end
	local player = getClosestPlayer(floor.Position) 
	if not player or not player.Character then
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
		
		if distOK then
			if not isPositionLitByCeiling(spawnPos) then
				return spawnPos
			end
		else
			if i % 10 == 0 then task.wait() end
		end
	end
	-- (Log de fallo de spawn quitado, ya no es necesario)
	return nil
end

function spawnMonster()
	if monster or aiState ~= "Idle" then return end
	
	local spawnPos = findDarkSpawnPoint()
	if not spawnPos then
		return 
	end
	
	print("[MonsterAI] ¡Apareciendo!") 
	monster = MONSTER_TEMPLATE:Clone() 
	lightRaycastParams.FilterDescendantsInstances = {monster} 
	monster:SetPrimaryPartCFrame(CFrame.new(spawnPos))
	monster.Parent = levelFolder
	monster.Humanoid.WalkSpeed = CONFIG.CHASE_SPEED
	for _, part in ipairs(monster:GetChildren()) do
		if part:IsA("BasePart") then
			part.Touched:Connect(onMonsterTouch)
		end
	end
	aiState = "Chasing"
	path = PathfindingService:CreatePath()
end

-- --- SECCIÓN 3: LÓGICA DE DESPAWN (Huida) ---
function despawnMonster()
	if not monster or aiState == "Fleeing" then return end
	
	print("[MonsterAI] ¡Huyendo de la luz!")
	aiState = "Fleeing"
	local monsterToFade = monster 
	
	if monsterToFade:FindFirstChild("Humanoid") then
		monsterToFade.Humanoid:MoveTo(monsterToFade.HumanoidRootPart.Position) 
	end
	for _, part in ipairs(monsterToFade:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
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
			if monster == monsterToFade then
				monster = nil
			end
		end
		targetPlayer = nil
		aiState = "Idle"
		local respawnWait = Random.new():NextNumber(CONFIG.RESPAWN_DELAY_MIN, CONFIG.RESPAWN_DELAY_MAX)
		print(string.format("[MonsterAI] Desapareció. Reaparecerá en %.1f seg.", respawnWait))
		task.wait(respawnWait)
		spawnMonster() 
	end)
end

-- --- SECCIÓN 4: LÓGICA DE COMBATE Y PERSECUCIÓN ---
function onMonsterTouch(hit)
	if aiState ~= "Chasing" or (os.clock() - lastAttackTime) < CONFIG.ATTACK_COOLDOWN then
		return
	end
	local parent = hit.Parent
	if not parent then return end
	local player = Players:GetPlayerFromCharacter(parent)
	if player and player.Character and player.Character:FindFirstChild("Humanoid") then
		lastAttackTime = os.clock()
		player.Character.Humanoid:TakeDamage(CONFIG.DAMAGE_AMOUNT)
		print("[MonsterAI] ¡Ataque!")
	end
end

local function updatePath()
	if aiState ~= "Chasing" or not monster or not targetPlayer or not targetPlayer.Character then
		despawnMonster() 
		return
	end
	local hrp = monster:FindFirstChild("HumanoidRootPart")
	local targetHrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or not targetHrp then return end
	local success, err = pcall(function()
		path:ComputeAsync(hrp.Position, targetHrp.Position)
	end)
	if success and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		if #waypoints >= 2 then
			monster.Humanoid:MoveTo(waypoints[2].Position)
		else
			monster.Humanoid:MoveTo(targetHrp.Position)
		end
	else
		monster.Humanoid:MoveTo(targetHrp.Position)
	end
end

-- --- SECCIÓN 5: DETECCIÓN DE LUZ (Limpia) ---

function isPositionLitByCeiling(pos)
	if not ceilingLampsFolder then
		ceilingLampsFolder = levelFolder:FindFirstChild("CeilingLamps")
		if not ceilingLampsFolder then return false end
	end
	for _, lampModel in ipairs(ceilingLampsFolder:GetChildren()) do
		local light = lampModel:FindFirstChildWhichIsA("Light")
		if light and light.Enabled then 
			local lightRange = (light:IsA("SpotLight") and light.Range or (light:IsA("PointLight") and light.Range) or 30)
			lightRange = lightRange * CONFIG.CEILING_LIGHT_RANGE_MULTIPLIER
			local lightPos = (light:IsA("SpotLight") and light.WorldPosition or lampModel:GetPrimaryPartCFrame().Position)
			if (pos - lightPos).Magnitude < lightRange then
				return true 
			end
		end
	end
	return false
end

function isMonsterLit()
	if not monster or not monster.PrimaryPart then return false end
	local monsterPos = monster.PrimaryPart.Position
	
	-- 1. Chequear luces del techo
	if isPositionLitByCeiling(monsterPos) then
		return true
	end
	
	-- 2. Chequear linternas de jugadores
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if not char then continue end
		
		local tool = char:FindFirstChildOfClass("Tool")
		
		if tool and tool.Name == "Flashlight" then 
			local handle = tool:FindFirstChild("Handle")
			local spotLight = handle and handle:FindFirstChild("SpotLight")
			
			if spotLight and handle:GetAttribute("IsOn") == true then 
				-- (Chequeo de luz...)
				local lightCF = handle.CFrame 
				local lightPos = lightCF.Position
				local dist = (monsterPos - lightPos).Magnitude
				
				if dist <= CONFIG.FLASHLIGHT_RANGE then
					local dirToMonster = (monsterPos - lightPos).Unit
					local lightLook = lightCF:VectorToWorldSpace(Vector3.FromNormalId(spotLight.Face))
					local angleThreshold = math.cos(math.rad(CONFIG.FLASHLIGHT_ANGLE / 2))
					local dot = dirToMonster:Dot(lightLook)
					
					if dot > angleThreshold then
						local ray = workspace:Raycast(lightPos, dirToMonster * dist, lightRaycastParams)
						
						if not ray or (ray.Instance and ray.Instance:IsDescendantOf(monster)) then
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

-- --- SECCIÓN 6: BUCLES PRINCIPALES DE IA ---
RunService.Heartbeat:Connect(function()
	if aiState == "Chasing" then
		if isMonsterLit() then
			despawnMonster()
		end
	end
end)

task.spawn(function()
	while task.wait(CONFIG.PATH_RECALCULATE) do
		if aiState == "Chasing" and monster then
			targetPlayer = getClosestPlayer(monster.PrimaryPart.Position)
			if targetPlayer then
				updatePath()
			else
				despawnMonster()
			end
		end
	end
end)

task.spawn(function()
	print(string.format("[MonsterAI] La Niña aparecerá en %d segundos...", CONFIG.INITIAL_SPAWN_WAIT))
	
	findFloor() 
	ceilingLampsFolder = levelFolder:FindFirstChild("CeilingLamps")
	
	task.wait(CONFIG.INITIAL_SPAWN_WAIT)
	
	spawnMonster() 
end)

print("[MonsterAI] Script de IA (Limpio) cargado.")