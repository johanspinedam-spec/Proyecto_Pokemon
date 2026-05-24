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

end
