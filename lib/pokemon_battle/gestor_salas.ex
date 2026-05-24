defmodule PokemonBattle.GestorSalas do
  use GenServer

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def init(_), do: {:ok, %{rooms: %{}, counter: 0}}

  

end
