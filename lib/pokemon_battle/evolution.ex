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

  # Evolve a Pokemon

  def evolve(pokemon) do
    catalog = Persistencia.read_pokemon()
    base = catalog[pokemon["species"]]
    new_species = base["evolution"]
    new_base = catalog[new_species]

    old_attack = pokemon["attack"]
    old_defense = pokemon["defense"]
    old_speed = pokemon["speed"]

    new_attack = round(old_attack * (new_base["base_attack"] / base["base_attack"]))
    new_defense = round(old_defense * (new_base["base_defense"] / base["base_defense"]))
    new_speed = round(old_speed * (new_base["base_speed"] / base["base_speed"]))

    new_moves = assign_evolution_moves(pokemon["moves"], new_base["types"])

    evolved = pokemon
      |> Map.put("species", new_species)
      |> Map.put("types", new_base["types"])
      |> Map.put("attack", new_attack)
      |> Map.put("defense", new_defense)
      |> Map.put("speed", new_speed)
      |> Map.put("moves", new_moves)

    IO.puts("\n Congratulations! #{String.capitalize(pokemon["species"])} evolved into #{String.capitalize(new_species)}!")
    IO.puts("   Attack:  #{old_attack} → #{new_attack}")
    IO.puts("   Defense: #{old_defense} → #{new_defense}")
    IO.puts("   Speed:   #{old_speed} → #{new_speed}")

    evolved
  end

  # Check and evolve all eligible pokemon

  def check_evolutions(trainer) do
    update_inventory = Enum.map(trainer["inventory"], fn pokemon ->
      if can_evolve?(pokemon) do
        evolve(pokemon)
      else
        pokemon
      end
    end)

    Map.put(trainer, "inventory", update_inventory)
  end

  # Evolution chain info

  def show_evolution_chain(species) do
    catalog = Persistencia.read_pokemon()
    chain = build_chain(catalog, species, [])

    IO.puts("\n Evolution Chain for #{String.capitalize(species)}:")
    chain
    |> Enum.with_index(1)
    |> Enum.each(fn {s, index} ->
      base = catalog[s]
      wins_needed = base["evolution_wins"]
      wins_text = if wins_needed, do: "(evolves at #{wins_needed} wins)", else: "(final evolution)"
      IO.puts("  #{index}. #{String.capitalize(s)} #{wins_text}")
    end)
  end

end
