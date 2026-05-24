defmodule PokemonBattle.SupervisorBatallas do
  use DynamicSupervisor

  # Start

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Start a new battle

  def start_battle(room_id, turn_time \\ 20) do
    spec = {
      PokemonBattle.Batalla,
      [room_id: room_id, turn_time: turn_time]
    }

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, _pid} ->
        IO.puts("[Supervisor] Battle #{room_id} started on node #{Node.self()}.")
        :ok

      {:error, {:already_started, _}} ->
        {:error, "A battle with that id already exists"}

      {:error, reason} ->
        {:error, "Could not start battle: #{inspect(reason)}"}
    end
  end

  # Stop a battle

  def stop_battle(room_id) do
    case Registry.lookup(PokemonBattle.Registry, {:battle, room_id}) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
        IO.puts("[Supervisor] Battle #{room_id} stopped.")
        :ok

      [] ->
        {:error, "Battle not found"}
    end
  end

end
