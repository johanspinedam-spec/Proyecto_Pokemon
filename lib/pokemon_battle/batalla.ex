defmodule PokemonBattle.Batalla do
  use GenServer
  alias PokemonBattle.{MotorCombate, Persistencia, Evolution}

  def start_link(opts) do
    id = Keyword.fetch!(opts, :room_id)
    GenServer.start_link(__MODULE__, opts, name: via(id))
  end

  defp via(room_id) do
    {:via, Registry, {PokemonBattle.Registry, {:battle, room_id}}}
  end

  def init(opts) do
    :net_kernel.monitor_nodes(true)
    state = %{
      room_id:           Keyword.fetch!(opts, :room_id),
      turn_time:         Keyword.get(opts, :turn_time, 20),
      players:           %{},
      teams:             %{},
      actives:           %{},
      actions:           %{},
      pids:              %{},
      pending_switch:    %{},
      disconnect_timers: %{},
      turn:              0,
      phase:             :waiting,
      timer:             nil,
      started_at:        DateTime.utc_now(),
      node:              Node.self()
    }
    {:ok, state}
  end

end
