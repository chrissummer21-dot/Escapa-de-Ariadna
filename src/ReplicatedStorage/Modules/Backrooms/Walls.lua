-- TODO: paste code here
-- ReplicatedStorage/Modules/Backrooms/Walls.lua
-- Maze conectado (DFS), SIN abrir huecos en el borde.
-- ConstrucciÃƒÂ³n de muros SIN duplicados por arista (consistencia y sin solapes raros).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Util = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Backrooms"):WaitForChild("Util"))

local Walls = {}

local dirs = {
	{name="N", dx=0, dz=-1, opposite="S"},
	{name="S", dx=0, dz= 1, opposite="N"},
	{name="W", dx=-1,dz= 0, opposite="E"},
	{name="E", dx=1, dz= 0, opposite="W"},
}
local byName = { N=dirs[1], S=dirs[2], W=dirs[3], E=dirs[4] }

local function newCell()
	return { visited=false, walls={N=true,S=true,E=true,W=true} }
end

local function shuffle(rng, list)
	for i=#list,2,-1 do
		local j = rng:NextInteger(1,i)
		list[i], list[j] = list[j], list[i]
	end
end

-- DFS: genera un ÃƒÂ¡rbol que conecta TODAS las celdas (sin islas)
local function carve(cfg, rng, grid, x, z)
	local cell = grid[x][z]
	cell.visited = true
	local order = {"N","S","E","W"}
	shuffle(rng, order)
	for _,name in ipairs(order) do
		local d = byName[name]
		local nx, nz = x + d.dx, z + d.dz
		if Util.InBounds(cfg, nx, nz) and not grid[nx][nz].visited then
			cell.walls[name] = false
			grid[nx][nz].walls[d.opposite] = false
			carve(cfg, rng, grid, nx, nz)
		end
	end
end

-- FÃƒÂ¡brica de muro
local function makeWall(parent, pos, size)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(240,240,240)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = "Wall"
	p.Parent = parent
	return p
end

function Walls.Generate(cfg, rng, levelModel, levelFolder)
	-- 1) GRID
	local grid = {}
	for x=1, cfg.GRID_W do
		grid[x] = {}
		for z=1, cfg.GRID_H do
			grid[x][z] = newCell()
		end
	end

	-- 2) DFS: conecta todo
	carve(cfg, rng, grid, rng:NextInteger(1,cfg.GRID_W), rng:NextInteger(1,cfg.GRID_H))

	-- 3) Opcional: aÃƒÂ±adir bucles extra (no rompe conectividad)
	for i=1, cfg.EXTRA_LOOPS do
		local x = rng:NextInteger(1, cfg.GRID_W)
		local z = rng:NextInteger(1, cfg.GRID_H)
		local pick = ({ "N","S","E","W" })[rng:NextInteger(1,4)]
		local d = byName[pick]
		local nx, nz = x + d.dx, z + d.dz
		if Util.InBounds(cfg, nx, nz) then
			grid[x][z].walls[d.name] = false
			grid[nx][nz].walls[d.opposite] = false
		end
	end

	-- 4) ConstrucciÃƒÂ³n SIN duplicados por arista:
	--    - Solo construimos muros hacia SUR y ESTE por cada celda.
	--    - AdemÃƒÂ¡s, construimos el borde NORTE del z=1 y el borde OESTE del x=1.
	--    - Posicionamos muros al borde interior con t*0.5 para cerrar con piso/techo.
	local parent = Util.ParentTarget(levelModel, levelFolder)
	local t      = cfg.WALL_THICK
	local h      = cfg.WALL_HEIGHT
	local halfX  = cfg.CELL_SIZE.X * 0.5
	local halfZ  = cfg.CELL_SIZE.Y * 0.5

	for x=1, cfg.GRID_W do
		for z=1, cfg.GRID_H do
			local c      = grid[x][z]
			local center = Util.CellCenter(cfg, x, z)

			-- Borde NORTE solo para la primera fila
			if z == 1 and c.walls.N then
				makeWall(parent, center + Vector3.new(0, h*0.5, -(halfZ - t*0.5)), Vector3.new(cfg.CELL_SIZE.X, h, t))
			end
			-- Borde OESTE solo para la primera columna
			if x == 1 and c.walls.W then
				makeWall(parent, center + Vector3.new(-(halfX - t*0.5), h*0.5, 0), Vector3.new(t, h, cfg.CELL_SIZE.Y))
			end

			-- Interior: construir solo SUR y ESTE para evitar duplicados
			if c.walls.S then
				makeWall(parent, center + Vector3.new(0, h*0.5,  (halfZ - t*0.5)), Vector3.new(cfg.CELL_SIZE.X, h, t))
			end
			if c.walls.E then
				makeWall(parent, center + Vector3.new( (halfX - t*0.5), h*0.5, 0), Vector3.new(t, h, cfg.CELL_SIZE.Y))
			end
		end
	end

	-- 5) Sin huecos exteriores: definimos entrada/salida lÃƒÂ³gicas solo para orientar puerta
	local entranceEdge = "N"
	local exitEdge     = "S"
	local sx, sz = 1, 1
	local ex, ez = cfg.GRID_W, cfg.GRID_H

	local totalW = cfg.GRID_W * cfg.CELL_SIZE.X
	local totalD = cfg.GRID_H * cfg.CELL_SIZE.Y

	return {
		grid = grid,
		entranceEdge = entranceEdge, entranceCell = Vector3.new(sx,0,sz),
		exitEdge     = exitEdge,     exitCell     = Vector3.new(ex,0,ez),
		totalW = totalW, totalD = totalD,
		parent = parent,
	}
end

return Walls
