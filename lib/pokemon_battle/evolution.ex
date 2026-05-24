defmodule PokemonBattle.Evolution do
  alias PokemonBattle.Persistencia

  # Check if Pokemon can evolve

  def can_evolve?(pokemon) do
    catalog = Persistencia.read_pokemon()
    base = catalog[pokemon["species"]]

    evolution = base["evolution"]
    evolution_wins = base["evolution_wins"]

    evolution != nil and
    evolution_wins != nil and
    pokemon["wins"] >= evolution_wins
  end

end 
