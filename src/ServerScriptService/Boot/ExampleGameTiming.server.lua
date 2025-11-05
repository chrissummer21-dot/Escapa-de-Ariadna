-- ServerScriptService/Boot/ExampleGameTiming.server.lua
-- Arranca DESPUÉS de que las lámparas estén colocadas
-- Espera señal LevelBuilt para asegurar sincronización

local RunService = game:GetService("RunService")
if RunService:IsClient() then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local GameTimingConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("GameTimingConfig"))
local LightController = require(script.Parent.Parent:WaitForChild("Systems"):WaitForChild("Lighting"):WaitForChild("LightController"))
local TimingController = require(script.Parent.Parent:WaitForChild("Systems"):WaitForChild("Timing"):WaitForChild("TimingController"))

-- ========= LÓGICA DE ILUMINACIÓN GLOBAL (UNIFICADA) =========

-- Este es el estado "ENCENDIDO" (basado en tu script NightLock.server.lua)
local function applyLighting_Normal()
	print("[GameTiming] Aplicando iluminación NORMAL (Noche)")
	Lighting.Brightness = 1.5
	Lighting.ClockTime = 2
	Lighting.GeographicLatitude = 0
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	
	-- Resetea la configuración de Blackout
	Lighting.Ambient = Color3.fromRGB(50, 50, 50) -- Un poco de luz ambiental
	Lighting.OutdoorAmbient = Color3.fromRGB(50, 50, 50)
	Lighting.ExposureCompensation = 0.0
	Lighting.FogEnd = 100000 -- Niebla lejana
	Lighting.FogColor = Color3.fromRGB(0, 0, 0) -- Niebla oscura pero no total
	
	-- Habilita efectos visuales si existen
	for _, eff in ipairs(Lighting:GetChildren()) do
		if eff:IsA("BloomEffect") or eff:IsA("ColorCorrectionEffect") then
			eff.Enabled = true
		end
	end
end

-- Este es el estado "APAGADO" (basado en tu script BackroomsBlackout.server.lua)
local function applyLighting_Blackout()
	print("[GameTiming] Aplicando iluminación BLACKOUT (Oscuridad total)")
	Lighting.Brightness = 0
	Lighting.ClockTime = 2
	Lighting.Ambient = Color3.new(0,0,0)
	Lighting.OutdoorAmbient = Color3.new(0,0,0)
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.ExposureCompensation = -2.0 -- Empuja a negro
	Lighting.FogColor = Color3.new(0,0,0) -- Niebla negra
	Lighting.FogStart = 0
	Lighting.FogEnd = 1000000 -- Niebla densa
	
	-- Deshabilita efectos visuales
	for _, eff in ipairs(Lighting:GetChildren()) do
		if eff:IsA("BloomEffect") or eff:IsA("SunRaysEffect") or eff:IsA("ColorCorrectionEffect") then
			eff.Enabled = false
		end
	end
end

-- ========= ESPERAR A QUE EL NIVEL ESTÉ LISTO =========
local function waitForLevelBuilt(timeout)
	-- === CORRECCIÓN DE RACE CONDITION ===
	-- Usamos WaitForChild para esperar a que BackroomsGenerator cree la carpeta
	local signals = ReplicatedStorage:WaitForChild("BackroomsSignals", timeout)
	if not signals then
		warn("[GameTiming] ⚠ Timeout: No se encontró BackroomsSignals después de " .. tostring(timeout) .. "s")
		return false
	end
	
	local evt = signals:FindFirstChild("LevelBuilt")
	if not evt or not evt:IsA("BindableEvent") then
		warn("[GameTiming] No se encontró LevelBuilt event")
		return false
	end
	
	local fired = false
	evt.Event:Connect(function()
		fired = true
		print("[GameTiming] ✓ Señal LevelBuilt recibida")
	end)
	
	local t0 = os.clock()
	-- Esperamos un poco más en caso de que la señal ya se haya disparado
	while not fired and (os.clock() - t0) < timeout do
		task.wait(0.1)
	end
	
	return fired
end

-- ========= ESPERAR A QUE EXISTAN LÁMPARAS =========
local function waitForLamps(timeout)
	local t0 = os.clock()
	while (os.clock() - t0) < timeout do
		local tagged = CollectionService:GetTagged(GameTimingConfig.LightTag)
		if #tagged > 0 then
			print(string.format("[GameTiming] ✓ Encontradas %d luces con tag '%s'", #tagged, GameTimingConfig.LightTag))
			return true
		end
		task.wait(0.2)
	end
	warn(string.format("[GameTiming] ⚠ Timeout: no se encontraron luces después de %.1fs", timeout))
	return false
end

-- Aplicar oscuridad total AL INICIO para que no se vea la carga
applyLighting_Blackout()

print("[GameTiming] Esperando a que el nivel esté construido...")

-- Esperar nivel
if not waitForLevelBuilt(10) then
	warn("[GameTiming] No se detectó LevelBuilt. (Esto puede ser normal si el generador terminó antes de que este script esperara)")
end

-- Esperar lámparas (ScatterCeilingLamps corre después de LevelBuilt)
if not waitForLamps(5) then
	warn("[GameTiming] ⚠ No se encontraron lámparas. El sistema de timing continuará pero sin control de luces.")
end

-- ========= INICIALIZAR CONTROLADORES =========
print("[GameTiming] Inicializando LightController...")
local lights = LightController.new()

-- CRÍTICO: Registrar luces POR TAG (esto detecta luces existentes Y futuras)
lights:RegisterTag(GameTimingConfig.LightTag, true)

-- Verificar cuántas luces se registraron
local initialCount = #CollectionService:GetTagged(GameTimingConfig.LightTag)
print(string.format("[GameTiming] LightController registró %d luces iniciales", initialCount))

print("[GameTiming] Inicializando TimingController...")
local timing = TimingController.new({
	Timeline = GameTimingConfig.Timeline,
	LoopTimeline = GameTimingConfig.LoopTimeline,
	PlaybackRate = GameTimingConfig.PlaybackRate,
	DefaultMusicVolume = GameTimingConfig.DefaultMusicVolume,
	MainMusic = GameTimingConfig.MainMusic,
})

-- ========= REGISTRAR HANDLERS DE LUCES =========

-- ACCIONES DE GRUPO (PARA LÁMPARAS DEL TECHO)
timing:OnAction("lights:group_on", function(p)
	if p and p.group then
		print(string.format("[GameTiming] → Acción: lights:group_on (grupo='%s')", p.group))
		lights:GroupOn(p.group)
		
		-- Si estamos encendiendo el grupo principal, restaurar la luz global
		if p.group == "CeilingLamps" then
			applyLighting_Normal()
		end
	end
end)

timing:OnAction("lights:group_off", function(p)
	if p and p.group then
		print(string.format("[GameTiming] → Acción: lights:group_off (grupo='%s')", p.group))
		lights:GroupOff(p.group)
		
		-- Si estamos apagando el grupo principal, activar la oscuridad total
		if p.group == "CeilingLamps" then
			applyLighting_Blackout()
		end
	end
end)

-- ACCIONES GLOBALES (POR SI LAS USAS)
timing:OnAction("lights:all_on", function()
	print("[GameTiming] → Acción: lights:all_on")
	lights:AllOn()
	applyLighting_Normal() -- Restaurar luz global
end)

timing:OnAction("lights:all_off", function()
	print("[GameTiming] → Acción: lights:all_off")
	lights:AllOff()
	applyLighting_Blackout() -- Activar oscuridad total
end)


-- Propiedades opcionales
timing:OnAction("lights:set_brightness", function(p)
	if p and p.target and p.value then
		lights:SetBrightness(p.target, p.value)
	end
end)

timing:OnAction("lights:set_color", function(p)
	if p and p.target and p.rgb then
		local c = Color3.fromRGB(p.rgb[1], p.rgb[2], p.rgb[3])
		lights:SetColor(p.target, c)
	end
end)

-- ========= EVENTOS GENÉRICOS =========
timing:OnAction("event:announce", function(p)
	local msg = p and p.message or "(sin mensaje)"
	print(string.format("[GameTiming] 📢 ANNOUNCE: %s", msg))
	-- Aquí podrías disparar RemoteEvents a clientes para UI
end)

-- ========= DEPURACIÓN: Monitorear TODOS los cues =========
timing.CueFired.Event:Connect(function(actionName, params)
	print(string.format("[GameTiming] 🎬 Cue disparado: '%s' | t=%.2fs", actionName, timing._acc or 0))
end)

-- ========= EJECUTAR TIMELINE =========
print("[GameTiming] ▶ Iniciando timeline...")
timing:Play()

print("[GameTiming] ✓ Sistema de timing activo")