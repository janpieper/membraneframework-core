defmodule GroupServer do
  use GenServer
  import Kernel, except: [self: 0, send: 2]

  def start_link(specs \\ [], opts \\ []) do
    # :observer.start()
    specs = Enum.map(specs, fn {module, opts} -> {make_ref(), module, opts} end)
    {:ok, pid} = GenServer.start_link(__MODULE__, specs, opts)
    refs = Enum.map(specs, fn {ref, _module, _opts} -> {__MODULE__, pid, ref} end)
    {:ok, pid, refs}
  end

  def add_subserver(pid, module, opts) do
    ref = GenServer.call(pid, {:add_subserver, module, opts})
    {:ok, ref}
  end

  def call(ref, msg, timeout \\ 5000)

  def call({__MODULE__, pid, ref}, msg, _timeout) when pid == Kernel.self() do
    {:reply, reply, _state} = exec(ref, :handle_call, [msg, nil])
    reply
  end

  def call({__MODULE__, pid, ref}, msg, timeout) do
    GenServer.call(pid, {__MODULE__, ref, msg}, timeout)
  end

  def call(pid, msg, timeout) when is_pid(pid) do
    if pid == Kernel.self() and __MODULE__.self() != Kernel.self() do
      call(__MODULE__.self(), msg, timeout)
    else
      GenServer.call(pid, msg, timeout)
    end
  end

  def send({__MODULE__, pid, ref}, msg) when pid == Kernel.self() do
    {:noreply, _state} = exec(ref, :handle_info, [msg])
    msg
  end

  def send({__MODULE__, pid, ref}, msg) do
    Kernel.send(pid, {__MODULE__, ref, msg})
    msg
  end

  def send(pid, msg) when is_pid(pid) do
    if pid == Kernel.self() and __MODULE__.self() != Kernel.self() do
      __MODULE__.send(__MODULE__.self(), msg)
    else
      Kernel.send(pid, msg)
    end
  end

  def cast({__MODULE__, pid, ref}, msg) when pid == Kernel.self() do
    {:noreply, _state} = exec(ref, :handle_cast, [msg])
    :ok
  end

  def cast({__MODULE__, pid, ref}, msg) do
    GenServer.cast(pid, {__MODULE__, ref, msg})
  end

  def cast(pid, msg) when is_pid(pid) do
    if pid == Kernel.self() and __MODULE__.self() != Kernel.self() do
      cast(__MODULE__.self(), msg)
    else
      GenServer.cast(pid, msg)
    end
  end

  def self() do
    case Process.get(:self) do
      nil -> Kernel.self()
      ref -> {__MODULE__, Kernel.self(), ref}
    end
  end

  def wrap_self(msg) do
    case self() do
      {__MODULE__, _pid, ref} -> {__MODULE__, ref, msg}
      _pid -> msg
    end
  end

  @impl true
  def init(opts) do
    Enum.each(opts, fn {ref, module, opts} ->
      Process.put(ref, {module, opts})
      exec(ref, :init, [])
    end)

    {:ok, %{}}
  end

  @impl true
  def handle_call({:add_subserver, module, opts}, _from, state) do
    ref = make_ref()
    Process.put(ref, {module, opts})
    exec(ref, :init, [])
    {:reply, {__MODULE__, Kernel.self(), ref}, state}
  end

  @impl true
  def handle_call({__MODULE__, ref, msg}, from, state) do
    exec(ref, :handle_call, [msg, from], state)
  end

  @impl true
  def handle_info({__MODULE__, ref, msg}, state) do
    exec(ref, :handle_info, [msg], state)
  end

  @impl true
  def handle_cast({__MODULE__, ref, msg}, state) do
    exec(ref, :handle_cast, [msg], state)
  end

  defp exec(ref, callback, args, state \\ nil) do
    {module, substate} = Process.get(ref)
    old_self = Process.put(:self, ref)
    {result, substate} = apply(module, callback, args ++ [substate]) |> handle_result(state)
    Process.put(:self, old_self)
    Process.put(ref, {module, substate})
    result
  end

  defp handle_result({:noreply, substate}, state) do
    {{:noreply, state}, substate}
  end

  defp handle_result({:reply, reply, substate}, state) do
    {{:reply, reply, state}, substate}
  end

  defp handle_result({:ok, substate}, state) do
    {{:ok, state}, substate}
  end
end
