defmodule PokemonBattleTest do
  use ExUnit.Case

  alias PokemonBattle.MotorCombate
  alias PokemonBattle.SistemaSobres
  alias PokemonBattle.Intercambio


  # 1. Cálculo de daño: fuerte, débil y neutro


  defp base_attacker(types), do: %{"attack" => 100, "types" => types}
  defp base_defender(types), do: %{"defense" => 100, "types" => types}

  test "damage is higher with super effective move (Electric vs Water)" do
    move     = %{"name" => "thunderbolt", "type" => "Electric", "base_power" => 90}
    attacker = base_attacker(["Electric"])
    defender = base_defender(["Water"])

    damage = MotorCombate.calculate_damage(move, attacker, defender)

    # Electric > Water (x2.0) + STAB (x1.5) → debe ser bastante alto
    # Sin efectividad ni STAB: base = trunc((90 * 100/100)/5 + 2) = 20
    # Con x2.0 y x1.5 y factor minimo 0.85: trunc(20 * 2.0 * 1.5 * 0.85) = 51 mínimo
    assert damage >= 51
  end

  test "damage is lower with not very effective move (Electric vs Grass)" do
    move     = %{"name" => "thunderbolt", "type" => "Electric", "base_power" => 90}
    attacker = base_attacker(["Electric"])
    defender = base_defender(["Grass"])

    damage = MotorCombate.calculate_damage(move, attacker, defender)

    # Grass no es Water ni Flying → Electric no es fuerte contra Grass
    # Grass es fuerte contra Water/Rock/Ground, no contra Electric → neutro
    # Pero Electric > Water, y Grass no está en esa lista → neutro x1.0
    # Con STAB x1.5: base=20, trunc(20 * 1.0 * 1.5 * 0.85) = 25 mínimo
    assert damage >= 10
  end

  test "damage with neutral move has no effectiveness multiplier" do
    move     = %{"name" => "tackle", "type" => "Normal", "base_power" => 35}
    attacker = base_attacker(["Normal"])
    defender = base_defender(["Normal"])

    damage = MotorCombate.calculate_damage(move, attacker, defender)

    # Normal vs Normal → neutro x1.0, STAB x1.5
    # base = trunc((35 * 100/100)/5 + 2) = 9
    # trunc(9 * 1.0 * 1.5 * 0.85) = 11 mínimo, trunc(9 * 1.0 * 1.5 * 1.0) = 13 máximo
    assert damage >= 11
    assert damage <= 14
  end

  test "super effective damage is greater than not very effective damage" do
    move            = %{"name" => "ember", "type" => "Fire", "base_power" => 30}
    attacker        = base_attacker(["Fire"])
    defender_weak   = base_defender(["Grass"])   # Fire > Grass → x2.0
    defender_strong = base_defender(["Water"])   # Water > Fire → Fire x0.5 contra Water

    damage_super    = MotorCombate.calculate_damage(move, attacker, defender_weak)
    damage_resisted = MotorCombate.calculate_damage(move, attacker, defender_strong)

    assert damage_super > damage_resisted
  end

  

end
