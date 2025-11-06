-- src/ServerScriptService/BackroomsBlackout.lua
-- CONVERTIDO A MODULESCRIPT
-- Contiene la función para aplicar la oscuridad total del Backroom.

local Lighting = game:GetService("Lighting")

local BackroomsBlackout = {}

-- 1) La función original de oscuridad
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

-- 2) Nueva función "Apply" que será llamada por el Generador
function BackroomsBlackout.Apply()
	print("[Blackout] Aplicando oscuridad total del Backroom.")
	applyBlackout()
end

-- (Eliminamos la llamada original applyBlackout() de aquí)

return BackroomsBlackout