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
end
