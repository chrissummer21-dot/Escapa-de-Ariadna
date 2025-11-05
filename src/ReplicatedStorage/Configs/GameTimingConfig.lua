-- Config general del juego: timeline base y opciones
local GameTimingConfig = {
	-- Tag que ya tienen tus luces (ajusta aquí el tag real que detectaste)
	LightTag = "AllowLight",

	-- Volumen base global de música
	DefaultMusicVolume = 0.5,

	-- rbxassetid:// de la música principal (cámbialo por el tuyo)
	MainMusic = "rbxassetid://1843522152",

	-- Timeline de ejemplo (segundos desde t=0)
	-- Puedes añadir/editar cues a voluntad.
	Timeline = {
		{ t = 0.0,  action = "music:play",  params = { soundId = "inherit", volume = "inherit", looped = true } },
		
		-- ==== LÍNEAS MODIFICADAS ====
		{ t = 0.0,  action = "lights:group_on",  params = { group = "CeilingLamps" } }, -- Enciende solo las lámparas del techo
		{ t = 30.0, action = "lights:group_off", params = { group = "CeilingLamps" } }, -- Apaga solo las lámparas del techo
		-- ============================

		{ t = 5.0,  action = "lights:group_on",  params = { group = "EscenaA" } },
		{ t = 20.0, action = "event:announce",    params = { message = "¡Prepárense para el clímax!" } },
		{ t = 28.0, action = "music:fade",  params = { toVolume = 0.15, duration = 2.0 } },
		{ t = 32.0, action = "music:stop" },
	},

	-- Si es true, el timeline se repite al terminar
	LoopTimeline = false,

	-- Velocidad de reproducción del timeline (1.0 = normal)
	PlaybackRate = 1.0,
}

return GameTimingConfig