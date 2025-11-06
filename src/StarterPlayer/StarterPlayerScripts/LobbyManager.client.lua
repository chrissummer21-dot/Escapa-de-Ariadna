-- src/StarterPlayer/StarterPlayerScripts/LobbyManager.client.lua
-- Muestra los mensajes del lobby (A dormir, cuenta atrás).
-- (Versión con texto superior y responsivo)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 1. Crear la GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LobbyGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 100 -- Encima de todo
screenGui.Parent = playerGui

local textLabel = Instance.new("TextLabel")
textLabel.Name = "LobbyText"
textLabel.Parent = screenGui
textLabel.Text = "Cargando..."
textLabel.Font = Enum.Font.SourceSansBold
textLabel.TextScaled = true
textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
textLabel.TextStrokeTransparency = 0.4
textLabel.BackgroundTransparency = 1

-- ==== POSICIÓN Y TAMAÑO (PARTE SUPERIOR) ====
textLabel.AnchorPoint = Vector2.new(0.5, 0) -- Anclaje: Centro (X), Arriba (Y)
textLabel.Size = UDim2.new(0.6, 0, 0.1, 0) -- Tamaño: 60% ancho, 10% alto
textLabel.Position = UDim2.new(0.5, 0, 0.05, 0) -- Posición: 50% (Centro X), 5% (Desde Arriba Y)
-- ===========================================

textLabel.Visible = false

-- 2. Esperar al RemoteEvent
local Signals = ReplicatedStorage:WaitForChild("BackroomsSignals")
local LobbySignal = Signals:WaitForChild("LobbySignal")

-- 3. Conectar el evento
LobbySignal.OnClientEvent:Connect(function(command, message)
	if command == "Show" then
		textLabel.Text = message
		textLabel.Visible = true
	elseif command == "Hide" then
		textLabel.Visible = false
	end
end)