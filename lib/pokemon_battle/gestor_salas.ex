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

  

end
