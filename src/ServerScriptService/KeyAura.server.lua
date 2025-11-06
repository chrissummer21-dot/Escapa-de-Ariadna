-- ServerScriptService/VFX/KeyAura.server.lua
-- Da un halo blanco/plateado + luz + partículas a las llaves del mapa.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG_NAME = "Key" -- Tag para tus llaves

local CFG = {
	highlight = {
		fillColor = Color3.fromRGB(245, 245, 255), -- blanco tirando a plateado
		outlineColor = Color3.fromRGB(255, 255, 255),
		fillTransparency = 0.15,   -- más bajo = más “opaco”
		outlineTransparency = 0.0,
		depthMode = Enum.HighlightDepthMode.Occluded, -- Occluded = no atraviesa paredes
	},

	light = {
		enabled = true,
		brightness = 1.6,  -- sube si quieres más punch
		range = 10,
		color = Color3.fromRGB(255, 255, 255),
		shadows = false,
	},

	particles = {
		enabled = true,
		rate = 7, -- pocas partículas para no saturar
		lifetime = NumberRange.new(0.8, 1.4),
		speed = NumberRange.new(0.2, 0.8),
		drag = 2.5,
		spreadAngle = Vector2.new(12, 12),
		accel = Vector3.new(0, 1.5, 0), -- un leve ascenso
		lightEmission = 0.6,
		size = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.25),
			NumberSequenceKeypoint.new(0.4, 0.14),
			NumberSequenceKeypoint.new(1.0, 0.0),
		}),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.15),
			NumberSequenceKeypoint.new(0.7, 0.35),
			NumberSequenceKeypoint.new(1.0, 1.0),
		}),
		rotSpeed = NumberRange.new(-45, 45),
		color = ColorSequence.new(Color3.fromRGB(255,255,255)), -- blanco
		texture = "rbxassetid://243660364" -- puntito suave (puedes cambiarlo)
	}
}

local function ensurePrimaryPart(model: Model): BasePart?
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	-- heuristic: Handle, o la primera BasePart
	local handle = model:FindFirstChild("Handle", true)
	if handle and handle:IsA("BasePart") then
		model.PrimaryPart = handle
		return handle
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			model.PrimaryPart = d
			return d
		end
	end
	return nil
end

local function alreadyHasVFX(model: Model): boolean
	return model:FindFirstChild("KeyVFX_Folder") ~= nil
end

local function addHighlight(model: Model)
	local h = Instance.new("Highlight")
	h.Name = "KeyVFX_Highlight"
	h.FillColor = CFG.highlight.fillColor
	h.OutlineColor = CFG.highlight.outlineColor
	h.FillTransparency = CFG.highlight.fillTransparency
	h.OutlineTransparency = CFG.highlight.outlineTransparency
	h.DepthMode = CFG.highlight.depthMode
	h.Parent = model -- al parentear al Model se adorna automáticamente
end

local function addLight(pp: BasePart, parent: Instance)
	if not CFG.light.enabled then return end
	local l = Instance.new("PointLight")
	l.Name = "KeyVFX_Light"
	l.Brightness = CFG.light.brightness
	l.Range = CFG.light.range
	l.Color = CFG.light.color
	l.Shadows = CFG.light.shadows
	l.Parent = parent -- parent al Attachment (mejor) o a la part
end

local function addParticles(pp: BasePart, parent: Instance)
	if not CFG.particles.enabled then return end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "KeyVFX_Particles"
	emitter.Enabled = true
	emitter.Rate = CFG.particles.rate
	emitter.Lifetime = CFG.particles.lifetime
	emitter.Speed = CFG.particles.speed
	emitter.Drag = CFG.particles.drag
	emitter.SpreadAngle = CFG.particles.spreadAngle
	emitter.Acceleration = CFG.particles.accel
	emitter.LightEmission = CFG.particles.lightEmission
	emitter.Size = CFG.particles.size
	emitter.Transparency = CFG.particles.transparency
	emitter.RotSpeed = CFG.particles.rotSpeed
	emitter.Color = CFG.particles.color
	emitter.Texture = CFG.particles.texture
	emitter.LockedToPart = false
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = parent
end

local function applyVFX(model: Model)
	if not model or not model.Parent then return end
	if alreadyHasVFX(model) then return end

	local pp = ensurePrimaryPart(model)
	if not pp then return end

	-- Carpeta contenedora para limpiar fácil
	local folder = Instance.new("Folder")
	folder.Name = "KeyVFX_Folder"
	folder.Parent = model

	-- Highlight (en el Model directamente)
	addHighlight(model)

	-- Attachment central para luz/partículas (mejor control)
	local att = Instance.new("Attachment")
	att.Name = "KeyVFX_Attachment"
	att.WorldCFrame = pp.CFrame -- centrado
	att.Parent = pp
	att.Parent = folder -- mantener todo junto

	addLight(pp, att)
	addParticles(pp, att)
end

local function isKeyModel(inst: Instance): boolean
	if not inst:IsA("Model") then return false end
	if CollectionService:HasTag(inst, TAG_NAME) then return true end
	if inst:GetAttribute("IsKey") == true then return true end
	return inst.Name == "Key"
end

-- Escaneo inicial
local function scanWorkspace()
	for _, inst in ipairs(workspace:GetDescendants()) do
		if isKeyModel(inst) then
			applyVFX(inst)
		end
	end
end

-- Reacciona a nuevos con tag
CollectionService:GetInstanceAddedSignal(TAG_NAME):Connect(function(inst)
	if inst:IsA("Model") then
		applyVFX(inst)
	end
end)

-- Si alguien quita el tag y quieres remover VFX, podrías escuchar GetInstanceRemovedSignal.
-- Aquí lo dejamos permanente mientras exista el Model.

-- Escucha nuevos modelos que parezcan llaves por atributo/nombre
workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("Model") and isKeyModel(inst) then
		applyVFX(inst)
	end
end)

-- Arranque
scanWorkspace()
