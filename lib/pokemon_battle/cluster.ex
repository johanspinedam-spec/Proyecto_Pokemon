defmodule PokemonBattle.Cluster do

  # Connect to node

  def connect(node) do
    case Node.connect(node) do
      true ->
        IO.puts("[Cluster] Successfully connected to #{node}.")
        :ok

      false ->
        IO.puts("[Cluster] Could not connect to #{node}.")
        {:error, "Connection failed"}

      :ignored ->
        IO.puts("[Cluster] Node ignored — this node is not distributed.")
        {:error, "Node not distributed"}
    end
  end

end
