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

end
