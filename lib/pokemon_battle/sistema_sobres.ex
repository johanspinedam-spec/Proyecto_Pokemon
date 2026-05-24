defmodule PokemonBattle.SistemaSobres do
  alias PokemonBattle.Persistencia

  # Buy pack

  def buy_pack(trainer, type) do
    shop = Persistencia.read_shop()

    case Map.get(shop, type) do
      nil ->
        {:error, "Pack type not found. Use: basic or advanced"}

      pack_info ->
        price = pack_info["price"]

        if trainer["coins"] < price do
          {:error, "Not enough coins. Need #{price}, have #{trainer["coins"]}"}
        else
          new_pack = %{"id" => :rand.uniform(999_999), "type" => type}

          updated_trainer =
            trainer
            |> Map.put("coins", trainer["coins"] - price)
            |> Map.put("packs", trainer["packs"] ++ [new_pack])

          {:ok, updated_trainer, new_pack}
        end
    end
  end

  # Open pack

  def open_pack(trainer, pack_id) do
    packs = trainer["packs"]

    pack = case pack_id do
      "last" -> List.last(packs)
      _      -> Enum.find(packs, fn p -> to_string(p["id"]) == to_string(pack_id) end)
    end

    case pack do
      nil ->
        {:error, "Pack not found"}

      found_pack ->
        shop     = Persistencia.read_shop()
        pack_cfg = shop[found_pack["type"]]
        probs    = pack_cfg["probabilities"]

        new_pokemon = Enum.map(1..3, fn _ ->
          species = random_species()
          rarity  = roll_rarity(probs)
          create_instance(species, rarity, trainer["username"])
        end)

        remaining_packs = List.delete(packs, found_pack)

        updated_trainer =
          trainer
          |> Map.put("packs", remaining_packs)
          |> Map.put("inventory", trainer["inventory"] ++ new_pokemon)

        {:ok, updated_trainer, new_pokemon}
    end
  end

  # Create pokemon instance

  def create_instance(species, rarity, owner) do
    catalog = Persistencia.read_pokemon()
    base    = catalog[species]
    factor  = rarity_factor(rarity)

    moves = assign_moves(base["types"])

    %{
      "id"             => :rand.uniform(999_999),
      "species"        => species,
      "types"          => base["types"],
      "original_owner" => owner,
      "rarity"         => rarity,
      "attack"         => round(base["base_attack"]   * (1 + factor / 100)),
      "defense"        => round(base["base_defense"]  * (1 + factor / 100)),
      "speed"          => round(base["base_speed"]    * (1 + factor / 100)),
      "moves"          => moves,
      "wins"           => 0
    }
  end

  # Assign moves

  defp assign_moves(types) do
    pool = Persistencia.read_moves()

    type_moves = case types do
      [single_type] ->
        pool
        |> Map.get(single_type, [])
        |> Enum.shuffle()
        |> Enum.take(2)

      [type1, type2] ->
        move1 = pool |> Map.get(type1, []) |> Enum.shuffle() |> Enum.take(1)
        move2 = pool |> Map.get(type2, []) |> Enum.shuffle() |> Enum.take(1)
        move1 ++ move2
    end

    all_moves = pool |> Map.values() |> List.flatten() |> Enum.uniq()

    extra_moves = all_moves
      |> Enum.reject(fn m -> m in type_moves end)
      |> Enum.shuffle()
      |> Enum.take(2)

    type_moves ++ extra_moves
  end

  # Roll rarity

  defp roll_rarity(probs) do
    n = :rand.uniform(100)

    cond do
      n <= probs["common"]                    -> "common"
      n <= probs["common"] + probs["rare"]    -> "rare"
      true                                    -> "epic"
    end
  end

end
