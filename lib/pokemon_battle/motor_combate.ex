defmodule PokemonBattle.MotorCombate do
  @advantages %{
    "Fire"     => ["Grass", "Ice", "Bug"],
    "Water"    => ["Fire", "Rock", "Ground"],
    "Grass"    => ["Water", "Rock", "Ground"],
    "Electric" => ["Water", "Flying"],
    "Rock"     => ["Fire", "Ice", "Flying", "Bug"]
  }

  def effectiveness(move_type, defender_types) do
    Enum.reduce(defender_types, 1.0, fn def_type, acc ->
      acc * modifier(move_type, def_type)
    end)
  end

  defp modifier(move_type, def_type) do
    strong_against = Map.get(@advantages, move_type, [])
    weak_against   = types_vulnerable_to(def_type)

    cond do
      def_type in strong_against -> 2.0
      move_type in weak_against  -> 0.5
      true                       -> 1.0
    end
  end

  defp types_vulnerable_to(def_type) do
    @advantages
    |> Enum.filter(fn {_attacker, defenders} -> def_type in defenders end)
    |> Enum.map(fn {attacker, _} -> attacker end)
  end

  def stab(move_type, attacker_types) do
    if move_type in attacker_types, do: 1.5, else: 1.0
  end

  def calculate_damage(move, attacker, defender) do
    power       = move["base_power"]
    move_type   = move["type"]
    eff         = effectiveness(move_type, defender["types"])
    stab_bonus  = stab(move_type, attacker["types"])
    rand_factor = 0.85 + :rand.uniform() * 0.15
    base_damage = trunc((power * (attacker["attack"] / defender["defense"])) / 5 + 2)
    max(trunc(base_damage * eff * stab_bonus * rand_factor), 1)
  end

  def effectiveness_message(move_type, defender_types) do
    case effectiveness(move_type, defender_types) do
      e when e >= 2.0 -> "It's super effective!"
      e when e <= 0.5 -> "It's not very effective..."
      _               -> ""
    end
  end

  def fainted?(pokemon), do: pokemon["current_hp"] <= 0

  def apply_damage(pokemon, damage) do
    Map.put(pokemon, "current_hp", max(pokemon["current_hp"] - damage, 0))
  end

  def initialize_team(team) do
    Enum.map(team, fn pokemon -> Map.put(pokemon, "current_hp", 100) end)
  end

  def build_turn_message(turn, rival, my_pokemon, my_team, rival_team) do
    moves_text =
      my_pokemon["moves"]
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {m, idx} ->
        "  #{idx}. #{String.pad_trailing(m["name"], 16)} (#{m["type"]}, power #{m["base_power"]})"
      end)

    """

    ═══ Turn #{turn} ═══
    Rival: #{String.capitalize(rival["species"])} (#{Enum.join(rival["types"], "/")}) | HP: #{rival["current_hp"]}/100
    Rival team: #{team_summary(rival_team)}

    Your Pokemon: [##{my_pokemon["id"]}] #{String.capitalize(my_pokemon["species"])} (#{Enum.join(my_pokemon["types"], "/")}) | Owner: #{my_pokemon["original_owner"]} | HP: #{my_pokemon["current_hp"]}/100 | Spd: #{my_pokemon["speed"]}
    Your team:    #{team_summary(my_team)}
    Moves:
    #{moves_text}

    Action > (attack <move> | switch <id> | surrender)
    """
  end

  def show_turn(turn, rival, my_pokemon, my_team, rival_team) do
    IO.puts(build_turn_message(turn, rival, my_pokemon, my_team, rival_team))
  end

  defp team_summary(team) do
    team
    |> Enum.map(fn p ->
      name = String.capitalize(p["species"])
      cond do
        Map.get(p, "active") -> "#{name}(active)"
        fainted?(p)          -> "#{name}(fainted)"
        true                 -> "#{name}(alive)"
      end
    end)
    |> Enum.join(" | ")
  end
end
