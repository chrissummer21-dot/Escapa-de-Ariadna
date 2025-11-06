-- src/StarterPlayer/StarterPlayerScripts/ProximityHorror.client.lua
-- SCRIPT NUEVO Y SEPARADO.
-- Reproduce un sonido 3D aleatorio (de 4) cuando el jugador
-- entra en el rango de proximidad del monstruo.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- === CONFIGURACIÓN ===
local SOUND_IDS = {
	"rbxassetid://132373478428379", -- ¡¡CAMBIA ESTO por tu ID de sonido de proximidad 1!!
	"rbxassetid://82949280959534", -- ¡¡CAMBIA ESTO por tu ID de sonido de proximidad 2!!
	"rbxassetid://129689304397014", -- ¡¡CAMBIA ESTO por tu ID de sonido de proximidad 3!!
	"rbxassetid://123778042680363", -- ¡¡CAMBIA ESTO por tu ID de sonido de proximidad 4!!
}
local COOLDOWN_SECONDS = 10 -- Cooldown de 30 segundos
local TRIGGER_DISTANCE = 200 -- ¿A qué distancia se activa el sonido?

-- Distancias para el sonido 3D
local ROLLOFF_MIN_DISTANCE = 15 -- Distancia para volumen MÁXIMO (cercano)
local ROLLOFF_MAX_DISTANCE = 120 -- Distancia para volumen CERO (lejano)

local MONSTER_NAME = "Monster" -- El nombre de tu modelo de monstruo
local LEVEL_FOLDER_NAME = "Level0" -- Dónde spawnea el monstruo
-- =======================

-- 1. Variables de estado
local lastSoundTime = -COOLDOWN_SECONDS
local monster = nil
local monsterHead = nil
local levelFolder = workspace:WaitForChild(LEVEL_FOLDER_NAME)
local soundObjects = {} -- Tabla para guardar los 4 sonidos

-- 2. Función para crear/adjuntar los sonidos al monstruo
local function setupMonsterSounds()
	if not monsterHead then return end

	for _, sound in ipairs(soundObjects) do
		sound:Destroy()
	end
	soundObjects = {}

	for i, soundId in ipairs(SOUND_IDS) do
		local sound = Instance.new("Sound")
		sound.Name = "ProximitySound" .. i
		sound.SoundId = soundId
		sound.Volume = 1
		
		sound.RollOffMode = Enum.RollOffMode.Linear
		sound.RollOffMinDistance = ROLLOFF_MIN_DISTANCE
		sound.RollOffMaxDistance = ROLLOFF_MAX_DISTANCE
		
		sound.Parent = monsterHead -- ¡Pegado al monstruo!
		table.insert(soundObjects, sound)
	end
	print("[ProximityHorror] Sonidos 3D de proximidad creados en el monstruo.")
end


-- Función principal (se ejecuta cada segundo para chequear)
while task.wait(1) do -- Chequea solo cada segundo, es más eficiente
	
	-- 1. Buscar al monstruo
	if not monster or not monster.Parent then
		monster = levelFolder:FindFirstChild(MONSTER_NAME)
		if monster then
			monsterHead = monster:FindFirstChild("Head") 
				or monster:FindFirstChild("UpperTorso") 
				or monster:FindFirstChild("HumanoidRootPart")
			
			if monsterHead then
				setupMonsterSounds() -- Crear sonidos la primera vez que lo vemos
			end
		else
			monsterHead = nil
			continue -- Espera al siguiente ciclo
		end
	end

	-- 2. ¿El jugador está vivo y el monstruo existe?
	if not monsterHead or not player.Character or player.Character.Humanoid.Health <= 0 then
		continue
	end

	-- 3. ¿El cooldown pasó?
	if (os.clock() - lastSoundTime) < COOLDOWN_SECONDS then
		continue
	end
	
	-- 4. ¿Está el jugador lo suficientemente cerca?
	local playerPos = player.Character:GetPrimaryPartCFrame().Position
	local monsterPos = monsterHead.Position
	local distance = (monsterPos - playerPos).Magnitude

	if distance <= TRIGGER_DISTANCE then
		-- ¡ÉXITO! El jugador está cerca.
		if #soundObjects == 0 then continue end -- Seguridad
		
		-- Elige un sonido aleatorio de la tabla
		local randomSound = soundObjects[math.random(1, #soundObjects)]
		
		print("[ProximityHorror] ¡Jugador cerca del monstruo! Reproduciendo sonido 3D.")
		randomSound:Play()
		lastSoundTime = os.clock() -- Reiniciar cooldown
	end
end