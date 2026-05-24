defmodule PokemonBattle.Batalla do
  use GenServer
  alias PokemonBattle.{MotorCombate, Persistencia, Evolution}

  def start_link(opts) do
    id = Keyword.fetch!(opts, :room_id)
    GenServer.start_link(__MODULE__, opts, name: via(id))
  end

  defp via(room_id) do
    {:via, Registry, {PokemonBattle.Registry, {:battle, room_id}}}
  end

  def init(opts) do
    :net_kernel.monitor_nodes(true)
    state = %{
      room_id:           Keyword.fetch!(opts, :room_id),
      turn_time:         Keyword.get(opts, :turn_time, 20),
      players:           %{},
      teams:             %{},
      actives:           %{},
      actions:           %{},
      pids:              %{},
      pending_switch:    %{},
      disconnect_timers: %{},
      turn:              0,
      phase:             :waiting,
      timer:             nil,
      started_at:        DateTime.utc_now(),
      node:              Node.self()
    }
    {:ok, state}
  end

  def join(room_id, trainer, team, pid \\ self()) do
    GenServer.call(via(room_id), {:join, trainer, team, pid})
  end

  def start_battle(room_id) do
    GenServer.call(via(room_id), :start)
  end

  def send_action(room_id, username, action) do
    GenServer.call(via(room_id), {:action, username, action})
  end

  def surrender(room_id, username) do
    GenServer.call(via(room_id), {:surrender, username})
  end

  def get_state(room_id) do
    GenServer.call(via(room_id), :get_state)
  end

  def handle_call({:join, trainer, team, pid}, _from, state) do
    players = state.players

    cond do
      map_size(players) >= 2 ->
        {:reply, {:error, "Room is full"}, state}

      Map.has_key?(players, trainer["username"]) ->
        {:reply, {:error, "Already in this room"}, state}

      true ->
        team_init = MotorCombate.initialize_team(team)
        new_state = state
          |> put_in([:players, trainer["username"]], trainer)
          |> put_in([:teams, trainer["username"]], team_init)
          |> put_in([:actives, trainer["username"]], hd(team_init))
          |> put_in([:pids, trainer["username"]], pid)

        notify_player(new_state, trainer["username"],
          "[Room #{state.room_id}] You joined the battle. Waiting for opponent...")
        {:reply, :ok, new_state}
    end
  end

  def handle_call(:start, _from, state) do
    if map_size(state.players) < 2 do
      {:reply, {:error, "Need 2 players to start"}, state}
    else
      new_state = %{state | phase: :in_progress, turn: 1}
      broadcast(new_state, "\n  Battle started! Get ready!")
      show_current_turn(new_state)
      timer = start_timer(state.turn_time)
      {:reply, :ok, %{new_state | timer: timer}}
    end
  end

  def handle_call({:action, username, action}, _from, state) do
    cond do
      state.phase != :in_progress ->
        {:reply, {:error, "Battle is not in progress"}, state}

      not Map.has_key?(state.players, username) ->
        {:reply, {:error, "You are not in this battle"}, state}

      # Si este jugador tiene un switch pendiente, solo acepta {:switch, id}
      Map.get(state.pending_switch, username, false) ->
        case action do
          {:switch, pokemon_id} ->
            team = state.teams[username]
            new_active = Enum.find(team, fn p ->
              to_string(p["id"]) == to_string(pokemon_id) and not MotorCombate.fainted?(p)
            end)

            if new_active == nil do
              notify_player(state, username, " That Pokemon is fainted or not found. Choose another one.")
              {:reply, {:error, "Invalid switch"}, state}
            else
              new_state = state
                |> put_in([:actives, username], new_active)
                |> put_in([:pending_switch, username], false)
                |> update_in_team(username, new_active)

              broadcast(new_state, " #{username} sent out #{String.capitalize(new_active["species"])}!")

              if Enum.any?(new_state.pending_switch, fn {_, v} -> v == true end) do
                notify_player(new_state, username, "Waiting for opponent to switch too...")
                {:reply, :ok, new_state}
              else
                clean_state = %{new_state | actions: %{}, turn: new_state.turn + 1}
                show_current_turn(clean_state)
                timer = start_timer(clean_state.turn_time)
                {:reply, :ok, %{clean_state | timer: timer}}
              end
            end

          _ ->
            notify_player(state, username, "Your Pokemon fainted! You must switch: switch <pokemon_id>")
            {:reply, {:error, "You must switch your fainted Pokemon first"}, state}
        end

      Map.has_key?(state.actions, username) ->
        {:reply, {:error, "You already sent your action this turn"}, state}

      true ->
        new_state = put_in(state.actions[username], action)
        notify_player(new_state, username, " Action registered. Waiting for opponent...")

        if map_size(new_state.actions) == 2 do
          cancel_timer(new_state.timer)
          new_state2 = resolve_turn(new_state)
          {:reply, :ok, new_state2}
        else
          {:reply, :ok, new_state}
        end
    end
  end
end
