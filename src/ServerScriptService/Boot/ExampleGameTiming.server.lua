-- ServerScriptService/Boot/ExampleGameTiming.server.lua
-- Arranca DESPUÉS de que las lámparas estén colocadas
-- Espera señal LevelBuilt para asegurar sincronización

local RunService = game:GetService("RunService")
if RunService:IsClient() then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTimingConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("GameTimingConfig"))

local LightController = require(script.Parent.Parent:WaitForChild("Systems"):WaitForChild("Lighting"):WaitForChild("LightController"))
local TimingController = require(script.Parent.Parent:WaitForChild("Systems"):WaitForChild("Timing"):WaitForChild("TimingController"))

-- ========= ESPERAR A QUE EL NIVEL ESTÉ LISTO =========
local function waitForLevelBuilt(timeout)
	local signals = ReplicatedStorage:FindFirstChild("BackroomsSignals")
	if not signals then
		warn("[GameTiming] No se encontró BackroomsSignals")
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
	while not fired and (os.clock() - t0) < timeout do
		task.wait(0.1)
	end
	
	return fired
end

-- ========= ESPERAR A QUE EXISTAN LÁMPARAS =========
local CollectionService = game:GetService("CollectionService")

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

print("[GameTiming] Esperando a que el nivel esté construido...")

-- Esperar nivel
if not waitForLevelBuilt(10) then
	warn("[GameTiming] No se detectó LevelBuilt, continuando de todas formas...")
end

-- Esperar lámparas (extra safety: ScatterCeilingLamps corre después de LevelBuilt)
task.wait(2) -- pausa adicional para ScatterCeilingLamps
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
timing:OnAction("lights:all_on", function()
	print("[GameTiming] → Acción: lights:all_on")
	lights:AllOn()
end)

timing:OnAction("lights:all_off", function()
	print("[GameTiming] → Acción: lights:all_off")
	lights:AllOff()
end)

timing:OnAction("lights:group_on", function(p)
	if p and p.group then
		print(string.format("[GameTiming] → Acción: lights:group_on (grupo='%s')", p.group))
		lights:GroupOn(p.group)
	end
end)

timing:OnAction("lights:group_off", function(p)
	if p and p.group then
		print(string.format("[GameTiming] → Acción: lights:group_off (grupo='%s')", p.group))
		lights:GroupOff(p.group)
	end
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

-- Ejemplos de control manual (comentados):
-- task.delay(10, function() timing:Pause(); print("[GameTiming] ⏸ Pausado") end)
-- task.delay(13, function() timing:Seek(25); timing:Play(); print("[GameTiming] ⏩ Saltado a t=25s") end)
-- task.delay(40, function() timing:Stop(); print("[GameTiming] ⏹ Detenido") end)