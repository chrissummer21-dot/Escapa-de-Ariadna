-- TODO: paste code here
local Util = require(game.ReplicatedStorage.Modules.Backrooms.Util)
local Floor = {}

function Floor.Place(cfg, build, levelModel, levelFolder)
	if not cfg.ADD_FLOOR then return end
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(build.totalW, cfg.FLOOR_THICK, build.totalD)
	local y = cfg.ORIGIN.Y - (cfg.FLOOR_THICK * 0.5)
	floor.CFrame = CFrame.new(cfg.ORIGIN.X + build.totalW*0.5, y, cfg.ORIGIN.Z + build.totalD*0.5)
	floor.Material = Enum.Material.SmoothPlastic
	floor.Color = cfg.FLOOR_COLOR
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor.Parent = Util.ParentTarget(levelModel, levelFolder)
end

return Floor
