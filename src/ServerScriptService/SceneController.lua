-- src/ServerScriptService/SceneController.lua
-- CONVERTIDO A MODULE SCRIPT. No se ejecuta solo.
-- Es llamado por ScatterCeilingLamps cuando las luces están listas.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ConfigsFolder = ReplicatedStorage:WaitForChild("Configs")
local ModulesFolder = ReplicatedStorage:WaitForChild("Modules")

-- 1. Cargar dependencias
print("[SceneController] Módulo cargado (requerido).")
local GameTimingConfig = require(ConfigsFolder:WaitForChild("GameTimingConfig"))
local SceneActions = require(ModulesFolder:WaitForChild("SceneActions"))
print("[SceneController] Dependencias de módulo cargadas.")

-- 2. Crear el Módulo
local SceneController = {}

-- 3. Mover la lógica DENTRO de una función del módulo
function SceneController.StartTimeline()
	print("[SceneController] StartTimeline() llamado. Iniciando timeline...")
	
	local timeline = GameTimingConfig.Timeline
	if not timeline or #timeline == 0 then
		warn("[SceneController] ¡ERROR! No se encontró 'Timeline' en GameTimingConfig.")
		return
	end
	
	-- Asegurar que la línea de tiempo esté ordenada por tiempo
	table.sort(timeline, function(a, b)
		return a.t < b.t
	end)
	
	print(string.format("[SceneController] Timeline cargado con %d eventos.", #timeline))
	
	local startTime = os.clock()
	local currentIndex = 1
	local connection
	
	-- Bucle de Heartbeat
	connection = RunService.Heartbeat:Connect(function(dt)
		local elapsedTime = (os.clock() - startTime) * GameTimingConfig.PlaybackRate
		
		-- Procesar todos los eventos que ya debieron ocurrir
		while currentIndex <= #timeline and elapsedTime >= timeline[currentIndex].t do
			local event = timeline[currentIndex]
			
			-- 4. Delegar la acción
			print(string.format(
				"[SceneController] >> TIEMPO ALCANZADO (t=%.2f). DISPARANDO ACCIÓN: %s (Grupo: %s)",
				elapsedTime,
				event.action,
				event.params and event.params.group or "N/A"
			))
			
			SceneActions.Execute(event.action, event.params)
			
			currentIndex += 1
		end
		
		-- 5. Detener el bucle si se acabó la timeline
		if currentIndex > #timeline then
			if not GameTimingConfig.LoopTimeline then
				print("[SceneController] Timeline completado. Deteniendo Heartbeat.")
				connection:Disconnect() -- Terminar el bucle
			else
				print("[SceneController] Timeline reiniciando...")
				startTime = os.clock() -- Reiniciar para loop
				currentIndex = 1
			end
		end
	end)
end

-- 4. Devolver el módulo para que otros scripts puedan usarlo
return SceneController