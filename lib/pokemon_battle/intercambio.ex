defmodule PokemonBattle.Intercambio do
  use GenServer

  def start_link(opts) do
    code = Keyword.fetch!(opts, :code)
    GenServer.start_link(__MODULE__, opts, name: via(code))
  end

  defp via(code) do
    {:via, Registry, {PokemonBattle.Registry, {:trade, code}}}
  end

  def init(opts) do
    state = %{
      code:         Keyword.fetch!(opts, :code),
      participants: %{},
      offers:       %{},
      confirmed:    [],
      pids:         %{}
    }
    {:ok, state}
  end

end
