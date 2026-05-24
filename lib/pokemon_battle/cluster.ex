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

  # List connected nodes

  def list_nodes do
    nodes = Node.list()

    IO.puts("\n=== Connected nodes ===")
    IO.puts("  This node: #{Node.self()}")

    if nodes == [] do
      IO.puts("  (no connected nodes)")
    else
      Enum.each(nodes, fn n ->
        IO.puts("  - #{n}")
      end)
    end

    nodes
  end

end
