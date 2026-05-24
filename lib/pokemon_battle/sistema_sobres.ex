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

  
end
