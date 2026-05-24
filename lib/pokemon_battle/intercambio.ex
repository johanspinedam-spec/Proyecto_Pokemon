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

   def create(code) do
    spec = {__MODULE__, [code: code]}
    case DynamicSupervisor.start_child(PokemonBattle.SupervisorBatallas, spec) do
      {:ok, _pid} -> :ok
      {:error, _} -> {:error, "Could not create trade room"}
    end
  end

  def join(code, trainer, pid \\ self()) do
    GenServer.call(via(code), {:join, trainer, pid})
  end

  def offer(code, username, pokemon) do
    GenServer.call(via(code), {:offer, username, pokemon})
  end

  def confirm(code, username) do
    GenServer.call(via(code), {:confirm, username})
  end

  def cancel(code, username) do
    GenServer.call(via(code), {:cancel, username})
  end

  def get_state(code) do
    GenServer.call(via(code), :get_state)
  end

end
