defmodule PokemonBattle.GestorSalas do
  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(_), do: {:ok, %{rooms: %{}, counter: 0}}

  def create_room(turn_time \\ 20), do: GenServer.call(__MODULE__, {:create_room, turn_time})
  def join_room(room_id, trainer, team, pid \\ self()), do: GenServer.call(__MODULE__, {:join, room_id, trainer, team, pid})
  def start_battle(room_id, username, requester_pid \\ nil) do
    GenServer.call(__MODULE__, {:start, room_id, username, requester_pid})
  end
  def list_rooms, do: GenServer.call(__MODULE__, :list)
  def get_room(room_id), do: GenServer.call(__MODULE__, {:get, room_id})

  def handle_call({:create_room, turn_time}, _from, state) do
    counter = state.counter + 1
    room_id = "S-#{String.pad_leading(to_string(counter), 4, "0")}"

    room = %{id: room_id, turn_time: turn_time, players: [], teams: %{}, pids: %{}, phase: :waiting}

    new_state =
      state
      |> put_in([:rooms, room_id], room)
      |> Map.put(:counter, counter)

    IO.puts("[Rooms] Room #{room_id} created (turn time: #{turn_time}s).")
    {:reply, {:ok, room_id}, new_state}
  end

  def handle_call({:join, room_id, trainer, team, pid}, _from, state) do
    case Map.get(state.rooms, room_id) do
      nil ->
        {:reply, {:error, "Room not found"}, state}

      room ->
        cond do
          room.phase != :waiting ->
            {:reply, {:error, "Room is already in progress or finished"}, state}

          length(room.players) >= 2 ->
            {:reply, {:error, "Room is full"}, state}

          Enum.any?(room.players, &(&1 == trainer["username"])) ->
            {:reply, {:error, "You are already in this room"}, state}

          team == [] or team == nil ->
            {:reply, {:error, "You must select a team first with use_team"}, state}

          true ->
            updated_room =
              room
              |> Map.put(:players, room.players ++ [trainer["username"]])
              |> put_in([:teams, trainer["username"]], team)
              |> put_in([:pids, trainer["username"]], pid)

            new_state = put_in(state.rooms[room_id], updated_room)
            IO.puts("[Rooms] #{trainer["username"]} joined room #{room_id}.")
            {:reply, :ok, new_state}
        end
    end
  end

  def handle_call({:start, room_id, username, requester_pid}, _from, state) do
    case Map.get(state.rooms, room_id) do
      nil ->
        {:reply, {:error, "Room not found"}, state}

      room ->
        cond do
          length(room.players) < 2 ->
            {:reply, {:error, "Need 2 players to start"}, state}

          room.phase != :waiting ->
            {:reply, {:error, "Battle already started"}, state}

          not Enum.member?(room.players, username) ->
            {:reply, {:error, "You are not in this room"}, state}

          true ->
            # Si quien inicia la batalla es del nodo remoto, actualizar su PID
            updated_pids =
              if requester_pid != nil do
                Map.put(room.pids, username, requester_pid)
              else
                room.pids
              end

            updated_room_pids = Map.put(room, :pids, updated_pids)

            PokemonBattle.SupervisorBatallas.start_battle(room_id, room.turn_time)

            Enum.each(room.players, fn player ->
              team    = room.teams[player]
              pid     = Map.get(updated_pids, player, self())
              trainer = %{"username" => player}
              PokemonBattle.Batalla.join(room_id, trainer, team, pid)
            end)

            PokemonBattle.Batalla.start_battle(room_id)

            updated_room = updated_room_pids |> Map.put(:phase, :in_progress)
            new_state    = put_in(state.rooms[room_id], updated_room)
            {:reply, :ok, new_state}
        end
    end
  end

  def handle_call(:list, _from, state) do
    rooms = state.rooms |> Map.values() |> Enum.filter(fn r -> r.phase == :waiting end)

    IO.puts("\n=== Available rooms ===")
    if rooms == [], do: IO.puts("  (no rooms available)"),
    else: Enum.each(rooms, fn r ->
      IO.puts("  #{r.id} | Players: #{length(r.players)}/2 | Turn time: #{r.turn_time}s")
    end)

    {:reply, rooms, state}
  end

  def handle_call({:get, room_id}, _from, state), do: {:reply, Map.get(state.rooms, room_id), state}
end
