-- ReplicatedStorage/Modules/Backrooms/Validate.lua
-- Verifica accesibilidad: BFS en grid + Pathfinding físico hasta la puerta.

local PathfindingService = game:GetService("PathfindingService")

local Validate = {}

-- --- BFS sobre el grid (usa walls booleans de build.grid) ---
local DIRS = {
	N = {dx=0, dz=-1, w="N", opp="S"},
	S = {dx=0, dz= 1, w="S", opp="N"},
	W = {dx=-1,dz= 0, w="W", opp="E"},
	E = {dx= 1,dz= 0, w="E", opp="W"},
}

local function inBounds(cfg, x, z)
	return x>=1 and x<=cfg.GRID_W and z>=1 and z<=cfg.GRID_H
end

local function bfsPath(cfg, grid, sx, sz, gx, gz)
	local q = {}
	local head, tail = 1, 1
	q[tail] = {x=sx, z=sz}; tail += 1
	local came = {}  -- came[z][x] = {x=px, z=pz}
	for x=1,cfg.GRID_W do
		came[x] = {}
	end
	came[sx][sz] = {x=0,z=0}

	while head < tail do
		local cur = q[head]; head += 1
		if cur.x == gx and cur.z == gz then
			-- reconstruir
			local path = {}
			local cx, cz = gx, gz
			while not (cx==sx and cz==sz) do
				table.insert(path, 1, {x=cx, z=cz})
				local p = came[cx][cz]
				cx, cz = p.x, p.z
			end
			table.insert(path, 1, {x=sx, z=sz})
			return path
		end
		local c = grid[cur.x][cur.z]
		for name,dir in pairs(DIRS) do
			-- si NO hay muro en esa dirección, podemos pasar
			if c.walls[name] == false then
				local nx, nz = cur.x + dir.dx, cur.z + dir.dz
				if inBounds(cfg, nx, nz) and not came[nx][nz] then
					came[nx][nz] = {x=cur.x, z=cur.z}
					q[tail] = {x=nx, z=nz}; tail += 1
				end
			end
		end
	end
	return nil
end

-- punto frente a la puerta para pathfinding físico
local function doorFrontWorld(cfg, build)
	local cellX, cellZ = build.exitCell.X, build.exitCell.Z
	local cx = cfg.ORIGIN.X + (cellX - 0.5) * cfg.CELL_SIZE.X
	local cz = cfg.ORIGIN.Z + (cellZ - 0.5) * cfg.CELL_SIZE.Y
	local halfX, halfZ = cfg.CELL_SIZE.X*0.5, cfg.CELL_SIZE.Y*0.5
	local y = cfg.ORIGIN.Y + 2 -- altura caminable

	local edge = build.exitEdge
	local inset = 2
	if edge == "N" then
		return Vector3.new(cx, y, cz - (halfZ - inset))
	elseif edge == "S" then
		return Vector3.new(cx, y, cz + (halfZ - inset))
	elseif edge == "W" then
		return Vector3.new(cx - (halfX - inset), y, cz)
	else -- "E"
		return Vector3.new(cx + (halfX - inset), y, cz)
	end
end

-- Tras tu generador (Spawn ya creado), valida:
function Validate.EnsureAccessible(cfg, build, spawnCFrame)
	-- 1) BFS lógico (grid)
	local okGrid = false
	do
		local path = bfsPath(cfg, build.grid, build.entranceCell.X, build.entranceCell.Z, build.exitCell.X, build.exitCell.Z)
		okGrid = path ~= nil
		if not okGrid then
			warn("[Backrooms/Validate] BFS: NO hay camino lógico en el grid (esto no debería pasar con DFS).")
		end
	end

	-- 2) PathfindingService físico
	local okPhys = false
	do
		local startPos = spawnCFrame and spawnCFrame.Position or Vector3.new(
			cfg.ORIGIN.X + cfg.CELL_SIZE.X*0.5, cfg.ORIGIN.Y + 2, cfg.ORIGIN.Z + cfg.CELL_SIZE.Y*0.5
		)
		local goal = doorFrontWorld(cfg, build)
		local agentParams = {
			AgentRadius = 2,    -- ajusta a tu humanoide
			AgentHeight = 5,
			AgentCanJump = true
		}
		local pf = PathfindingService:CreatePath(agentParams)
		pf:ComputeAsync(startPos, goal)
		if pf.Status == Enum.PathStatus.Success then
			okPhys = true
		else
			warn("[Backrooms/Validate] Pathfinding físico: sin camino al frente de la puerta. Estado:", pf.Status)
		end
	end

	return okGrid, okPhys
end

return Validate
