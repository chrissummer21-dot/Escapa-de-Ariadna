-- src/ReplicatedStorage/Modules/Backrooms/Door.lua
-- MODIFICADO (V4):
-- 1. La luz/puerta se queda encendida (no desaparece).
-- 2. Dispara la señal "DoorOpenedSignal" 1 sola vez.
-- 3. Respawnea en el lobby a CUALQUIERA que la use después de abierta.
-- 4. Pone una bandera "WonGame" en el jugador para que GameManager lo sepa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Door = {}

-- getSignals (Solo busca, ya no crea)
local function getSignals()
	local signals = ReplicatedStorage:WaitForChild("BackroomsSignals")
	local openExit = signals:WaitForChild("OpenExit")
	local showToast = signals:WaitForChild("ShowToastMessage")
	local doorOpened = signals:WaitForChild("DoorOpenedSignal") -- ¡NUEVO!
	
	return signals, openExit, showToast, doorOpened
end

-- ¡NUEVA FUNCIÓN! Esta es la lógica de respawn
local function respawnPlayerToLobby(player)
	if not player then return end
	
	-- 1. Poner la bandera para que GameManager la vea
	local flag = Instance.new("BoolValue")
	flag.Name = "WonGame"
	flag.Parent = player
	
	-- 2. Encontrar el spawn del lobby
	local lobbySpawn = workspace:FindFirstChild("LobbySpawn")
	
	if lobbySpawn then
		print(string.format("[Door] %s ha usado la puerta. Respawneando en el lobby.", player.Name))
		player.RespawnLocation = lobbySpawn
		player:LoadCharacter()
	else
		warn("[Door] ¡No se pudo encontrar 'LobbySpawn' en workspace para el respawn!")
	end
end


function Door.PlaceLightDoor(cfg, build, levelModel, levelFolder, options)
	options = options or {}
	local gap         = options.gap or 2
	local usePrompt   = (options.prompt ~= false)
	local intensity   = options.intensity or 2.5
	local range       = options.range or 20
	local useSurface  = (options.useSurfaceLight ~= false)
	local neonColor   = options.color or Color3.fromRGB(255,255,255)
	
	local keysRequired = options.keysRequired or 3
	local keyName      = options.keyName or "Key"

	if not build or not build.exitCell then return nil end

	local function parentTarget() return levelModel or levelFolder end
	local function cellCenter(x, z)
		local cx = cfg.ORIGIN.X + (x - 0.5) * cfg.CELL_SIZE.X
		local cz = cfg.ORIGIN.Z + (z - 0.5) * cfg.CELL_SIZE.Y
		return Vector3.new(cx, cfg.ORIGIN.Y, cz)
	end

	local center = cellCenter(build.exitCell.X, build.exitCell.Z)
	local halfX, halfZ = cfg.CELL_SIZE.X * 0.5, cfg.CELL_SIZE.Y * 0.5

	local door = Instance.new("Part")
	door.Name = "GlitchLightDoor"
	door.Anchored = true
	door.CanCollide = true
	door.Material = Enum.Material.Neon
	door.Color = neonColor
	door.Transparency = 0.2
	door.CastShadow = false
	door:SetAttribute("IsOpen", false) -- ¡NUEVO! Atributo para estado

	local edge = build.exitEdge or "S"
	local dH = cfg.DOOR_HEIGHT or 12
	local dW = cfg.DOOR_WIDTH  or 6
	local dT = cfg.DOOR_THICK  or 1

	if edge == "N" then
		door.Size = Vector3.new(dW, dH, dT)
		door.CFrame = CFrame.new(center + Vector3.new(0, dH*0.5, -(halfZ - gap)))
	elseif edge == "S" then
		door.Size = Vector3.new(dW, dH, dT)
		door.CFrame = CFrame.new(center + Vector3.new(0, dH*0.5,  (halfZ - gap)))
	elseif edge == "W" then
		door.Size = Vector3.new(dT, dH, dW)
		door.CFrame = CFrame.new(center + Vector3.new(-(halfX - gap), dH*0.5, 0))
	elseif edge == "E" then
		door.Size = Vector3.new(dT, dH, dW)
		door.CFrame = CFrame.new(center + Vector3.new( (halfX - gap), dH*0.5, 0))
	end

	door.Parent = parentTarget()

	-- ... (Lógica de la luz, sin cambios) ...
	if useSurface then
		local sl = Instance.new("SurfaceLight")
		sl.Brightness = intensity
		sl.Range = range
		sl.Color = Color3.fromRGB(255,255,255)
		if edge == "N" then sl.Face = Enum.NormalId.Back
		elseif edge == "S" then sl.Face = Enum.NormalId.Front
		elseif edge == "W" then sl.Face = Enum.NormalId.Right
		elseif edge == "E" then sl.Face = Enum.NormalId.Left
		end
		sl.Parent = door
	else
		local pl = Instance.new("PointLight")
		pl.Brightness = intensity
		pl.Range = range
		pl.Color = Color3.fromRGB(255,255,255)
		pl.Parent = door
	end

	-- Función de animación (solo se llama una vez)
	local function animateDoorOpen()
		door.CanCollide = false
		local t1 = TweenService:Create(door, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {Transparency = 0.6})
		t1:Play()
		-- ¡YA NO SE DESTRUYE NI SE HACE 100% TRANSPARENTE!
	end

	local keysInserted = Instance.new("IntValue")
	keysInserted.Name = "KeysInserted"
	keysInserted.Value = 0
	keysInserted.Parent = door

	local _, OpenExit, ShowToastMessage, DoorOpenedSignal = getSignals()

	if usePrompt then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Interactuar"
		prompt.ObjectText = string.format("Abrir (%d/%d)", 0, keysRequired)
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 9
		prompt.Parent = door

		keysInserted.Changed:Connect(function(newValue)
			if newValue < keysRequired then
				prompt.ObjectText = string.format("Abrir (%d/%d)", newValue, keysRequired)
			else
				prompt.ObjectText = "Salir al Lobby" -- ¡Texto cambiado!
				prompt.Enabled = true
			end
		end)

		-- ==== ¡LÓGICA DE PROMPT MODIFICADA! ====
		prompt.Triggered:Connect(function(player)
			
			-- Chequear si la puerta ya está abierta
			if door:GetAttribute("IsOpen") == true then
				print("[Door] La puerta ya estaba abierta. Respawneando jugador.")
				respawnPlayerToLobby(player)
				return
			end

			-- Si no está abierta, chequear llaves
			local keyTool = player.Backpack:FindFirstChild(keyName)
			if not keyTool then
				keyTool = player.Character:FindFirstChild(keyName)
			end

			if keyTool then
				keyTool:Destroy()
				keysInserted.Value = keysInserted.Value + 1
				
				local remaining = keysRequired - keysInserted.Value
				
				if remaining > 0 then
					local message = ""
					if remaining > 1 then
						message = string.format("Faltan %d llaves", remaining)
					else
						message = "Falta 1 llave"
					end
					ShowToastMessage:FireClient(player, message)
				
				elseif remaining == 0 then
					-- ¡ÚLTIMA LLAVE!
					print("[Door] ¡Última llave insertada!")
					ShowToastMessage:FireClient(player, "¡Puerta desbloqueada!")
					
					door:SetAttribute("IsOpen", true)
					DoorOpenedSignal:FireAllClients() -- ¡Avisar a todos!
					
					animateDoorOpen()
					respawnPlayerToLobby(player) -- Respawnear al primer jugador
				end
				
			else
				-- El jugador no tiene llave
				local remaining = keysRequired - keysInserted.Value
				local message = ""
				if remaining > 1 then
					message = string.format("Necesitas %d llaves más", remaining)
				else
					message = "Necesitas 1 llave más"
				end
				ShowToastMessage:FireClient(player, message)
			end
		end)
	end

	-- (Si la puerta se abre por señal (ej. admin))
	OpenExit.Event:Connect(function()
		if door:GetAttribute("IsOpen") == true then return end
		
		print("[Door] Abierta forzosamente por señal.")
		door:SetAttribute("IsOpen", true)
		keysInserted.Value = keysRequired
		DoorOpenedSignal:FireAllClients()
		animateDoorOpen()
	end)

	return door
end

return Door