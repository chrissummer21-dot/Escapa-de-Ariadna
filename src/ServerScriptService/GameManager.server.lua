-- src/ServerScriptService/GameManager.lua
-- GESTOR DE LOBBY (VERSIÓN 14 - CICLO COMPLETO)
-- Añade "DoorOpenedSignal" y el toast "Has despertado" al respawnear.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

-- ==== CREADOR DE SEÑALES GLOBALES (MODIFICADO) ====
local Signals = ReplicatedStorage:FindFirstChild("BackroomsSignals")
if not Signals then
	Signals = Instance.new("Folder")
	Signals.Name = "BackroomsSignals"
	Signals.Parent = ReplicatedStorage
end
if not Signals:FindFirstChild("LobbySignal") then
	local evt = Instance.new("RemoteEvent")
	evt.Name = "LobbySignal"
	evt.Parent = Signals
end
if not Signals:FindFirstChild("LevelBuilt") then
	local evt = Instance.new("RemoteEvent") 
	evt.Name = "LevelBuilt"
	evt.Parent = Signals
end
if not Signals:FindFirstChild("ShowToastMessage") then
	local evt = Instance.new("RemoteEvent")
	evt.Name = "ShowToastMessage"
	evt.Parent = Signals
end
if not Signals:FindFirstChild("OpenExit") then
	local evt = Instance.new("BindableEvent")
	evt.Name = "OpenExit"
	evt.Parent = Signals
end
-- ¡NUEVA SEÑAL!
if not Signals:FindFirstChild("DoorOpenedSignal") then
	local evt = Instance.new("RemoteEvent")
	evt.Name = "DoorOpenedSignal"
	evt.Parent = Signals
end
-- ===============================================

local BackroomsGenerator = require(script.Parent:WaitForChild("BackroomsGenerator"))
local LobbySignal = Signals:WaitForChild("LobbySignal")
local ShowToastMessage = Signals:WaitForChild("ShowToastMessage") -- ¡NUEVO!

-- --- CONFIGURACIÓN ---
local LOBBY_SPAWN = workspace:WaitForChild("LobbySpawn") 
local COUNTDOWN_TIME = 10
local gameState = "Lobby"
local countdownActive = false
local heartbeatConnection = nil
local HORIZONTAL_THRESHOLD = 0.3

-- --- (Funciones setLobbyLighting, sendPlayersToLobby, startGame, startCountdownLoop, setupHeartbeatDetector) ---
-- (Estas funciones de la V13 se pegan aquí sin cambios)
-- ...
local function setLobbyLighting(isDay)
	if isDay then
		Lighting.ClockTime = 12
		Lighting.Brightness = 2
		Lighting.Ambient = Color3.fromRGB(128, 128, 128)
		Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	else
		Lighting.ClockTime = 2
		Lighting.Brightness = 0
		Lighting.Ambient = Color3.new(0, 0, 0)
		Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
	end
end

local function sendPlayersToLobby()
	setLobbyLighting(true)
	
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if not char then continue end
		
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		
		if hrp and hum then
			hum.Sit = false 
			hum.PlatformStand = false
			hrp.Anchored = false
			hrp.CFrame = LOBBY_SPAWN.CFrame + Vector3.new(0, 3, 0)
		end
		
		LobbySignal:FireClient(player, "Show", "¡A dormir!")
	end
	
	gameState = "Lobby"
	countdownActive = false
	if heartbeatConnection then heartbeatConnection:Disconnect() end
	heartbeatConnection = setupHeartbeatDetector()
end

local function startGame()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	
	countdownActive = false
	gameState = "Teleporting" 
	
	LobbySignal:FireAllClients("Show", "Preparando Backroom...")

	local playersToTeleport = {}
	local playersInLobby = Players:GetPlayers()
	for _, player in ipairs(playersInLobby) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")

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

	print(string.format("[GameManager] Llamando al generador para %d jugadores.", playerCount))
	local result = BackroomsGenerator.Generate(playerCount)
	
	if not result then
		warn("[GameManager] ¡El generador falló! Volviendo al lobby.")
		sendPlayersToLobby()
		return
	end
	
	local config = result.Config
	local util = result.Util
	
	LobbySignal:FireAllClients("Show", "Limpiando jugadores...")
	print("[GameManager] Forzando respawn en el lobby para limpiar estado...")
	for _, player in ipairs(playersToTeleport) do
		player.RespawnLocation = LOBBY_SPAWN
		player:LoadCharacter()
	end
	
	task.wait(2.5) 
	
	LobbySignal:FireAllClients("Hide")
	print("[GameManager] Teletransportando jugadores limpios al Backroom...")
	local rng = Random.new()
	
	for _, player in ipairs(playersToTeleport) do
		local char = player.Character 
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		
		if hrp then
			local x = rng:NextInteger(1, config.GRID_W)
			local z = rng:NextInteger(1, config.GRID_H)
			local center = util.CellCenter(config, x, z)
			local spawnPos = center + Vector3.new(0, 5, 0)
			
			hrp.CFrame = CFrame.new(spawnPos)
		else
			warn(string.format("[GameManager] No se pudo encontrar el personaje de %s después del respawn.", player.Name))
		end
	end
	
	gameState = "InProgress"
	print("[GameManager] ¡Partida iniciada!")
end

local function startCountdownLoop()
	for i = COUNTDOWN_TIME, 0, -1 do
		if gameState ~= "Lobby" then 
			countdownActive = false 
			break 
		end 
		
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
		
		if i == 8 then
			print("[GameManager] Faltan 8 segundos. Haciendo de noche...")
			setLobbyLighting(false)
		end
		
		if i > 0 then
			task.wait(1)
		else
			LobbySignal:FireAllClients("Show", "¡Entrando al Backroom!")
			task.wait(1)
			startGame()
		end
	end
end

function setupHeartbeatDetector()
	return RunService.Heartbeat:Connect(function()
		if countdownActive or gameState ~= "Lobby" then
			return
		end
		
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			
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
-- ...
-- --- LÓGICA DE INICIO ---

-- Manejar jugadores que se unen (¡MODIFICADO!)
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5) 
		
		-- ==== ¡NUEVA LÓGICA DE "HAS DESPERTADO"! ====
		local hasWon = player:FindFirstChild("WonGame")
		if hasWon then
			hasWon:Destroy() -- Limpiar la bandera
			
			-- Ya está en el lobby (porque Door.lua lo puso ahí)
			-- Solo mostramos el toast.
			ShowToastMessage:FireClient(player, "Has despertado.")
			
			-- (El detector de Heartbeat se reiniciará si todos ganan y el juego resetea)
			
		elseif gameState == "InProgress" or gameState == "Teleporting" then
			-- El jugador se une tarde o muere, va al respawn del backroom
			local hrp = character:WaitForChild("HumanoidRootPart")
			local respawn = workspace:FindFirstChild("Level0") and workspace.Level0:FindFirstChild("BackroomsRespawn")
			if respawn then
				player.RespawnLocation = respawn
				hrp.CFrame = respawn.CFrame + Vector3.new(0, 3, 0)
			else
				hrp.CFrame = LOBBY_SPAWN.CFrame + Vector3.new(0, 3, 0)
			end
		else
			-- El juego está en el Lobby, spawn normal
			local hrp = character:WaitForChild("HumanoidRootPart")
			hrp.CFrame = LOBBY_SPAWN.CFrame + Vector3.new(0, 3, 0)
			LobbySignal:FireClient(player, "Show", "¡A dormir!")
		end
	end) 
end) 

-- Configuración inicial
sendPlayersToLobby() -- Esto teletransporta a todos, pone el lobby de día y activa el detector

print("[GameManager] Servidor iniciado. (V14 - Ciclo Completo).")