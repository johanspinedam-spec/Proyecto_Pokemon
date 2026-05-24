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

end
