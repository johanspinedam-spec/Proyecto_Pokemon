# PokemonBattle 

Plataforma de batallas Pokémon por turnos en consola, desarrollada en **Elixir** como proyecto final de Programación III — Universidad del Quindío.

El sistema permite a múltiples entrenadores conectarse, armar equipos, intercambiar Pokémon y enfrentarse en batallas 1v1 en tiempo real, con soporte para ejecución distribuida en múltiples nodos.

---

## Características principales

- Registro e inicio de sesión de entrenadores con persistencia entre sesiones
- Sistema de sobres con rareza aleatoria (común, raro, épico) para obtener Pokémon
- Motor de combate por turnos con efectividad de tipos y STAB
- Equipos predefinidos reutilizables por entrenador
- Intercambio de Pokémon en tiempo real entre dos entrenadores
- Evolución automática de Pokémon al acumular victorias
- Economía de monedas con recompensas por batalla
- Múltiples batallas concurrentes sin interferencia
- Ejecución distribuida en al menos 2 nodos Elixir

---

## Instalación

Requisitos previos: tener instalado **Elixir 1.19+** y **Erlang/OTP 28+**.

```bash
# Clonar el repositorio
git clone <url-del-repositorio>
cd proyecto_pokemon

# Instalar dependencias
mix deps.get

# Compilar
mix compile
```

---

## Ejecución

### Modo single node (pruebas o un solo jugador)

```bash
iex -S mix
```

Una vez dentro del shell:

```elixir
PokemonBattle.Servidor.start()
```

---

### Modo distribuido (2 nodos — recomendado para batallas reales)

Primero averigua tu dirección IP local ejecutando esto en la terminal:

- **Windows:** `ipconfig` → busca "Dirección IPv4"
- **Linux/Mac:** `hostname -I`

Usa esa IP en lugar de `TU_IP` en todos los comandos siguientes.

---

**Terminal 1 — Nodo primario:**

```bash
iex --name node1@TU_IP --cookie pokemonbattle -S mix
```

```elixir
PokemonBattle.Servidor.start()
```

---

**Terminal 2 — Nodo secundario** (puede ser otra máquina en la misma red):

```bash
iex --name node2@TU_IP --cookie pokemonbattle -S mix
```

Una vez dentro, conectar al nodo primario:

```elixir
Node.connect(:"node1@TU_IP")
```

Luego arrancar el servidor:

```elixir
PokemonBattle.Servidor.start()
```

---

> **Importante:** Ambos nodos deben usar exactamente la misma `--cookie` (`pokemonbattle`) y estar en la misma red local. Si corres ambas terminales en la misma máquina, usa la misma IP en los dos. Puedes verificar que la conexión fue exitosa con `Node.list()` — debe aparecer el otro nodo en la lista.

## Comandos disponibles

Una vez dentro del sistema, escribe `play` para ver todos los comandos. Acá el resumen:

### Sesión
| Comando | Descripción |
|---|---|
| `login <usuario> <clave>` | Inicia sesión o crea cuenta automáticamente |
| `logout` | Cierra la sesión actual |
| `profile` | Muestra monedas, sobres y estadísticas |
| `leaderboard` | Clasificación global por victorias |

### Inventario y sobres
| Comando | Descripción |
|---|---|
| `inventory` | Lista todos tus Pokémon con estadísticas y movimientos |
| `shop` | Muestra los tipos de sobre disponibles y precios |
| `buy_pack <basic\|advanced>` | Compra un sobre (basic=100 monedas, advanced=250) |
| `open_pack <id\|last>` | Abre un sobre y recibe 3 Pokémon aleatorios |

### Equipos
| Comando | Descripción |
|---|---|
| `create_team <nombre> <id1,id2,id3>` | Crea un equipo con 1 a 3 Pokémon |
| `list_teams` | Lista tus equipos guardados |
| `show_team <nombre>` | Ver detalle de un equipo |
| `use_team <nombre>` | Selecciona el equipo para la siguiente batalla |
| `add_to_team <equipo> <id>` | Agrega un Pokémon a un equipo existente |
| `remove_from_team <equipo> <id>` | Quita un Pokémon de un equipo |
| `rename_team <viejo> <nuevo>` | Renombra un equipo |
| `delete_team <nombre>` | Elimina un equipo |

### Batalla
| Comando | Descripción |
|---|---|
| `create_room <segundos>` | Crea una sala de batalla con tiempo de turno |
| `list_rooms` | Lista salas disponibles |
| `join_room <id_sala>` | Unirse a una sala existente |
| `start_battle <id_sala>` | Inicia la batalla cuando hay 2 jugadores |
| `attack <movimiento>` | Ejecutar un ataque en tu turno |
| `switch <id_pokemon>` | Cambiar el Pokémon activo |
| `surrender` | Rendirse (el rival gana) |

### Intercambio
| Comando | Descripción |
|---|---|
| `create_trade_room` | Crea una sala de intercambio y genera un código |
| `join_trade_room <codigo>` | Unirse a una sala de intercambio |
| `offer_pokemon <id>` | Ofrecer un Pokémon para el intercambio |
| `confirm_trade` | Confirmar el intercambio |
| `cancel_trade` | Cancelar y cerrar la sala |

### Cluster
| Comando | Descripción |
|---|---|
| `connect_node <node@host>` | Conectar a otro nodo Elixir |
| `list_nodes` | Ver nodos conectados |
| `cluster_info` | Información del cluster actual |

---

## Arquitectura

proyecto_pokemon/
├── lib/
│   └── pokemon_battle/
│       ├── servidor.ex             # Interfaz de consola y enrutamiento de comandos
│       ├── gestor_entrenadores.ex  # Sesión, perfil, inventario, monedas, equipos
│       ├── sistema_sobres.ex       # Compra/apertura de sobres y asignación de movimientos
│       ├── intercambio.ex          # GenServer de sala de intercambio
│       ├── gestor_salas.ex         # Creación y gestión de salas de batalla
│       ├── batalla.ex              # GenServer de batalla (turnos, acciones, fin)
│       ├── supervisor_batallas.ex  # DynamicSupervisor de batallas e intercambios
│       ├── motor_combate.ex        # Daño, tipos, STAB, visualización de turnos
│       ├── evolution.ex            # Evolución automática de Pokémon
│       ├── persistencia.ex         # Lectura/escritura de archivos JSON
│       └── cluster.ex              # Conexión y gestión de nodos distribuidos
├── data/
│   ├── trainers.json               # Entrenadores, inventario, equipos, monedas
│   ├── pokemon.json                # Especies base con estadísticas y evoluciones
│   ├── moves.json                  # Pool de movimientos por tipo elemental
│   ├── shop.json                   # Precios y probabilidades de sobres
│   └── battles.log                 # Registro histórico de batallas
└── test/
└── pokemon_battle_test.exs     # Pruebas unitarias ExUnit


---

## Pruebas

```bash
mix test
```

Las pruebas cubren:

- Cálculo de daño con tipo fuerte, débil y neutro
- Validación de orden por velocidad en combate
- Asignación correcta de monedas al ganador (+100) y perdedor (+30)
- Apertura de sobres: 3 Pokémon, rareza válida, 4 movimientos, dueño correcto
- Intercambio completo entre dos entrenadores preservando id, rareza y dueño original

---

## Guía estratégica — ¿Qué Pokémon usar?

### Tabla de efectividad de tipos

Si tu movimiento es del tipo de la izquierda y el rival es del tipo de la derecha, haces **el doble de daño (x2.0)**. Al revés, recibes **la mitad (x0.5)**:

| Tu tipo ataca con... | Es fuerte contra... | Es débil contra... |
|---|---|---|
|  Fuego | Planta, Hielo, Bicho | Agua, Roca |
|  Agua | Fuego, Roca, Tierra | Planta |
|  Planta | Agua, Roca, Tierra | Fuego, Bicho |
|  Eléctrico | Agua, Volador | Tierra |
|  Roca | Fuego, Hielo, Volador, Bicho | Agua, Planta, Tierra |

### Bonus STAB — Same Type Attack Bonus

Si usas un movimiento del **mismo tipo que tu Pokémon**, el daño se multiplica por **x1.5**. Por ejemplo, un Pikachu (Eléctrico) usando `thunderbolt` (Eléctrico) recibe ese bonus. Siempre que puedas, usa movimientos del tipo de tu Pokémon.

### Los Pokémon más fuertes del juego

#### Tier S — Los mejores para cualquier equipo

**Golduck** (Agua) — El más completo del juego. Speed alto, ataque alto y defensa sólida. Con `surf` o `hydro_pump` arrasa contra Fuego, Roca y Tierra. Si lo consigues épico, es prácticamente imbatible.

**Gengar** (Normal) — El más rápido del juego (speed base 110). Siempre actúa primero, lo que en muchos duelos decide la batalla antes de que el rival pueda responder. Ideal para equipos ofensivos.

**Golem** (Roca/Tierra) — El mayor tanque del juego. Defensa base 130 y ataque base 120. Absorbe casi cualquier golpe y responde con `earthquake` o `stone_edge`. Su punto débil es la velocidad (45 base) y que Agua y Planta le hacen x2.0.

#### Tier A — Muy buenos, fáciles de conseguir

**Raichu** (Eléctrico) — Speed 110, ataque 90. Devastador contra equipos con Agua o Volador. `volt_tackle` con STAB hace daño masivo.

**Machamp** (Normal) — Ataque base 130, el más alto del juego. Si lo consigues en rareza épica sus stats son brutales. `hyper_beam` de poder 150 puede noquear a casi cualquiera en un golpe.

**Charizard** (Fuego/Volador) — Bi-tipo con buena velocidad y ataque. Tiene ventaja sobre Planta, Hielo y Bicho. Cuidado con Roca que le hace x2.0.

**Blastoise** (Agua) — El mejor tanque de tipo Agua. Defensa base 100, ideal para aguantar y contraatacar.

#### Tier B — Sólidos para equipos mixtos

**Venusaur** (Planta), **Ninetales** (Fuego), **Pidgeot** (Normal/Volador)

#### Tier C — Útiles solo en situaciones específicas

**Graveler/Geodude** (Roca/Tierra) — Muy lentos pero tanques. Solo úsalos si el rival tiene Fuego o Volador.

**Haunter** (Normal) — Stats mediocres comparado con Gengar. Úsalo solo si estás en proceso de evolución.

### Consejos para armar tu equipo

**Cubre tus debilidades** — No pongas 3 Pokémon del mismo tipo. Si todos son de Agua, un solo Pokémon de Planta te destruye el equipo entero.

**Un tanque, un velocista, uno de soporte** — La combinación clásica: un Golem o Blastoise que aguante, un Gengar o Raichu que ataque primero, y un tercero versátil.

**Rareza importa mucho** — Un Charmander épico puede superar a un Charizard común en estadísticas. Siempre revisa el ataque/defensa/speed real de tu instancia con `inventory`, no solo la especie.

**La velocidad decide duelos cerrados** — Si dos Pokémon se van a noquear mutuamente, el más rápido siempre gana. En empate el orden es aleatorio, así que en duelos ajustados la velocidad es la stat más importante.

**STAB siempre** — Cuando elijas qué movimiento usar, prioriza los que coincidan con el tipo de tu Pokémon. El x1.5 combinado con una buena efectividad de tipo puede triplicar el daño base.

**Evoluciona antes de intercambiar** — Las estadísticas escalan con la evolución. Un Haunter con 6 victorias se convierte en Gengar automáticamente. Espera a que evolucione antes de ofrecerlo en un intercambio.

---

## Modelo de datos

### Rareza y estadísticas

| Rareza | Factor de bonus | Probabilidad (sobre básico) | Probabilidad (sobre avanzado) |
|---|---|---|---|
| Común | +2% a +8% | 70% | 40% |
| Raro | +10% a +20% | 25% | 45% |
| Épico | +25% a +40% | 5% | 15% |

### Evoluciones disponibles

| Cadena | Victorias para evolucionar |
|---|---|
| Gastly → Haunter → Gengar | 3 → 6 |
| Geodude → Graveler → Golem | 3 → 6 |
| Charmander → Charmeleon → Charizard | 3 → 6 |
| Squirtle → Wartortle → Blastoise | 3 → 6 |
| Bulbasaur → Ivysaur → Venusaur | 3 → 6 |
| Pikachu → Raichu | 3 |
| Psyduck → Golduck | 3 |
| Machop → Machoke → Machamp | 3 → 6 |
| Pidgey → Pidgeotto → Pidgeot | 3 → 6 |
| Vulpix → Ninetales | 3 |

---

## Persistencia

Los datos de entrenadores, inventario, equipos y monedas se guardan automáticamente en `data/trainers.json` después de cada acción relevante. Al reiniciar la aplicación, todo el progreso se conserva.

Los intercambios **no se persisten** — son exclusivamente en tiempo real y requieren que ambos entrenadores estén conectados simultáneamente.

---

## Autores

Proyecto desarrollado para Programación III — Ingeniería de Sistemas y Computación, Universidad del Quindío.

- Juan Felipe Ibarra Londoño.
- Johan Stiven Pineda Martinez.

Docente: Carlos Andrés Florez V.
