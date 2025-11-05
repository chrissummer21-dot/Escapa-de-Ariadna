-- TODO: paste code here
-- ReplicatedStorage/Modules/Backrooms/Door.lua
-- Puerta tipo “luz blanca” Neon + luz suave adicional.
-- Coloca la puerta ligeramente hacia el interior (gap) sin perforar muros.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Door = {}

-- options:
--   gap (number)                -> desplazamiento hacia adentro (default 2)
--   prompt (bool)               -> ProximityPrompt para abrir (default true)
--   intensity (number)          -> brillo de la luz (default 2.5)
--   range (number)              -> alcance de la luz (default 20)
--   useSurfaceLight (bool)      -> true = SurfaceLight (direccional), false = PointLight (omni). (default true)
--   color (Color3)              -> color del panel Neon (default blanco)
--   openBySignalOnly (bool)     -> si true, no crea prompt y solo abre con BackroomsSignals.OpenExit

local function getSignals()
	local signals = ReplicatedStorage:FindFirstChild("BackroomsSignals")
	if not signals then
		signals = Instance.new("Folder")
		signals.Name = "BackroomsSignals"
		signals.Parent = ReplicatedStorage
	end
	local ev = signals:FindFirstChild("OpenExit")
	if not ev then
		ev = Instance.new("BindableEvent")
		ev.Name = "OpenExit"
		ev.Parent = signals
	end
	return signals, ev
end

function Door.PlaceLightDoor(cfg, build, levelModel, levelFolder, options)
	options = options or {}
	local gap         = options.gap or 2
	local usePrompt   = (options.prompt ~= false) and (options.openBySignalOnly ~= true)
	local intensity   = options.intensity or 2.5
	local range       = options.range or 20
	local useSurface  = (options.useSurfaceLight ~= false) -- default true
	local neonColor   = options.color or Color3.fromRGB(255,255,255)

	if not build or not build.exitCell then return nil end

	local function parentTarget() return levelModel or levelFolder end
	local function cellCenter(x, z)
		local cx = cfg.ORIGIN.X + (x - 0.5) * cfg.CELL_SIZE.X
		local cz = cfg.ORIGIN.Z + (z - 0.5) * cfg.CELL_SIZE.Y
		return Vector3.new(cx, cfg.ORIGIN.Y, cz)
	end

	local center = cellCenter(build.exitCell.X, build.exitCell.Z)
	local halfX, halfZ = cfg.CELL_SIZE.X * 0.5, cfg.CELL_SIZE.Y * 0.5

	-- Panel NEON (blanco) como puerta
	local door = Instance.new("Part")
	door.Name = "GlitchLightDoor"
	door.Anchored = true
	door.CanCollide = true
	door.Material = Enum.Material.Neon
	door.Color = neonColor             -- Neon blanco
	door.Transparency = 0.2            -- un poco más suave que 0.1
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

	-- Luz suave blanca adicional
	if useSurface then
		local sl = Instance.new("SurfaceLight")
		sl.Brightness = intensity
		sl.Range = range
		sl.Color = Color3.fromRGB(255,255,255)
		-- orienta hacia el interior del pasillo según el borde
		if edge == "N" then sl.Face = Enum.NormalId.Back      -- emite hacia +Z
		elseif edge == "S" then sl.Face = Enum.NormalId.Front -- emite hacia -Z
		elseif edge == "W" then sl.Face = Enum.NormalId.Right -- emite hacia +X
		elseif edge == "E" then sl.Face = Enum.NormalId.Left  -- emite hacia -X
		end
		sl.Parent = door
	else
		local pl = Instance.new("PointLight")
		pl.Brightness = intensity
		pl.Range = range
		pl.Color = Color3.fromRGB(255,255,255)
		pl.Parent = door
	end

	-- Abrir (desvanecer y quitar colisión)
	local opening = false
	local function open()
		if opening then return end
		opening = true
		door.CanCollide = false
		local t1 = TweenService:Create(door, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.6})
		local t2 = TweenService:Create(door, TweenInfo.new(0.35, Enum.EasingStyle.Sine), {Transparency = 1})
		t1:Play(); t1.Completed:Wait(); t2:Play()
	end

	-- Interacción manual (si no se fuerza solo por señal)
	if usePrompt then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Entrar"
		prompt.ObjectText = "Luz"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 9
		prompt.Parent = door
		prompt.Triggered:Connect(open)
	end

	-- Señal para abrir por tareas
	local _, OpenExit = getSignals()
	OpenExit.Event:Connect(open)

	return door
end

return Door
