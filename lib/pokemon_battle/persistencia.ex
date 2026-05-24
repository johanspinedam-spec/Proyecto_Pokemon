defmodule PokemonBattle.Persistencia do
  @trainers_path "data/trainers.json"
  @pokemon_path  "data/pokemon.json"
  @moves_path    "data/moves.json"
  @shop_path     "data/shop.json"
  @battles_log   "data/battles.log"

  def read_trainers do
    case File.read(@trainers_path) do
      {:ok, content} -> Jason.decode!(content)
      {:error, _}    -> []
    end
  end

  def save_trainers(trainers) do
    content = Jason.encode!(trainers, pretty: true)
    File.write!(@trainers_path, content)
  end

  def read_pokemon do
    {:ok, content} = File.read(@pokemon_path)
    Jason.decode!(content)
  end

  def read_moves do
    {:ok, content} = File.read(@moves_path)
    Jason.decode!(content)
  end

  def read_shop do
    {:ok, content} = File.read(@shop_path)
    Jason.decode!(content)
  end

  def log_battle(info) do
    line = "#{info.date} | #{info.player1} vs #{info.player2} | " <>
           "Winner: #{info.winner} | Turns: #{info.turns} | " <>
           "Node: #{info.node} | Duration: #{info.duration}\n"
    File.write!(@battles_log, line, [:append])
  end
end
