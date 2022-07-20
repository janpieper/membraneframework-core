defmodule Membrane.Core.Element.Toilet do
  defmodule Atomic do
    @moduledoc """
    Atomic
    """
    def new(type) do
      case type do
        :same_node ->
          {:same_node, :atomics.new(1, [])}

        :different_nodes ->
          {:ok, pid} = GenServer.start(Membrane.Core.Element.Toilet.AtomicProcess, [])
          {:different_nodes, pid}
      end
    end

    def add_get({:different_nodes, ref}, value) do
      GenServer.cast(ref, {:add, value})
      GenServer.call(ref, :get)
    end

    def add_get({:same_node, ref}, value) do
      :atomics.add_get(ref, 1, value)
    end

    def sub({:different_nodes, ref}, value) do
      GenServer.cast(ref, {:sub, value})
    end

    def sub({:same_node, ref}, value) do
      :atomics.sub(ref, 1, value)
    end
  end

  defmodule AtomicProcess do
    use GenServer

    def init(_) do
      {:ok, 0}
    end

    def handle_cast({:add, value}, state) do
      {:noreply, state + value}
    end

    def handle_cast({:sub, value}, state) do
      {:noreply, state - value}
    end

    def handle_call(:get, _from, state) do
      {:reply, state, state}
    end
  end

  @moduledoc false

  # Toilet is an entity that can be filled and drained. If it's not drained on
  # time and exceeds its capacity, it overflows by logging an error and killing
  # the responsible process (passed on the toilet creation).

  require Membrane.Logger

  @opaque t :: {__MODULE__, :atomics.atomics_ref(), pos_integer, Process.dest()}

  @default_capacity_factor 200

  @spec new(pos_integer() | nil, Membrane.Buffer.Metric.unit_t(), Process.dest()) :: t
  def new(capacity, demand_unit, responsible_process) do
    default_capacity =
      Membrane.Buffer.Metric.from_unit(demand_unit).buffer_size_approximation() *
        @default_capacity_factor

    toilet_ref = Atomic.new(:different_nodes)
    capacity = capacity || default_capacity
    {__MODULE__, toilet_ref, capacity, responsible_process}
  end

  @spec fill(t, non_neg_integer) :: :ok | :overflow
  def fill({__MODULE__, atomic, capacity, responsible_process}, amount) do
    size = Atomic.add_get(atomic, amount)

    if size > capacity do
      overflow(size, capacity, responsible_process)
      :overflow
    else
      :ok
    end
  end

  @spec drain(t, non_neg_integer) :: :ok
  def drain({__MODULE__, atomic, _capacity, _responsible_process}, amount) do
    Atomic.sub(atomic, amount)
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
