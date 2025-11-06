-- ReplicatedStorage/Modules/Backrooms/Door.lua
-- MODIFICADO: Usa un RemoteEvent para enviar un "toast" al cliente
-- en lugar de cambiar el ObjectText.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Door = {}

-- (NUEVO) Modificamos getSignals para que también maneje el RemoteEvent
local function getSignals()
	local signals = ReplicatedStorage:FindFirstChild("BackroomsSignals")
	if not signals then
		signals = Instance.new("Folder")
		signals.Name = "BackroomsSignals"
		signals.Parent = ReplicatedStorage
	end
	
	local openExit = signals:FindFirstChild("OpenExit")
	if not openExit then
		openExit = Instance.new("BindableEvent")
		openExit.Name = "OpenExit"
		openExit.Parent = signals
	end
	
	-- (NUEVO) Añadir el RemoteEvent para los mensajes toast
	local showToast = signals:FindFirstChild("ShowToastMessage")
	if not showToast then
		showToast = Instance.new("RemoteEvent")
		showToast.Name = "ShowToastMessage"
		showToast.Parent = signals
	end
	
	return signals, openExit, showToast
end

function Door.PlaceLightDoor(cfg, build, levelModel, levelFolder, options)
	options = options or {}
	local gap         = options.gap or 2
	local usePrompt   = (options.prompt ~= false) and (options.openBySignalOnly ~= true)
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

	local opening = false
	local function open()
		if opening then return end
		opening = true
		door.CanCollide = false
		local t1 = TweenService:Create(door, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.6})
		local t2 = TweenService:Create(door, TweenInfo.new(0.35, Enum.EasingStyle.Sine), {Transparency = 1})
		t1:Play(); t1.Completed:Wait(); t2:Play()
	end

	local keysInserted = Instance.new("IntValue")
	keysInserted.Name = "KeysInserted"
	keysInserted.Value = 0
	keysInserted.Parent = door

	-- (MODIFICADO) Obtener el nuevo RemoteEvent
	local _, OpenExit, ShowToastMessage = getSignals()

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
				prompt.ObjectText = "Abierto"
				prompt.Enabled = false
			end
		end)

		prompt.Triggered:Connect(function(player)
			if opening or keysInserted.Value >= keysRequired then return end

			local keyTool = player.Backpack:FindFirstChild(keyName)
			if not keyTool then
				keyTool = player.Character:FindFirstChild(keyName)
			end

			if keyTool then
				keyTool:Destroy()
				keysInserted.Value = keysInserted.Value + 1
				if keysInserted.Value >= keysRequired then
					open()
				end
			else
				-- (INICIO DE MODIFICACIÓN)
				-- 4. No tiene llave: Disparar el RemoteEvent al cliente
				local remaining = keysRequired - keysInserted.Value
				local message = ""
				if remaining > 1 then
					message = string.format("Necesitas %d llaves más", remaining)
				else
					message = "Necesitas 1 llave más"
				end
				
				-- Dispara el evento SOLO a ese jugador
				ShowToastMessage:FireClient(player, message)
				-- (FIN DE MODIFICACIÓN)
			end
		end)
	end

	OpenExit.Event:Connect(open)

	return door
end

return Door