local Util = require(game.ReplicatedStorage.Modules.Backrooms.Util)
local Ceiling = {}

function Ceiling.Place(cfg, build, levelModel, levelFolder)
	if not cfg.ADD_CEILING then return end
	local ceil = Instance.new("Part")
	ceil.Name = "Ceiling"
	ceil.Anchored = true
	ceil.Size = Vector3.new(build.totalW, cfg.CEILING_THICK, build.totalD)
	local y = cfg.ORIGIN.Y + cfg.WALL_HEIGHT + (cfg.CEILING_THICK * 0.5)
	ceil.CFrame = CFrame.new(cfg.ORIGIN.X + build.totalW*0.5, y, cfg.ORIGIN.Z + build.totalD*0.5)
	ceil.Material = Enum.Material.SmoothPlastic
	ceil.Color = cfg.CEILING_COLOR
	ceil.TopSurface = Enum.SurfaceType.Smooth
	ceil.BottomSurface = Enum.SurfaceType.Smooth
	ceil.Parent = Util.ParentTarget(levelModel, levelFolder)
end

return Ceiling
