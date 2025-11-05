--!strict
-- TimingController: orquesta un timeline de cues (música, luces, eventos).
-- Permite play/pause/seek, loop y playback rate. Registras handlers por acción.
-- Uso típico: inyectar LightController y registrar handlers default.

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

export type Cue = { t: number; action: string; params: any? }
export type Handler = (params: any?) -> ()

local TimingController = {}
TimingController.__index = TimingController

type Opts = {
	Timeline: { Cue },
	LoopTimeline: boolean?,
	PlaybackRate: number?,
	DefaultMusicVolume: number?,
	MainMusic: string?,
}

function TimingController.new(opts: Opts)
	local self = setmetatable({}, TimingController)

	self._timeline = table.clone(opts.Timeline or {}) :: { Cue }
	table.sort(self._timeline, function(a, b) return a.t < b.t end)

	self._loop = opts.LoopTimeline == true
	self._rate = opts.PlaybackRate or 1.0
	self._handlers = {} :: {[string]: Handler}
	self._playing = false
	self._t0 = 0.0
	self._acc = 0.0
	self._cursor = 1
	self._conn = nil :: RBXScriptConnection?

	-- Música base
	self._sound = Instance.new("Sound")
	self._sound.Name = "GameMusic"
	self._sound.SoundId = (opts.MainMusic and opts.MainMusic ~= "inherit") and opts.MainMusic or ""
	self._sound.Volume = opts.DefaultMusicVolume or 0.5
	self._sound.Looped = false
	self._sound.Parent = SoundService

	-- Evento para terceros (opcional)
	self.CueFired = Instance.new("BindableEvent")

	return self
end

-- ===== Registro de handlers =====
function TimingController:OnAction(actionName: string, fn: Handler)
	self._handlers[actionName] = fn
end

local function fire(self, actionName: string, params: any?)
	local h = self._handlers[actionName]
	if h then h(params) end
	self.CueFired:Fire(actionName, params)
end

-- ===== Control de música (handlers por defecto) =====
function TimingController:_registerDefaultMusicHandlers()
	self:OnAction("music:play", function(params)
		local id = params and params.soundId or "inherit"
		if id and id ~= "inherit" then
			self._sound.SoundId = id
		end
		if params and params.volume and params.volume ~= "inherit" then
			self._sound.Volume = params.volume
		end
		self._sound.Looped = (params and params.looped) == true
		self._sound:Play()
	end)

	self:OnAction("music:stop", function(_)
		self._sound:Stop()
	end)

	self:OnAction("music:fade", function(params)
		local toV = (params and params.toVolume) or 0.0
		local dur = (params and params.duration) or 1.0
		local fromV = self._sound.Volume
		local t0 = os.clock()
		task.spawn(function()
			while true do
				local dt = os.clock() - t0
				local alpha = math.clamp(dt / dur, 0, 1)
				self._sound.Volume = fromV + (toV - fromV) * alpha
				if alpha >= 1 then break end
				RunService.Heartbeat:Wait()
			end
		end)
	end)
end

-- ===== Reproducción del timeline =====
function TimingController:Play()
	if self._playing then return end
	self._playing = true
	self._t0 = os.clock()
	self._conn = RunService.Heartbeat:Connect(function()
		self:_tick()
	end)
end

function TimingController:Pause()
	if not self._playing then return end
	self._playing = false
	if self._conn then self._conn:Disconnect(); self._conn = nil end
end

function TimingController:Stop()
	self:Pause()
	self._acc = 0
	self._cursor = 1
end

function TimingController:Seek(seconds: number)
	self._acc = math.max(0, seconds)
	-- reposicionar cursor
	local i = 1
	while i <= #self._timeline and self._timeline[i].t < self._acc do
		i += 1
	end
	self._cursor = i
end

function TimingController:SetRate(rate: number)
	self._rate = rate
end

function TimingController:_duration()
	if #self._timeline == 0 then return 0 end
	return self._timeline[#self._timeline].t
end

function TimingController:_tick()
	if not self._playing then return end
	local now = os.clock()
	local dt = (now - self._t0) * self._rate
	self._t0 = now
	self._acc += dt

	-- disparar cues pendientes
	while self._cursor <= #self._timeline and self._timeline[self._cursor].t <= self._acc do
		local cue = self._timeline[self._cursor]
		fire(self, cue.action, cue.params)
		self._cursor += 1
	end

	-- loop si terminó
	if self._cursor > #self._timeline then
		if self._loop then
			self:Seek(0)
		else
			self:Pause()
		end
	end
end

-- ===== Utilidades =====
function TimingController:AppendCue(cue: Cue)
	table.insert(self._timeline, cue)
	table.sort(self._timeline, function(a,b) return a.t < b.t end)
end

function TimingController:AppendCues(cues: {Cue})
	for _, c in ipairs(cues) do table.insert(self._timeline, c) end
	table.sort(self._timeline, function(a,b) return a.t < b.t end)
end

function TimingController:Dispose()
	self:Stop()
	self._sound:Destroy()
	self.CueFired:Destroy()
end

-- Registrar handlers base de música al crear
TimingController._registerDefaultMusicHandlers(TimingController)

return TimingController
