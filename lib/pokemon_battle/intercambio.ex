defmodule PokemonBattle.Intercambio do
  use GenServer

  def start_link(opts) do
    code = Keyword.fetch!(opts, :code)
    GenServer.start_link(__MODULE__, opts, name: via(code))
  end

  defp via(code) do
    {:via, Registry, {PokemonBattle.Registry, {:trade, code}}}
  end

  def init(opts) do
    state = %{
      code:         Keyword.fetch!(opts, :code),
      participants: %{},
      offers:       %{},
      confirmed:    [],
      pids:         %{}
    }
    {:ok, state}
  end

   def create(code) do
    spec = {__MODULE__, [code: code]}
    case DynamicSupervisor.start_child(PokemonBattle.SupervisorBatallas, spec) do
      {:ok, _pid} -> :ok
      {:error, _} -> {:error, "Could not create trade room"}
    end
  end

  def join(code, trainer, pid \\ self()) do
    GenServer.call(via(code), {:join, trainer, pid})
  end

  def offer(code, username, pokemon) do
    GenServer.call(via(code), {:offer, username, pokemon})
  end

  def confirm(code, username) do
    GenServer.call(via(code), {:confirm, username})
  end

  def cancel(code, username) do
    GenServer.call(via(code), {:cancel, username})
  end

  def get_state(code) do
    GenServer.call(via(code), :get_state)
  end

  def handle_call({:join, trainer, pid}, _from, state) do
    username = trainer["username"]
    creator  = List.first(Map.keys(state.participants))

    cond do
      map_size(state.participants) >= 2 ->
        {:reply, {:error, "Trade room already has 2 participants"}, state}

      Map.has_key?(state.participants, username) ->
        {:reply, {:error, "You are already in this room"}, state}

      creator == username ->
        {:reply, {:error, "You cannot join your own trade room"}, state}

      true ->
        new_state = state
          |> put_in([:participants, username], trainer)
          |> put_in([:pids, username], pid)

        IO.puts("[Trade #{state.code}] #{username} joined.")

        if map_size(new_state.participants) == 2 do
          IO.puts("[Trade #{state.code}] Both trainers connected. You can now trade.")
        end

        {:reply, :ok, new_state}
    end
  end

  def handle_call({:offer, username, pokemon}, _from, state) do
    cond do
      not Map.has_key?(state.participants, username) ->
        {:reply, {:error, "You are not in this room"}, state}

      true ->
        new_state = put_in(state.offers[username], pokemon)
        broadcast(new_state, "[Trade #{state.code}] #{username} offers [##{pokemon["id"]}] #{String.capitalize(pokemon["species"])}")
        show_trade_state(new_state)
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:confirm, username}, _from, state) do
    cond do
      not Map.has_key?(state.participants, username) ->
        {:reply, {:error, "You are not in this room"}, state}

      not Map.has_key?(state.offers, username) ->
        {:reply, {:error, "You must offer a Pokemon before confirming"}, state}

      username in state.confirmed ->
        {:reply, {:error, "You already confirmed your offer"}, state}

      true ->
        confirmed = [username | state.confirmed]
        new_state = %{state | confirmed: confirmed}

        if length(confirmed) == 2 do
          result = execute_trade(new_state)
          # Notificar a cada jugador con su resultado via PID
          Enum.each(new_state.pids, fn {user, pid} ->
            received = result[user]
            send(pid, {:trade_completed, received})
          end)
          {:reply, {:completed, result}, new_state}
        else
          broadcast(new_state, "[Trade #{state.code}] #{username} confirmed. Waiting for the other trainer...")
          {:reply, :ok, new_state}
        end
    end
  end

  def handle_call({:cancel, username}, _from, state) do
    broadcast(state, "[Trade #{state.code}] #{username} cancelled the trade. Room closed.")
    {:reply, :cancelled, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  defp execute_trade(state) do
    [user1, user2] = Map.keys(state.participants)
    pokemon1 = state.offers[user1]
    pokemon2 = state.offers[user2]

    broadcast(state, """

    [Trade #{state.code}] Trade completed!
      #{user1} received [##{pokemon2["id"]}] #{String.capitalize(pokemon2["species"])}
      #{user2} received [##{pokemon1["id"]}] #{String.capitalize(pokemon1["species"])}
    """)

    %{user1 => pokemon2, user2 => pokemon1}
  end

  defp show_trade_state(state) do
    [u1 | rest] = Map.keys(state.participants)
    u2 = List.first(rest)

    offer1 = case Map.get(state.offers, u1) do
      nil -> "(no offer)"
      p   -> "[##{p["id"]}] #{String.capitalize(p["species"])}"
    end

    offer2 = case Map.get(state.offers, u2) do
      nil -> "(no offer)"
      p   -> "[##{p["id"]}] #{String.capitalize(p["species"])}"
    end

    broadcast(state, "[Trade #{state.code}] #{u1} → #{offer1}\n                #{u2} → #{offer2}")

    if map_size(state.offers) == 2 do
      broadcast(state, "Both have offered. Confirm with: confirm_trade")
    end
  end
end
