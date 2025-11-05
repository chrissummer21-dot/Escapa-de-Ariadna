-- ServerScriptService/BackroomsBlackout.server.lua
-- MODIFICADO: Aplica oscuridad global (Lighting),
-- pero ignora por completo las luces individuales (lámparas).

local Lighting = game:GetService("Lighting")
-- Ya no necesitamos CollectionService

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
    -- (Corregí un error de tu script original, que los ponía en 'true' en lugar de 'false')
	for _, eff in ipairs(Lighting:GetChildren()) do
		if eff:IsA("BloomEffect") or eff:IsA("SunRaysEffect") or eff:IsA("ColorCorrectionEffect") then
			eff.Enabled = false
		end
	end
end

-- Aplicar la oscuridad global al iniciar
applyBlackout()

-- 2) SECCIÓN ELIMINADA
-- Ya no se incluye la lógica 'isAllowed' ni 'enforceLight'.
-- Este script ya no vigila ni apaga las luces individuales.
-- Las lámparas (con tag "AllowLight") se quedarán como estén (encendidas si la plantilla lo está).

-- 3) (Opcional) si quieres desactivar sombras globales para ganar FPS en negro:
-- Lighting.GlobalShadows = false