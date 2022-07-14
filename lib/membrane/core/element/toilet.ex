defmodule Membrane.Core.Element.Toilet do
  defmodule DistributedCounter do
    @moduledoc """
    Atomic
    """
    def new(type) do
      atomic_ref = :atomics.new(1, [])

      case type do
        :same_node ->
          {:same_node, atomic_ref}

        :different_nodes ->
          {:ok, pid} = GenServer.start(Membrane.Core.Element.Toilet.DistributedCounterWorker, [])
          {:different_nodes, pid, atomic_ref}
      end
    end

    def add_get({:same_node, atomic_ref}, value) do
      :atomics.add_get(atomic_ref, 1, value)
    end

    def add_get({:different_nodes, pid, atomic_ref}, value) when node(pid) == node(self()) do
      :atomics.add_get(atomic_ref, 1, value)
    end

    def add_get({:different_nodes, pid, atomic_ref}, value) do
      GenServer.call(pid, {:add_get, atomic_ref, value})
    end

    def sub({:same_node, atomic_ref}, value) do
      :atomics.sub(atomic_ref, 1, value)
    end

    def sub({:different_nodes, pid, atomic_ref}, value) when node(pid) == node(self()) do
      :atomics.sub(atomic_ref, 1, value)
    end

    def sub({:different_nodes, pid, atomic_ref}, value) do
      GenServer.cast(pid, {:sub, atomic_ref, value})
    end
  end

  defmodule DistributedCounterWorker do
    use GenServer

    def init(_) do
      {:ok, nil}
    end

    def handle_call({:add_get, atomic_ref, value}, _from, _state) do
      result = :atomics.add_get(atomic_ref, 1, value)
      {:reply, result, nil}
    end

    def handle_cast({:sub, atomic_ref, value}, _state) do
      :atomics.sub(atomic_ref, 1, value)
      {:noreply, nil}
    end
  end

  @moduledoc false

  # Toilet is an entity that can be filled and drained. If it's not drained on
  # time and exceeds its capacity, it overflows by logging an error and killing
  # the responsible process (passed on the toilet creation).

  require Membrane.Logger

  @opaque t :: {__MODULE__, :atomics.atomics_ref(), pos_integer, Process.dest()}

  @default_capacity_factor 200

  @spec new(
          pos_integer() | nil,
          Membrane.Buffer.Metric.unit_t(),
          Process.dest(),
          :same_node | :different_nodes
        ) :: t
  def new(capacity, demand_unit, responsible_process, counter_type) do
    default_capacity =
      Membrane.Buffer.Metric.from_unit(demand_unit).buffer_size_approximation() *
        @default_capacity_factor

    toilet_ref = DistributedCounter.new(counter_type)
    capacity = capacity || default_capacity
    {__MODULE__, toilet_ref, capacity, responsible_process}
  end

  @spec fill(t, non_neg_integer) :: :ok | :overflow
  def fill({__MODULE__, atomic, capacity, responsible_process}, amount) do
    size = DistributedCounter.add_get(atomic, amount)

    if size > capacity do
      overflow(size, capacity, responsible_process)
      :overflow
    else
      :ok
    end
  end

  @spec drain(t, non_neg_integer) :: :ok
  def drain({__MODULE__, atomic, _capacity, _responsible_process}, amount) do
    DistributedCounter.sub(atomic, amount)
  end

  defp overflow(size, capacity, responsible_process) do
    Membrane.Logger.debug_verbose(~S"""
    Toilet overflow

                 ` ' `
             .'''. ' .'''.
               .. ' ' ..
              '  '.'.'  '
              .'''.'.'''.
             ' .''.'.''. '
           ;------ ' ------;
           | ~~ .--'--//   |
           |   /   '   \   |
           |  /    '    \  |
           |  |    '    |  |  ,----.
           |   \ , ' , /   | =|____|=
           '---,###'###,---'  (---(
              /##  '  ##\      )---)
              |##, ' ,##|     (---(
               \'#####'/       `---`
                \`"#"`/
                 |`"`|
               .-|   |-.
          jgs /  '   '  \
              '---------'
    """)

    Membrane.Logger.error("""
    Toilet overflow.

    Reached the size of #{inspect(size)}, which is above toilet capacity (#{inspect(capacity)})
    when storing data from output working in push mode. It means that some element in the pipeline
    processes the stream too slow or doesn't process it at all.
    To have control over amount of buffers being produced, consider using output in pull mode
    (see `Membrane.Pad.mode_t`).
    You can also try changing the `toilet_capacity` in `Membrane.ParentSpec.via_in/3`.
    """)

    Process.exit(responsible_process, :kill)
  end
end
