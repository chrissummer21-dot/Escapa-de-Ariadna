-- Config general del juego: timeline base y opciones
local GameTimingConfig = {
	-- Tag que ya tienen tus luces (ajusta aquÃƒÂ­ el tag real que detectaste)
	LightTag = "Lamp",

	-- Volumen base global de mÃƒÂºsica
	DefaultMusicVolume = 0.5,

	-- rbxassetid:// de la mÃƒÂºsica principal (cÃƒÂ¡mbialo por el tuyo)
	MainMusic = "rbxassetid://1843522152",

	-- Timeline de ejemplo (segundos desde t=0)
	-- Puedes aÃƒÂ±adir/editar cues a voluntad.
	Timeline = {
		{ t = 0.0,  action = "music:play",  params = { soundId = "inherit", volume = "inherit", looped = true } },
		{ t = 0.0,  action = "lights:all_on" },
		{ t = 5.0,  action = "lights:group_on",  params = { group = "EscenaA" } },
		{ t = 20.0, action = "event:announce",    params = { message = "Ã‚Â¡PrepÃƒÂ¡rense para el clÃƒÂ­max!" } },
		{ t = 28.0, action = "music:fade",  params = { toVolume = 0.15, duration = 2.0 } },
		{ t = 30.0, action = "lights:all_off" }, -- equivalente al Ã¢â‚¬Å“auto-offÃ¢â‚¬Â de 30s, pero desde el timeline
		{ t = 32.0, action = "music:stop" },
	},

	-- Si es true, el timeline se repite al terminar
	LoopTimeline = false,

	-- Velocidad de reproducciÃƒÂ³n del timeline (1.0 = normal)
	PlaybackRate = 1.0,
}

return GameTimingConfig
