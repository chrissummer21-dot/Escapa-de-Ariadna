-- Arranque de ejemplo: carga config, arma LightController y TimingController,
-- registra acciones de luces y de eventos genÃ©ricos, y corre el timeline.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameTimingConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("GameTimingConfig"))

-- LÍNEAS NUEVAS Y CORREGIDAS:
local LightController = require(script.Parent.Parent:WaitForChild("Systems"):WaitForChild("Lighting"):WaitForChild("LightController"))
local TimingController = require(script.Parent.Parent:WaitForChild("Systems"):WaitForChild("Timing"):WaitForChild("TimingController"))

-- 1) Instanciar controladores
local lights = LightController.new()
-- Registra luces por tag (si quieres agrupar por nombre del padre, pasa true como 2Âº arg)
lights:RegisterTag(GameTimingConfig.LightTag, true)

local timing = TimingController.new({
	Timeline = GameTimingConfig.Timeline,
	LoopTimeline = GameTimingConfig.LoopTimeline,
	PlaybackRate = GameTimingConfig.PlaybackRate,
	DefaultMusicVolume = GameTimingConfig.DefaultMusicVolume,
	MainMusic = GameTimingConfig.MainMusic,
})

-- 2) Handlers de luces (nombres de acciÃ³n que usarÃ¡ el timeline)
timing:OnAction("lights:all_on", function() lights:AllOn() end)
timing:OnAction("lights:all_off", function() lights:AllOff() end)
timing:OnAction("lights:group_on", function(p) if p and p.group then lights:GroupOn(p.group) end end)
timing:OnAction("lights:group_off", function(p) if p and p.group then lights:GroupOff(p.group) end end)

-- TambiÃ©n propiedades (opcional)
timing:OnAction("lights:set_brightness", function(p)
	if p and p.target and p.value then lights:SetBrightness(p.target, p.value) end
end)
timing:OnAction("lights:set_color", function(p)
	if p and p.target and p.rgb then
		local c = Color3.fromRGB(p.rgb[1], p.rgb[2], p.rgb[3])
		lights:SetColor(p.target, c)
	end
end)

-- 3) Events genÃ©ricos (para UI, letreros, triggers, etc.)
timing:OnAction("event:announce", function(p)
	print("[ANNOUNCE]", p and p.message or "(sin mensaje)")
	-- AquÃ­ podrÃ­as disparar RemoteEvents a clientes, UI, etc.
end)

-- 4) Ejecutar timeline
timing:Play()

-- Ejemplos extra (runtime):
-- task.delay(10, function() timing:Pause() end)
-- task.delay(13, function() timing:Seek(25); timing:Play() end)
-- task.delay(40, function() timing:Stop() end)
