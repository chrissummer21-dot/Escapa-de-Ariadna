-- ServerScriptService/NightLock.server.lua
-- Mantiene el mundo siempre de noche (hora fija).

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local NIGHT_HOUR = 2            -- 2:00 AM (ajusta entre 0–24)
local UPDATE_EVERY = 0          -- 0 = cada frame del servidor; o pon 1 para cada segundo

-- Ajustes opcionales para una noche más oscura/suave:
Lighting.Brightness = 1.5
Lighting.ClockTime = NIGHT_HOUR
Lighting.GeographicLatitude = 0          -- evita amaneceres raros
Lighting.EnvironmentDiffuseScale = 0.5   -- menos luz ambiental
Lighting.EnvironmentSpecularScale = 0.5  -- menos reflejo ambiente

-- Si existe un ColorCorrection/Bloom, puedes dejarlos como estén.
-- Este bucle reimpone la hora para que no avance.
if UPDATE_EVERY == 0 then
	RunService.Stepped:Connect(function()
		if Lighting.ClockTime ~= NIGHT_HOUR then
			Lighting.ClockTime = NIGHT_HOUR
		end
	end)
else
	while true do
		Lighting.ClockTime = NIGHT_HOUR
		task.wait(UPDATE_EVERY)
	end
end
