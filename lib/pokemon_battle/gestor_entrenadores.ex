defmodule PokemonBattle.GestorEntrenadores do
  alias PokemonBattle.Persistencia

  def login(username, password) do
    trainers = Persistencia.read_trainers()

    case Enum.find(trainers, fn t -> t["username"] == username end) do
      nil ->
        new_trainer = %{
          "username"          => username,
          "password"          => password,
          "coins"             => 0,
          "accumulated_coins" => 0,
          "wins"              => 0,
          "inventory"         => [],
          "packs"             => [initial_pack()],
          "teams"             => []
        }
        Persistencia.save_trainers([new_trainer | trainers])
        {:ok, :registered, new_trainer}

      trainer ->
        if trainer["password"] == password do
          {:ok, :logged_in, trainer}
        else
          {:error, "Incorrect password"}
        end
    end
  end

  def show_profile(trainer) do
    IO.puts("""

    === Profile of #{trainer["username"]} ===
    Wins:                 #{trainer["wins"]}
    Coins:                #{trainer["coins"]}
    Accumulated coins:    #{trainer["accumulated_coins"]}
    Pending packs:        #{length(trainer["packs"])}
    Pokemon in inventory: #{length(trainer["inventory"])}
    """)
  end

  def show_inventory(trainer) do
    inventory = trainer["inventory"]
    IO.puts("\n=== Inventory of #{trainer["username"]} (#{length(inventory)} Pokemon) ===")

    inventory
    |> Enum.with_index(1)
    |> Enum.each(fn {pokemon, index} ->
      types = Enum.join(pokemon["types"], "/")
      moves = pokemon["moves"]
              |> Enum.map(fn m -> "#{m["name"]}(#{m["base_power"]})" end)
              |> Enum.join(", ")

      IO.puts("  #{index}. [##{pokemon["id"]}] #{String.capitalize(pokemon["species"])} (#{types}) [#{pokemon["rarity"]}]")
      IO.puts("     Attack: #{pokemon["attack"]} | Defense: #{pokemon["defense"]} | Speed: #{pokemon["speed"]} | Max HP: 100")
      IO.puts("     Original owner: #{pokemon["original_owner"]}")
      IO.puts("     Wins: #{pokemon["wins"]} | Moves: #{moves}")
    end)
  end

  def add_coins(trainer, amount) do
    trainer
    |> Map.put("coins", trainer["coins"] + amount)
    |> Map.put("accumulated_coins", trainer["accumulated_coins"] + amount)
  end

  def show_leaderboard do
    trainers = Persistencia.read_trainers()

    sorted = Enum.sort_by(trainers, fn t -> {-t["wins"], -t["accumulated_coins"]} end)

    IO.puts("\n=== Global Leaderboard ===")
    IO.puts("#    Trainer          Wins   Accumulated coins")

    sorted
    |> Enum.with_index(1)
    |> Enum.each(fn {t, i} ->
      IO.puts("#{String.pad_trailing(to_string(i), 4)} " <>
              "#{String.pad_trailing(t["username"], 16)} " <>
              "#{String.pad_leading(to_string(t["wins"]), 6)}   " <>
              "#{t["accumulated_coins"]}")
    end)
  end

end
