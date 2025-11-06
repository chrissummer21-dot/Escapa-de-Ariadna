-- src/StarterPlayer/StarterPlayerScripts/DoorStatus.client.lua
-- Muestra el mensaje "La puerta se ha abierto" de forma permanente
-- hasta que el lobby se reinicia.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 1. Esperar a que existan las señales
local Signals = ReplicatedStorage:WaitForChild("BackroomsSignals")
local DoorOpenedSignal = Signals:WaitForChild("DoorOpenedSignal")
local LobbySignal = Signals:WaitForChild("LobbySignal")

-- 2. Crear la GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DoorStatusGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 98 -- Debajo del Toast y el Lobby
screenGui.Parent = playerGui

local textLabel = Instance.new("TextLabel")
textLabel.Name = "DoorStatusLabel"
textLabel.Parent = screenGui
textLabel.Text = "La puerta se ha abierto"
textLabel.Font = Enum.Font.SourceSansBold
textLabel.TextScaled = true
textLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Verde
textLabel.TextStrokeTransparency = 0.4
textLabel.BackgroundTransparency = 1

-- Posición (justo debajo del mensaje del Lobby)
textLabel.AnchorPoint = Vector2.new(0.5, 0)
textLabel.Size = UDim2.new(0.5, 0, 0.08, 0)
textLabel.Position = UDim2.new(0.5, 0, 0.15, 0)
textLabel.Visible = false

-- 3. Conectar los eventos
DoorOpenedSignal.OnClientEvent:Connect(function()
	textLabel.Visible = true
end)

-- Ocultar este mensaje cuando el lobby se reinicia
LobbySignal.OnClientEvent:Connect(function(command, message)
	if command == "Show" then
		textLabel.Visible = false
	end
end)