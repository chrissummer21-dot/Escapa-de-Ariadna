--!strict
-- Control de luces (PointLight/SpotLight/SurfaceLight) con grupos y control total.
-- Pensado para que lo llame TimingController u otros sistemas.

local CollectionService = game:GetService("CollectionService")

export type LightInstance = PointLight | SpotLight | SurfaceLight
export type LampId = string

type LampRecord = {
	id: LampId,
	inst: LightInstance,
	group: string?,
}

local LightController = {}
LightController.__index = LightController

local function isLight(inst: Instance): boolean
	local c = inst.ClassName
	return c == "PointLight" or c == "SpotLight" or c == "SurfaceLight"
end

local function makeId(inst: LightInstance): LampId
	return ("%s|%s|%d"):format(inst:GetFullName(), inst.Name, inst:GetDebugId())
end

function LightController.new()
	local self = setmetatable({}, LightController)
	self._byId = {} :: {[LampId]: LampRecord}
	self._byInst = {} :: {[Instance]: LampRecord}
	self._groups = {} :: {[string]: {[LampId]: true}}
	return self
end

function LightController:Register(inst: Instance, group: string?)
	assert(isLight(inst), "Instancia no es una luz válida")
	local light = inst :: LightInstance
	local id = makeId(light)
	if self._byId[id] then return id end

	local rec: LampRecord = { id = id, inst = light, group = group }
	self._byId[id] = rec
	self._byInst[light] = rec
	if group then
		self._groups[group] = self._groups[group] or {}
		self._groups[group][id] = true
	end

	light.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self._byInst[light] = nil
			if rec.group and self._groups[rec.group] then
				self._groups[rec.group][id] = nil
			end
			self._byId[id] = nil
		end
	end)

	return id
end

function LightController:RegisterTag(tagName: string, groupFromParent: boolean?)
	for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
		if isLight(inst) then
			local group = if groupFromParent and inst.Parent then inst.Parent.Name else nil
			self:Register(inst, group)
		end
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(function(inst)
		if isLight(inst) then
			local group = if groupFromParent and inst.Parent then inst.Parent.Name else nil
			self:Register(inst, group)
		end
	end)
end

-- ===== Acciones básicas =====
function LightController:On(target: LampId | Instance)
	local rec = typeof(target) == "Instance" and self._byInst[target] or self._byId[target]
	if rec then rec.inst.Enabled = true end
end

function LightController:Off(target: LampId | Instance)
	local rec = typeof(target) == "Instance" and self._byInst[target] or self._byId[target]
	if rec then rec.inst.Enabled = false end
end

function LightController:Toggle(target: LampId | Instance)
	local rec = typeof(target) == "Instance" and self._byInst[target] or self._byId[target]
	if rec then rec.inst.Enabled = not rec.inst.Enabled end
end

function LightController:AllOn()
	for _, rec in pairs(self._byId) do rec.inst.Enabled = true end
end

function LightController:AllOff()
	for _, rec in pairs(self._byId) do rec.inst.Enabled = false end
end

function LightController:GroupOn(group: string)
	local map = self._groups[group]; if not map then return end
	for id in pairs(map) do self:On(id) end
end

function LightController:GroupOff(group: string)
	local map = self._groups[group]; if not map then return end
	for id in pairs(map) do self:Off(id) end
end

-- ===== Propiedades comunes =====
function LightController:SetBrightness(target: LampId | Instance, v: number)
	local rec = typeof(target) == "Instance" and self._byInst[target] or self._byId[target]
	if rec then (rec.inst :: any).Brightness = v end
end

function LightController:SetColor(target: LampId | Instance, color: Color3)
	local rec = typeof(target) == "Instance" and self._byInst[target] or self._byId[target]
	if rec then (rec.inst :: any).Color = color end
end

function LightController:SetRange(target: LampId | Instance, v: number)
	local rec = typeof(target) == "Instance" and self._byInst[target] or self._byId[target]
	if rec then (rec.inst :: any).Range = v end
end

function LightController:SetAngle(target: LampId | Instance, inner: number?, outer: number?)
	local rec = typeof(target) == "Instance" and self._byInst[target] or self._byId[target]
	if rec and rec.inst.ClassName == "SpotLight" then
		if inner ~= nil then (rec.inst :: any).InnerAngle = inner end
		if outer ~= nil then (rec.inst :: any).OuterAngle = outer end
	end
end

return LightController
