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

end
