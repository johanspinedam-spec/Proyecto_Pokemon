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

  # --- CRUD EQUIPOS ---

  # CREATE
  def create_team(trainer, name, ids) do
    teams = trainer["teams"]

    cond do
      Enum.any?(teams, fn t -> t["name"] == name end) ->
        {:error, "A team named '#{name}' already exists"}

      length(ids) < 1 or length(ids) > 3 ->
        {:error, "Team must have between 1 and 3 Pokemon"}

      true ->
        inventory_ids = Enum.map(trainer["inventory"], fn p -> to_string(p["id"]) end)
        invalid_ids   = Enum.reject(ids, fn id -> to_string(id) in inventory_ids end)

        if length(invalid_ids) > 0 do
          {:error, "Pokemon not found in inventory: #{Enum.join(invalid_ids, ", ")}"}
        else
          new_team = %{"name" => name, "ids" => ids}
          {:ok, Map.put(trainer, "teams", [new_team | teams])}
        end
    end
  end

  # READ
  def list_teams(trainer) do
    teams = trainer["teams"]

    IO.puts("\n=== Saved teams of #{trainer["username"]} ===")

    if teams == [] do
      IO.puts("  (no teams yet)")
    else
      Enum.each(teams, fn t ->
        ids = Enum.join(t["ids"], ", ")
        IO.puts("  #{t["name"]} [#{length(t["ids"])}/3]: #{ids}")
      end)
    end
  end

  def get_team(trainer, name) do
    case Enum.find(trainer["teams"], fn t -> t["name"] == name end) do
      nil  -> {:error, "Team '#{name}' not found"}
      team -> {:ok, team}
    end
  end

  # UPDATE — renombrar equipo
  def rename_team(trainer, old_name, new_name) do
    teams = trainer["teams"]

    cond do
      not Enum.any?(teams, fn t -> t["name"] == old_name end) ->
        {:error, "Team '#{old_name}' not found"}

      Enum.any?(teams, fn t -> t["name"] == new_name end) ->
        {:error, "A team named '#{new_name}' already exists"}

      true ->
        updated_teams = Enum.map(teams, fn t ->
          if t["name"] == old_name, do: Map.put(t, "name", new_name), else: t
        end)
        {:ok, Map.put(trainer, "teams", updated_teams)}
    end
  end

  # UPDATE — agregar pokemon al equipo
  def add_pokemon_to_team(trainer, team_name, pokemon_id) do
    teams = trainer["teams"]

    case Enum.find(teams, fn t -> t["name"] == team_name end) do
      nil ->
        {:error, "Team '#{team_name}' not found"}

      team ->
        cond do
          length(team["ids"]) >= 3 ->
            {:error, "Team '#{team_name}' is already full (3/3)"}

          to_string(pokemon_id) in Enum.map(team["ids"], &to_string/1) ->
            {:error, "Pokemon ##{pokemon_id} is already in this team"}

          not Enum.any?(trainer["inventory"], fn p -> to_string(p["id"]) == to_string(pokemon_id) end) ->
            {:error, "Pokemon ##{pokemon_id} not found in your inventory"}

          true ->
            updated_teams = Enum.map(teams, fn t ->
              if t["name"] == team_name,
                do: Map.put(t, "ids", t["ids"] ++ [to_string(pokemon_id)]),
                else: t
            end)
            {:ok, Map.put(trainer, "teams", updated_teams)}
        end
    end
  end

  # UPDATE — quitar pokemon del equipo
  def remove_pokemon_from_team(trainer, team_name, pokemon_id) do
    teams = trainer["teams"]

    case Enum.find(teams, fn t -> t["name"] == team_name end) do
      nil ->
        {:error, "Team '#{team_name}' not found"}

      team ->
        cond do
          not (to_string(pokemon_id) in Enum.map(team["ids"], &to_string/1)) ->
            {:error, "Pokemon ##{pokemon_id} is not in team '#{team_name}'"}

          length(team["ids"]) <= 1 ->
            {:error, "Cannot remove the last Pokemon from a team. Delete the team instead."}

          true ->
            new_ids = Enum.reject(team["ids"], fn id -> to_string(id) == to_string(pokemon_id) end)
            updated_teams = Enum.map(teams, fn t ->
              if t["name"] == team_name, do: Map.put(t, "ids", new_ids), else: t
            end)
            {:ok, Map.put(trainer, "teams", updated_teams)}
        end
    end
  end

  # DELETE — eliminar equipo completo
  def delete_team(trainer, name) do
    teams = trainer["teams"]

    case Enum.find(teams, fn t -> t["name"] == name end) do
      nil ->
        {:error, "Team '#{name}' not found"}

      _ ->
        updated_teams = Enum.reject(teams, fn t -> t["name"] == name end)
        {:ok, Map.put(trainer, "teams", updated_teams)}
    end
  end

  defp initial_pack do
    %{"id" => :rand.uniform(999_999), "type" => "basic"}
  end

end
