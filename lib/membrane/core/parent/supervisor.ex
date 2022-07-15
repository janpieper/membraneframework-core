defmodule Membrane.Core.Parent.Supervisor do
  use GenServer

  alias Membrane.Core.Parent.ChildrenSupervisor

  require Membrane.Core.Message, as: Message
  require Membrane.Logger

  def go_brrr(method, start_fun, setup_logger) do
    with {:ok, pid} <- GenServer.start(__MODULE__, {start_fun, setup_logger, self()}) do
      # Not doing start_link here is a nasty hack to avoid `terminate` being called
      # once parent sends an `exit` signal. This way we receive it in `handle_info`
      # and can wait till the children exit without calling `receive`.
      if method == :start_link do
        Process.link(pid)
      end

      receive do
        Message.new(:parent_spawned, parent) -> {:ok, pid, parent}
      end
    end
  end

  @impl true
  def init({start_fun, setup_logger, reply_to}) do
    Process.flag(:trap_exit, true)
    {:ok, children_supervisor} = ChildrenSupervisor.start_link()

    with {:ok, parent} <- start_fun.(children_supervisor) do
      setup_logger.(parent)
      Message.send(reply_to, :parent_spawned, parent)
      {:ok, %{parent: {:alive, parent}, children_supervisor: children_supervisor}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_info(Message.new(:child_death, _args) = message, %{parent: {:alive, parent}} = state) do
    send(parent, message)
    {:noreply, state}
  end

  @impl true
  def handle_info(Message.new(:child_death, _args), state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, %{parent: {:alive, pid}} = state) do
    Membrane.Logger.debug("Parent supervisor: parent exited, stopping children supervisor")
    Process.exit(state.children_supervisor, :shutdown)
    {:noreply, %{state | parent: {:exited, reason}}}
  end

  @impl true
  def handle_info(
        {:EXIT, pid, reason},
        %{children_supervisor: pid, parent: {:exited, parent_exit_reason}} = state
      ) do
    Membrane.Logger.debug(
      "Parent supervisor: children supervisor exited, reason: #{inspect(reason)}. Exiting."
    )

    {:stop, parent_exit_reason, state}
  end

  @impl true
  def handle_info(
        {:EXIT, pid, reason},
        %{children_supervisor: pid, parent: {:alive, _parent_pid}} = state
      ) do
    Membrane.Logger.debug(
      "Parent supervisor: children supervisor failure, reason: #{inspect(reason)}. Exiting."
    )

    {:stop, {:shutdown, :children_supervisor_failed}, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, reason}, %{parent: {:alive, parent_pid}} = state) do
    Membrane.Logger.debug("Parent supervisor: got exit from a linked process, stopping parent")
    Process.exit(parent_pid, reason)
    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, _reason}, state) do
    Membrane.Logger.debug(
      "Parent supervisor: got exit from a linked process, parent already dead, waiting for children supervisor to exit"
    )

    {:noreply, state}
  end
end