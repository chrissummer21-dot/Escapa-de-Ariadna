-- src/ReplicatedStorage/Modules/SceneActions.lua
-- Contiene la lógica para CADA tipo de acción del timeline. (CON DEBUG PRINTS)

local CollectionService = game:GetService("CollectionService")

local SceneActions = {}

-- Función interna para controlar grupos de luces
local function setLightGroup(groupName, enabledState)
	print(string.format("[SceneActions] setLightGroup: Intentando cambiar grupo '%s' a enabled=%s", groupName, tostring(enabledState)))
	
	local levelFolder = workspace:FindFirstChild("Level0")
	if not levelFolder then
		warn("[SceneActions] ¡FALLO! No se encontró 'workspace.Level0'.")
		return
	end
	
	-- El nombre del grupo (ej: "CeilingLamps") es el nombre de la carpeta
	local groupFolder = levelFolder:FindFirstChild(groupName)
	if not groupFolder then
		warn(string.format("[SceneActions] ¡FALLO! No se encontró la carpeta del grupo: workspace.Level0.%s", groupName))
		return
	end
	
	print(string.format("[SceneActions] Encontrada carpeta de grupo: %s", groupFolder:GetFullName()))
	
	local lightsFound = 0
	-- Recorre todas las partes/modelos en la carpeta
	for _, item in ipairs(groupFolder:GetChildren()) do
		-- Busca luces en los descendientes del item
		for _, light in ipairs(item:GetDescendants()) do
			if light:IsA("Light") then -- (PointLight, SpotLight, SurfaceLight)
				light.Enabled = enabledState
				lightsFound += 1
			end
		end
	end
	
	-- Reporte final
	if lightsFound > 0 then
		print(string.format("[SceneActions] ¡ÉXITO! Se cambiaron %d luces en '%s' a Enabled = %s", lightsFound, groupName, tostring(enabledState)))
	else
		warn(string.format("[SceneActions] ADVERTENCIA: No se encontró NINGUNA luz ('Light') dentro de %s. ¿Están las lámparas ahí?", groupFolder:GetFullName()))
	end
end

-- Función principal llamada por el SceneController
function SceneActions.Execute(action, params)
	print(string.format("[SceneActions] Execute: Recibida acción '%s'", action))
	params = params or {}
	
	local parts = string.split(action, ":")
	local category = parts[1]
	local command = parts[2]
	
	-- ======= SECCIÓN DE LUCES =======
	if category == "lights" then
		
		if command == "group_on" and params.group then
			setLightGroup(params.group, true)
			
		elseif command == "group_off" and params.group then
			setLightGroup(params.group, false)
			
		end
	
	-- ======= OTRAS SECCIONES ... =======
	elseif category == "sound" then
		warn(string.format("[SceneActions] Categoría '%s' aún no implementada.", category))
	elseif category == "event" then
		warn(string.format("[SceneActions] Categoría '%s' aún no implementada.", category))
	end
end

return SceneActions