local Util = {}

function Util.ParentTarget(levelModel, levelFolder)
	return levelModel or levelFolder
end

function Util.CellCenter(cfg, x, z)
	local cx = cfg.ORIGIN.X + (x - 0.5) * cfg.CELL_SIZE.X
	local cz = cfg.ORIGIN.Z + (z - 0.5) * cfg.CELL_SIZE.Y
	return Vector3.new(cx, cfg.ORIGIN.Y, cz)
end

function Util.InBounds(cfg, x, z)
	return x >= 1 and x <= cfg.GRID_W and z >= 1 and z <= cfg.GRID_H
end

return Util
