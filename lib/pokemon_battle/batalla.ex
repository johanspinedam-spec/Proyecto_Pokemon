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

  def handle_call({:surrender, username}, _from, state) do
    [winner] = Map.keys(state.players) |> Enum.reject(&(&1 == username))
    new_state = end_battle(state, winner, "surrender")
    {:reply, :ok, new_state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_info(:turn_timeout, state) do
    broadcast(state, "\nTime is up! Turn resolved automatically.")
    new_state = resolve_turn(state)
    {:noreply, new_state}
  end

  def handle_info({:nodedown, node}, state) do
    # Buscar qué jugador estaba en ese nodo
    disconnected_user = Enum.find_value(state.pids, fn {username, pid} ->
      if node(pid) == node, do: username, else: nil
    end)

    if disconnected_user && state.phase == :in_progress do
      broadcast(state, "  #{disconnected_user} disconnected. They have 15 seconds to reconnect or they lose.")
      timer = Process.send_after(self(), {:disconnect_timeout, disconnected_user}, 15_000)
      new_state = put_in(state.disconnect_timers[disconnected_user], timer)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:disconnect_timeout, username}, state) do
    if state.phase == :in_progress do
      [winner] = Map.keys(state.players) |> Enum.reject(&(&1 == username))
      broadcast(state, " #{username} did not reconnect in time. #{winner} wins!")
      new_state = end_battle(state, winner, "disconnect")
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  defp resolve_turn(state) do
    [p1, p2]  = Map.keys(state.players)
    action_p1 = Map.get(state.actions, p1, :pass)
    action_p2 = Map.get(state.actions, p2, :pass)
    spd_p1    = state.actives[p1]["speed"]
    spd_p2    = state.actives[p2]["speed"]

    {first, second, act_first, act_second} =
      cond do
        spd_p1 > spd_p2 ->
          {p1, p2, action_p1, action_p2}
        spd_p2 > spd_p1 ->
          {p2, p1, action_p2, action_p1}
        :rand.uniform(2) == 1 ->
          {p1, p2, action_p1, action_p2}
        true ->
          {p2, p1, action_p2, action_p1}
      end

    broadcast(state, "\n─── Resolving turn #{state.turn} ───")

    state1 = execute_action(state, first, second, act_first)

    state2 =
      if active_fainted?(state1, second), do: state1,
      else: execute_action(state1, second, first, act_second)

    state3 = check_end(state2)

    if state3.phase == :in_progress do
      # Verificar si algún Pokémon activo quedó debilitado
      state4 = check_pending_switches(state3)

      if Enum.any?(state4.pending_switch, fn {_, v} -> v == true end) do
        # Hay jugadores que deben cambiar de Pokémon
        state4
      else
        clean_state = %{state4 | actions: %{}, turn: state4.turn + 1}
        show_current_turn(clean_state)
        timer = start_timer(state4.turn_time)
        %{clean_state | timer: timer}
      end
    else
      state3
    end
  end
end
