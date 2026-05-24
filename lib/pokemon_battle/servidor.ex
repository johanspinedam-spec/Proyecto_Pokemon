defmodule PokemonBattle.Servidor do
  alias PokemonBattle.GestorEntrenadores
  alias PokemonBattle.SistemaSobres
  alias PokemonBattle.GestorSalas
  alias PokemonBattle.Intercambio
  alias PokemonBattle.Cluster
  alias PokemonBattle.Persistencia
  alias PokemonBattle.Evolution

  defstruct trainer: nil, current_team: nil, current_room: nil, trade_room: nil

  def start do
    IO.puts("""
    ╔══════════════════════════════════════╗
    ║      Welcome to Pokemon Battles!     ║
    ║      Type 'play' to get started      ║
    ╚══════════════════════════════════════╝
    """)
    loop(%__MODULE__{})
  end

  defp loop(session) do
    new_session =
      try do
        flush_battle_events(session)
      catch
        {:updated_session, updated} -> updated
      end

    prompt = if new_session.trainer,
      do: "\n[#{new_session.trainer["username"]}] > ",
      else: "\n[guest] > "

    IO.write(prompt)
    input = IO.gets("") |> String.trim()

    next_session = process(input, new_session)
    loop(next_session)
  end

  defp flush_battle_events(session) do
    receive do
      {:battle_event, msg} ->
        IO.puts(msg)
        flush_battle_events(session)

      {:refresh_trainer, username} ->
        # Recargar datos frescos desde el archivo
        trainers = Persistencia.read_trainers()
        case Enum.find(trainers, fn t -> t["username"] == username end) do
          nil     -> flush_battle_events(session)
          trainer ->
            IO.puts("\nProfile updated — Coins: #{trainer["coins"]} | Wins: #{trainer["wins"]}")
            # Retornar la sesión actualizada
            throw({:updated_session, %{session | trainer: trainer, current_room: nil}})
        end

    after
      0 -> session
    end
  end

  defp process("play", session) do
    IO.puts("""
    SESSION
      login <username> <password>
      logout
      profile
      leaderboard

    INVENTORY & PACKS
      inventory
      shop
      buy_pack <basic|advanced>
      open_pack <id|last>

    EVOLUTION
      evolution <species>

    TEAMS
      create_team <name> <ids>
      show_team <name>
      list_teams
      use_team <name>
      add_to_team <name> <id>
      remove_from_team <name> <id>
      rename_team <old_name> <new_name>
      delete_team <name>


    BATTLE
      create_room <seconds>
      list_rooms
      join_room <room_id>
      start_battle <room_id>
      attack <move_name>
      switch <pokemon_id>
      surrender

    TRADE
      create_trade_room
      join_trade_room <code>
      offer_pokemon <pokemon_id>
      confirm_trade
      cancel_trade

    CLUSTER
      connect_node <node@host>
      list_nodes
      cluster_info
    """)
    session
  end

  defp process("logout", session) do
    IO.puts("Goodbye, #{session.trainer["username"]}!")
    %{session | trainer: nil, current_team: nil, current_room: nil, trade_room: nil}
  end

  defp process("profile", session) do
    with_session(session, fn -> GestorEntrenadores.show_profile(session.trainer) end)
  end

  defp process("leaderboard", session) do
    GestorEntrenadores.show_leaderboard()
    session
  end

  defp process("inventory", session) do
    with_session(session, fn -> GestorEntrenadores.show_inventory(session.trainer) end)
  end

  defp process("login " <> rest, session) do
    case String.split(rest) do
      [username, password] ->
        case GestorEntrenadores.login(username, password) do
          {:ok, :registered, trainer} ->
            IO.puts("Welcome #{username}! Account created. You have 1 free basic pack.")
            %{session | trainer: trainer}

          {:ok, :logged_in, trainer} ->
            IO.puts("Welcome back, #{username}!")
            %{session | trainer: trainer}

          {:error, msg} ->
            IO.puts("Error: #{msg}")
            session
        end

      _ ->
        IO.puts("Usage: login <username> <password>")
        session
    end
  end

  defp process("shop", session) do
    shop = Persistencia.read_shop()
    IO.puts("\n=== Shop ===")
    Enum.each(shop, fn {type, info} ->
      IO.puts("  #{type} — #{info["price"]} coins | Common: #{info["probabilities"]["common"]}% | Rare: #{info["probabilities"]["rare"]}% | Epic: #{info["probabilities"]["epic"]}%")
    end)
    session
  end

  defp process("buy_pack " <> type, session) do
    with_session(session, fn ->
      case SistemaSobres.buy_pack(session.trainer, String.trim(type)) do
        {:ok, updated_trainer, pack} ->
          IO.puts("#{pack["type"]} pack purchased! Pack id: #{pack["id"]}")
          save_trainer(updated_trainer)
          %{session | trainer: updated_trainer}

        {:error, msg} ->
          IO.puts("Error: #{msg}")
          session
      end
    end)
  end

  defp process("open_pack " <> id, session) do
    with_session(session, fn ->
      case SistemaSobres.open_pack(session.trainer, String.trim(id)) do
        {:ok, updated_trainer, pokemon_list} ->
          SistemaSobres.show_pack_result(pokemon_list, session.trainer["username"])
          save_trainer(updated_trainer)
          %{session | trainer: updated_trainer}

        {:error, msg} ->
          IO.puts("Error: #{msg}")
          session
      end
    end)
  end

  defp process("evolution " <> species, session) do
    Evolution.show_evolution_chain(String.trim(species))
    session
  end

  defp process("create_team " <> rest, session) do
    with_session(session, fn ->
      case String.split(rest) do
        [name | id_parts] ->
          ids = id_parts |> Enum.join("") |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

          case GestorEntrenadores.create_team(session.trainer, name, ids) do
            {:ok, updated_trainer} ->
              IO.puts("Team '#{name}' created with #{length(ids)} Pokemon.")
              save_trainer(updated_trainer)
              %{session | trainer: updated_trainer}

            {:error, msg} ->
              IO.puts("Error: #{msg}")
              session
          end

        _ ->
          IO.puts("Usage: create_team <name> <id1,id2,id3>")
          session
      end
    end)
  end

  defp process("list_teams", session) do
    with_session(session, fn -> GestorEntrenadores.list_teams(session.trainer) end)
  end

  defp process("use_team " <> name, session) do
    with_session(session, fn ->
      case String.trim(name) do
        "" ->
          IO.puts(" Missing team name. Usage: use_team <name>")
          session

        n ->
          team = Enum.find(session.trainer["teams"], fn t -> t["name"] == n end)

          case team do
            nil ->
              IO.puts("  Team '#{n}' not found. Use list_teams to see your teams.")
              session

            t ->
              missing_ids = Enum.reject(t["ids"], fn id ->
                Enum.any?(session.trainer["inventory"], fn p ->
                  to_string(p["id"]) == to_string(id)
                end)
              end)

              if length(missing_ids) > 0 do
                IO.puts("  Cannot use team '#{n}': Pokemon not in inventory: #{Enum.join(missing_ids, ", ")}")
                session
              else
                team_pokemon = Enum.map(t["ids"], fn id ->
                  Enum.find(session.trainer["inventory"], fn p ->
                    to_string(p["id"]) == to_string(id)
                  end)
                end)

                IO.puts("Team '#{n}' selected (#{length(team_pokemon)} Pokemon).")
                %{session | current_team: team_pokemon}
              end
          end
      end
    end)
  end

  # Ver detalle de un equipo
  defp process("show_team " <> name, session) do
    with_session(session, fn ->
      case GestorEntrenadores.get_team(session.trainer, String.trim(name)) do
        {:error, msg} ->
          IO.puts("  #{msg}")
          session

        {:ok, team} ->
          IO.puts("\n=== Team '#{team["name"]}' [#{length(team["ids"])}/3] ===")
          Enum.each(team["ids"], fn id ->
            pokemon = Enum.find(session.trainer["inventory"], fn p ->
              to_string(p["id"]) == to_string(id)
            end)
            case pokemon do
              nil -> IO.puts("  [##{id}] (not in inventory)")
              p   ->
                IO.puts("  [##{p["id"]}] #{String.capitalize(p["species"])} " <>
                        "(#{Enum.join(p["types"], "/")}) [#{p["rarity"]}] " <>
                        "| Atk: #{p["attack"]} Def: #{p["defense"]} Spd: #{p["speed"]}")
            end
          end)
          session
      end
    end)
  end

  # Renombrar equipo
  defp process("rename_team " <> rest, session) do
    with_session(session, fn ->
      case String.split(String.trim(rest)) do
        [old_name, new_name] ->
          case GestorEntrenadores.rename_team(session.trainer, old_name, new_name) do
            {:ok, updated_trainer} ->
              IO.puts(" Team '#{old_name}' renamed to '#{new_name}'.")
              save_trainer(updated_trainer)
              %{session | trainer: updated_trainer}

            {:error, msg} ->
              IO.puts("  #{msg}")
              session
          end

        _ ->
          IO.puts("  Usage: rename_team <old_name> <new_name>")
          session
      end
    end)
  end

  # Agregar pokemon a equipo existente
  defp process("add_to_team " <> rest, session) do
    with_session(session, fn ->
      case String.split(String.trim(rest)) do
        [team_name, pokemon_id] ->
          case GestorEntrenadores.add_pokemon_to_team(session.trainer, team_name, pokemon_id) do
            {:ok, updated_trainer} ->
              IO.puts(" Pokemon ##{pokemon_id} added to team '#{team_name}'.")
              save_trainer(updated_trainer)
              %{session | trainer: updated_trainer}

            {:error, msg} ->
              IO.puts("  #{msg}")
              session
          end

        _ ->
          IO.puts(" Usage: add_to_team <team_name> <pokemon_id>")
          session
      end
    end)
  end

  # Quitar pokemon de equipo
  defp process("remove_from_team " <> rest, session) do
    with_session(session, fn ->
      case String.split(String.trim(rest)) do
        [team_name, pokemon_id] ->
          case GestorEntrenadores.remove_pokemon_from_team(session.trainer, team_name, pokemon_id) do
            {:ok, updated_trainer} ->
              IO.puts(" Pokemon ##{pokemon_id} removed from team '#{team_name}'.")
              save_trainer(updated_trainer)
              %{session | trainer: updated_trainer}

            {:error, msg} ->
              IO.puts("  #{msg}")
              session
          end

        _ ->
          IO.puts(" Usage: remove_from_team <team_name> <pokemon_id>")
          session
      end
    end)
  end

  # Eliminar equipo completo
  defp process("delete_team " <> name, session) do
    with_session(session, fn ->
      case GestorEntrenadores.delete_team(session.trainer, String.trim(name)) do
        {:ok, updated_trainer} ->
          IO.puts(" Team '#{String.trim(name)}' deleted.")
          save_trainer(updated_trainer)
          %{session | trainer: updated_trainer}

        {:error, msg} ->
          IO.puts("  #{msg}")
          session
      end
    end)
  end


end
