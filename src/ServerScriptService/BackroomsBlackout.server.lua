-- ServerScriptService/BackroomsBlackout.server.lua
-- Apaga toda la iluminación global y bloquea luces nuevas,
-- excepto las que estén dentro de "GlitchLightDoor" o con tag "AllowLight".

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

-- 1) Oscuridad total (global)
local function applyBlackout()
	Lighting.ClockTime = 2            -- irrelevante con brillo 0, pero por si acaso
	Lighting.Brightness = 0
	Lighting.Ambient = Color3.new(0,0,0)
	Lighting.OutdoorAmbient = Color3.new(0,0,0)
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.ExposureCompensation = -2.0  -- empuja a negro
	Lighting.FogColor = Color3.new(0,0,0)
	Lighting.FogStart = 0
	Lighting.FogEnd = 1000000          -- usa negrura por exposición/ambient, no niebla densa cercana
	-- Quita efectos de brillo/tonemapping si los hay
	for _, eff in ipairs(Lighting:GetChildren()) do
		if eff:IsA("BloomEffect") or eff:IsA("SunRaysEffect") or eff:IsA("ColorCorrectionEffect") then
			eff.Enabled = false
		end
	end
end
applyBlackout()

-- 2) Regla: deshabilitar TODAS las luces, salvo las permitidas
local function isAllowed(light: Instance): boolean
	-- Permitimos luces dentro del modelo de la puerta o con tag AllowLight
	if CollectionService:HasTag(light, "AllowLight") then
		return true
	end
	local ancestor = light
	while ancestor do
		if ancestor.Name == "GlitchLightDoor" then
			return true
		end
		ancestor = ancestor.Parent
	end
	return false
end

local function enforceLight(light: Instance)
	if light:IsA("PointLight") or light:IsA("SpotLight") or light:IsA("SurfaceLight") then
		light.Enabled = isAllowed(light)
	end
end

-- Aplicar a luces ya existentes
for _, desc in ipairs(workspace:GetDescendants()) do
	enforceLight(desc)
end
for _, desc in ipairs(Lighting:GetDescendants()) do
	enforceLight(desc)
end

-- Vigilar nuevas luces
workspace.DescendantAdded:Connect(enforceLight)
Lighting.DescendantAdded:Connect(enforceLight)

-- 3) (Opcional) si quieres desactivar sombras globales para ganar FPS en negro:
-- Lighting.GlobalShadows = false
