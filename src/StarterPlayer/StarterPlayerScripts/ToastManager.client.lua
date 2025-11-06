-- src/StarterPlayer/StarterPlayerScripts/ToastManager.client.lua
-- Este script ahora maneja la creación de un "toast"
-- que se activa por un RemoteEvent desde el servidor.
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
screenGui.DisplayOrder = 99 -- Asegura que esté encima de otras UI

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

-- (IMPORTANTE) Posición y Tamaño usando 'Scale' para adaptarse a cualquier resolución
-- ==== CORRECCIÓN 1: Comentario en una sola línea ====
textLabel.AnchorPoint = Vector2.new(0.5, 1) -- Anclado abajo y al centro
textLabel.Size = UDim2.new(0.4, 0, 0.08, 0) -- 40% ancho, 8% alto
textLabel.Position = UDim2.new(0.5, 0, 0.9, 0) -- 50% centro X, 90% abajo Y

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

local isShowing = false -- Debounce para evitar spamear

-- 4. Conectar el evento
showToastEvent.OnClientEvent:Connect(function(message)
	-- ==== CORRECCIÓN 2: 'if' en una sola línea ====
	if isShowing then return end -- Evitar que se pise
	
	isShowing = true
	textLabel.Text = message
	
	tweenIn:Play()
	tweenIn.Completed:Wait() -- Esperar a que termine de aparecer
	
	task.wait(STAY_TIME)
	
	tweenOut:Play()
	tweenOut.Completed:Wait() -- Esperar a que termine de desaparecer
	
	isShowing = false
end)

print("ToastManager.client.lua cargado.")