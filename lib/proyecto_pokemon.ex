defmodule PokemonBattle.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: PokemonBattle.Registry},
      PokemonBattle.SupervisorBatallas,
    ]

    children = if Node.self() == :nonode@nohost or primary_node?() do
      children ++ [PokemonBattle.GestorSalas]
    else
      children
    end

    opts = [strategy: :one_for_one, name: PokemonBattle.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp primary_node? do
    node_name = Node.self() |> to_string()
    String.contains?(node_name, "node1")
  end
end
