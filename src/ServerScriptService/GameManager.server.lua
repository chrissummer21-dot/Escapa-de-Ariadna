-- src/ServerScriptService/GameManager.lua
-- GESTOR DE LOBBY (VERSIÓN V9 - DETECCIÓN DE ORIENTACIÓN)
-- Comprueba la orientación FÍSICA del HumanoidRootPart.
-- Funciona con CUALQUIER tipo de cama (Sit, PlatformStand, CFrame, etc.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BackroomsGenerator = require(script.Parent:WaitForChild("BackroomsGenerator"))
local Signals = ReplicatedStorage:WaitForChild("BackroomsSignals")
local LobbySignal = Signals:WaitForChild("LobbySignal")

-- --- CONFIGURACIÓN ---
local LOBBY_SPAWN = workspace:WaitForChild("LobbySpawn") 

local COUNTDOWN_TIME = 30
local gameState = "Lobby"
local countdownActive = false
local heartbeatConnection = nil
local HORIZONTAL_THRESHOLD = 0.3 -- Qué tan "horizontal" debe estar (más bajo = más plano)

-- Función para teletransportar a todos al Lobby
local function sendPlayersToLobby()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if not char then continue end
		
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		
		if hrp and hum then
			-- "Stand up" universal
			hum.Sit = false 
			hum.PlatformStand = false
			hrp.CFrame = LOBBY_SPAWN.CFrame + Vector3.new(0, 3, 0)
		end
		
		LobbySignal:FireClient(player, "Show", "¡A dormir!")
	end
	
	-- (Reiniciar el estado del juego)
	gameState = "Lobby"
	countdownActive = false
	if heartbeatConnection then heartbeatConnection:Disconnect() end
	heartbeatConnection = setupHeartbeatDetector()
end

-- Función para iniciar la partida
local function startGame()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	
	countdownActive = false
	gameState = "InProgress"
	LobbySignal:FireAllClients("Hide")

	-- ¡VERIFICACIÓN DE ORIENTACIÓN!
	local playersToTeleport = {}
	local playersInLobby = Players:GetPlayers()
	for _, player in ipairs(playersInLobby) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")

		-- ¿El jugador está vivo Y su HRP está horizontal?
		if hum and hum.Health > 0 and hrp then
			if math.abs(hrp.CFrame.UpVector.Y) < HORIZONTAL_THRESHOLD then
				table.insert(playersToTeleport, player)
			end
		end
	end

	local playerCount = #playersToTeleport
	
	if playerCount == 0 then
		print("[GameManager] No hay jugadores dormidos, volviendo al lobby.")
		sendPlayersToLobby() 
		return
	end

	-- 1. Generar el Backroom
	print(string.format("[GameManager] Llamando al generador para %d jugadores.", playerCount))
	local result = BackroomsGenerator.Generate(playerCount)
	local config = result.Config
	local util = result.Util
	
	-- 2. Teletransportar jugadores
	print("[GameManager] Teletransportando jugadores dormidos...")
	local rng = Random.new()
	
	for _, player in ipairs(playersToTeleport) do
		local char = player.Character
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		
		if hrp and hum then
			-- "Stand up" universal ANTES de teletransportar
			hum.Sit = false 
			--hum.PlatformStand = false
			hrp.Anchored = false
			local x = rng:NextInteger(1, config.GRID_W)
			local z = rng:NextInteger(1, config.GRID_H)
			local center = util.CellCenter(config, x, z)
			local spawnPos = center + Vector3.new(0, 4, 0)
			
			hrp.CFrame = CFrame.new(spawnPos) -- El TP resetea la orientación
            hrp.Anchored = false
		end
	end
	
	print("[GameManager] ¡Partida iniciada!")
end

-- Bucle de cuenta atrás
local function startCountdownLoop()
	for i = COUNTDOWN_TIME, 0, -1 do
		if gameState ~= "Lobby" then 
			countdownActive = false 
			break 
		end 
		
		-- ¡VERIFICACIÓN DE ORIENTACIÓN!
		local currentSleeping = 0
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			
			if hum and hum.Health > 0 and hrp then
				if math.abs(hrp.CFrame.UpVector.Y) < HORIZONTAL_THRESHOLD then
					currentSleeping += 1
				end
			end
		end
		
		local msg = string.format("La partida comienza en %d... (%d acostados)", i, currentSleeping)
		LobbySignal:FireAllClients("Show", msg)
		
		if i > 0 then
			task.wait(1)
		else
			LobbySignal:FireAllClients("Show", "¡Entrando al Backroom!")
			task.wait(1)
			startGame()
		end
	end
end

-- Detector de Heartbeat
function setupHeartbeatDetector()
	return RunService.Heartbeat:Connect(function()
		if countdownActive or gameState ~= "Lobby" then
			return
		end
		
		-- ¡VERIFICACIÓN DE ORIENTACIÓN!
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			
			-- ¿El jugador está vivo Y su HRP está horizontal?
			if hum and hum.Health > 0 and hrp then
				if math.abs(hrp.CFrame.UpVector.Y) < HORIZONTAL_THRESHOLD then
					
					print(string.format("[GameManager] ¡%s está acostado! Iniciando cuenta atrás.", player.Name))
					
					countdownActive = true 
					
					if heartbeatConnection then
						heartbeatConnection:Disconnect()
						heartbeatConnection = nil
					end
					
					startCountdownLoop()
					break 
				end
			end
		end
	end)
end

-- --- LÓGICA DE INICIO ---

-- Manejar jugadores que se unen
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5) 
		local hrp = character:WaitForChild("HumanoidRootPart")
		
		if gameState == "Lobby" then
			hrp.CFrame = LOBBY_SPAWN.CFrame + Vector3.new(0, 3, 0)
			LobbySignal:FireClient(player, "Show", "¡A dormir!")
		else
			local respawn = workspace:FindFirstChild("Level0") and workspace.Level0:FindFirstChild("BackroomsRespawn")
			if respawn then
				hrp.CFrame = respawn.CFrame + Vector3.new(0, 3, 0)
			else
				hrp.CFrame = LOBBY_SPAWN.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end) 
end) 

-- Configuración inicial
sendPlayersToLobby() -- Esto teletransporta a todos y activa el detector Heartbeat

print("[GameManager] Servidor iniciado. (V9 - Orientación).")