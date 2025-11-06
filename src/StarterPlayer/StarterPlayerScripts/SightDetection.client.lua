-- src/StarterPlayer/StarterPlayerScripts/SightDetection.client.lua
-- Revisa si el jugador está mirando directamente al monstruo
-- y reproduce un sonido de susto con cooldown.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- === CONFIGURACIÓN ===
local SOUND_ID = "rbxassetid://89477030981428" -- ¡¡CAMBIA ESTO por tu ID de sonido!!
local COOLDOWN_SECONDS = 30 -- Cooldown de 30 segundos
local MAX_DISTANCE = 150 -- Distancia máxima para que suene
local MONSTER_NAME = "Monster" -- El nombre de tu modelo de monstruo
local LEVEL_FOLDER_NAME = "Level0" -- Dónde spawnea el monstruo
-- =======================

-- 1. Crear el sonido
local sound = Instance.new("Sound")
sound.SoundId = SOUND_ID
sound.Volume = 1
-- Lo ponemos en la GUI del jugador para que solo él lo escuche
sound.Parent = player:WaitForChild("PlayerGui")

-- 2. Variables de estado
local lastSoundTime = -COOLDOWN_SECONDS -- Permite que suene la primera vez
local monster = nil
local monsterHead = nil
local levelFolder = workspace:WaitForChild(LEVEL_FOLDER_NAME)

-- 3. Parámetros del Raycast
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
-- (El filtro se actualizará para ignorar al jugador)

-- Función principal (se ejecuta cada frame)
RunService.RenderStepped:Connect(function(dt)
	-- 0. Actualizar el filtro del raycast (el personaje puede cambiar)
	if player.Character then
		rayParams.FilterDescendantsInstances = {player.Character}
	else
		rayParams.FilterDescendantsInstances = {}
	end

	-- 1. Buscar al monstruo
	if not monster or not monster.Parent then
		monster = levelFolder:FindFirstChild(MONSTER_NAME)
		if monster then
			-- Busca la cabeza, si no, el torso, si no, la raíz
			monsterHead = monster:FindFirstChild("Head") 
				or monster:FindFirstChild("UpperTorso") 
				or monster:FindFirstChild("HumanoidRootPart")
		else
			monsterHead = nil
			return -- Monstruo no está, no hacer nada
		end
	end

	-- 2. ¿El jugador está vivo y el monstruo existe?
	if not monsterHead or not player.Character or player.Character.Humanoid.Health <= 0 then
		return
	end

	-- 3. ¿El cooldown pasó?
	if (os.clock() - lastSoundTime) < COOLDOWN_SECONDS then
		return
	end

	local monsterPos = monsterHead.Position
	local cameraPos = camera.CFrame.Position
	local distance = (monsterPos - cameraPos).Magnitude

	-- 4. ¿Está lo suficientemente cerca?
	if distance > MAX_DISTANCE then
		return
	end

	-- 5. ¿Está en la pantalla?
	-- WorldToScreenPoint nos dice si está en la pantalla (isOnScreen)
	local _, isOnScreen = camera:WorldToScreenPoint(monsterPos)
	if not isOnScreen then
		return
	end

	-- 6. ¿Hay línea de visión (Raycast)?
	-- Lanzamos un rayo desde la cámara hasta el monstruo
	local direction = (monsterPos - cameraPos).Unit
	local rayResult = workspace:Raycast(cameraPos, direction * distance, rayParams)

	local hitMonster = false
	if not rayResult then
		-- Si no golpeó NADA, significa que hay visión limpia
		hitMonster = true 
	elseif rayResult.Instance:IsDescendantOf(monster) then
		-- Si golpeó una parte del monstruo
		hitMonster = true 
	end
	-- (Si golpeó una 'Wall' o 'Floor', hitMonster sigue en false)

	-- 7. ¡ÉXITO!
	if hitMonster then
		print("[SightDetection] ¡Jugador vio al monstruo! Reproduciendo sonido de susto.")
		sound:Play()
		lastSoundTime = os.clock() -- Reiniciar cooldown
	end
end)

print("SightDetection.client.lua cargado.")