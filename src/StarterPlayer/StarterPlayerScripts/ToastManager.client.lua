-- src/StarterPlayer/StarterPlayerScripts/ToastManager.client.lua
-- MODIFICADO (V15): Ahora maneja múltiples toasts
-- cancelando el anterior para mostrar el nuevo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 1. Esperar a que existan las señales
local signalsFolder = ReplicatedStorage:WaitForChild("BackroomsSignals")
local showToastEvent = signalsFolder:WaitForChild("ShowToastMessage")

-- 2. Crear la GUI del Toast (reutilizable)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ToastGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 99 -- Encima de DoorStatus

local textLabel = Instance.new("TextLabel")
textLabel.Name = "ToastLabel"
textLabel.Parent = screenGui
textLabel.Text = "Mensaje de prueba"
textLabel.Font = Enum.Font.SourceSansBold
textLabel.TextScaled = true
textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
textLabel.TextStrokeTransparency = 0.5
textLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
textLabel.BackgroundTransparency = 0.2
textLabel.BorderMode = Enum.BorderMode.Outline
textLabel.BorderSizePixel = 1

-- ==== POSICIÓN Y TAMAÑO (PARTE SUPERIOR) ====
textLabel.AnchorPoint = Vector2.new(0.5, 0) -- Anclaje: Centro (X), Arriba (Y)
textLabel.Size = UDim2.new(0.5, 0, 0.08, 0) -- Tamaño: 50% ancho, 8% alto
textLabel.Position = UDim2.new(0.5, 0, 0.25, 0) -- Posición: 50% (Centro X), 25% (Debajo de DoorStatus)
-- ===========================================

-- Inicialmente invisible
textLabel.TextTransparency = 1
textLabel.BackgroundTransparency = 1

screenGui.Parent = playerGui

-- 3. Definir las animaciones
local FADE_IN_TIME = 0.3
local FADE_OUT_TIME = 0.4
local STAY_TIME = 2.5 -- Cuánto tiempo se queda visible

local tweenInfoIn = TweenInfo.new(FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenInfoOut = TweenInfo.new(FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local goalsIn = {
	TextTransparency = 0,
	BackgroundTransparency = 0.2,
}
local goalsOut = {
	TextTransparency = 1,
	BackgroundTransparency = 1,
}

local tweenIn = TweenService:Create(textLabel, tweenInfoIn, goalsIn)
local tweenOut = TweenService:Create(textLabel, tweenInfoOut, goalsOut)

-- ==== ¡NUEVA LÓGICA DE EVENTOS (V15)! ====
local currentToastJob = nil -- Variable para guardar el toast activo

-- 4. Conectar el evento
showToastEvent.OnClientEvent:Connect(function(message)
	
	-- Si hay un toast activo (mostrándose o esperando),
	-- cancélelo inmediatamente.
	if currentToastJob then
		task.cancel(currentToastJob)
		currentToastJob = nil
	end

	-- Iniciar un nuevo "trabajo" (coroutine) para este toast
	currentToastJob = task.spawn(function()
		
		textLabel.Text = message
		
		-- Detener animaciones anteriores y forzar estado visible (si estaba desapareciendo)
		tweenIn:Cancel()
		tweenOut:Cancel()
		textLabel.TextTransparency = 0
		textLabel.BackgroundTransparency = 0.2
		
		-- (Si no estaba visible, hacer el fade in)
		if textLabel.TextTransparency > 0 then
			tweenIn:Play()
			tweenIn.Completed:Wait()
		end
		
		-- Esperar
		task.wait(STAY_TIME)
		
		-- Ocultar
		tweenOut:Play()
		tweenOut.Completed:Wait()
		
		-- Limpiar
		currentToastJob = nil
	end)
end)

print("ToastManager.client.lua (V15 - Cola corregida) cargado.")