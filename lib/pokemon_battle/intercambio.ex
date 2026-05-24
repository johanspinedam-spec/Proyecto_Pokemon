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
end
