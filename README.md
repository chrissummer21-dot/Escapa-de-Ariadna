🌀 Backrooms Horror Game (Roblox)

Proyecto de juego de terror tipo Backrooms, desarrollado en Roblox Studio con sincronización Rojo + VS Code.
El proyecto genera un laberinto procedural con tareas, iluminación dinámica y validación automática de accesibilidad (spawn → puerta).

📁 Estructura del Proyecto
src/
├─ ReplicatedStorage/
│  └─ Modules/
│     └─ Backrooms/
│        ├─ Util.lua
│        ├─ Walls.lua
│        ├─ Floor.lua
│        ├─ Ceiling.lua
│        ├─ Door.lua
│        └─ Validate.lua
└─ ServerScriptService/
   ├─ BackroomsGenerator.server.lua
   ├─ ScatterCeilingLamps.server.lua
   ├─ BackroomsBlackout.server.lua
   └─ NightLock.server.lua

⚙️ Configuración del entorno
1️⃣ Requisitos

Roblox Studio

Rojo (Plugin + CLI)

Instala con Aftman:

aftman install rojo


o manualmente:
https://github.com/rojo-rbx/rojo/releases

2️⃣ Estructura de sincronización

El proyecto usa el archivo default.project.json para mapear:

src/ReplicatedStorage/Modules/Backrooms → ReplicatedStorage > Modules > Backrooms

src/ServerScriptService → ServerScriptService (o ServerScriptService/Managed si lo definiste así)

3️⃣ Servidor de desarrollo

Conecta Rojo al estudio:

rojo serve


Luego en Roblox Studio → Plugins → Rojo → Connect
Tu contenido se sincronizará automáticamente.

🧠 Scripts principales
Script	Tipo	Descripción
BackroomsGenerator.server.lua	Server	Crea proceduralmente paredes, piso, techo y puerta de luz. Controla el spawn y validación.
Walls.lua	Module	Genera un laberinto totalmente conectado (DFS) sin huecos inaccesibles.
Door.lua	Module	Crea la salida “glitch” con luz blanca y condiciones de desbloqueo.
ScatterCeilingLamps.server.lua	Server	Distribuye lámparas en el techo dentro del área del laberinto, evitando muros.
BackroomsBlackout.server.lua	Server	Desactiva la iluminación global; sólo lámparas marcadas con AllowLight emiten luz.
Validate.lua	Module	Comprueba accesibilidad con BFS (grid) y Pathfinding físico.
Util.lua / Floor.lua / Ceiling.lua	Modules	Soporte de generación estructural (centrado, offset, posicionamiento).
🌙 Funcionalidades

🧩 Mapa procedural tipo laberinto (sin espacios cerrados).

💡 Iluminación adaptativa: lámparas con posición aleatoria pero lógica.

🚪 Puerta de salida “glitch” con efectos de luz blanca.

🕹️ Spawn dinámico dentro del backroom (invisible para el jugador).

⚙️ Validación automática del nivel (garantiza que la puerta sea alcanzable).

🌑 Modo oscuro total (solo luces etiquetadas activas).

🔧 Personalización

Edita en BackroomsGenerator.server.lua:

GRID_W = 10,  -- ancho en celdas
GRID_H = 10,  -- alto en celdas
CELL_SIZE = Vector2.new(22, 22),
EXTRA_LOOPS = 12, -- más caminos abiertos
WALL_HEIGHT = 12,
DOOR_WIDTH = 6,


También puedes ajustar la cantidad de lámparas y su intensidad en
ScatterCeilingLamps.server.lua:

local LAMP_COUNT = 3
local LAMP_OFFSET_FROM_CEILING = 0.5

🧰 Comandos útiles
Acción	Comando
Sincronizar proyecto con Studio	rojo serve
Construir archivo .rbxlx	rojo build -o build/Backrooms.rbxlx
Instalar dependencias	aftman install
Limpiar build	Remove-Item build -Recurse -Force
🧩 Próximos pasos

Añadir sistema de tareas para abrir la puerta.

Implementar IA del monstruo con Pathfinding.

Integrar efectos sonoros y eventos de terror aleatorios.

Guardar progreso con DataStoreService.

📜 Licencia

Código libre para uso educativo y no comercial.
Creado por Alan Juárez con asistencia técnica de ChatGPT (OpenAI).