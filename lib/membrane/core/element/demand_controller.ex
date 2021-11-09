defmodule Membrane.Core.Element.DemandController do
  @moduledoc false

  # Module handling demands incoming through output pads.

  use Bunch

  alias Membrane.Core.{CallbackHandler, Message}
  alias Membrane.Core.Child.PadModel
  alias Membrane.Core.Element.{ActionHandler, State}
  alias Membrane.Element.CallbackContext
  alias Membrane.Pad

  require Membrane.Core.Child.PadModel
  require Membrane.Logger

  @doc """
  Handles demand coming on an output pad. Updates demand value and executes `handle_demand` callback.
  """
  @spec handle_demand(Pad.ref_t(), non_neg_integer, State.t()) ::
          State.stateful_try_t()
  def handle_demand(pad_ref, size, state) do
    data = PadModel.get_data!(state, pad_ref)
    %{direction: :output, mode: :pull} = data
    do_handle_demand(pad_ref, size, data, state)
  end

  defp do_handle_demand(pad_ref, size, %{demand_mode: :auto} = data, state) do
    %{demand: old_demand, demand_pads: demand_pads} = data
    state = PadModel.set_data!(state, pad_ref, :demand, old_demand + size)

    if old_demand <= 0 do
      {:ok, Enum.reduce(demand_pads, state, &send_auto_demand_if_needed/2)}
    else
      {:ok, state}
    end
  end

  defp do_handle_demand(pad_ref, size, %{demand_mode: :manual} = data, state) do
    demand = data.demand + size
    state = PadModel.set_data!(state, pad_ref, :demand, demand)

    if exec_handle_demand?(data) do
      require CallbackContext.Demand
      context = &CallbackContext.Demand.from_state(&1, incoming_demand: size)

      CallbackHandler.exec_and_handle_callback(
        :handle_demand,
        ActionHandler,
        %{
          split_continuation_arbiter: &exec_handle_demand?(PadModel.get_data!(&1, pad_ref)),
          context: context
        },
        [pad_ref, demand, data.other_demand_unit],
        state
      )
    else
      {:ok, state}
    end
  end

  @spec send_auto_demand_if_needed(Pad.ref_t(), integer, State.t()) :: State.t()
  def send_auto_demand_if_needed(pad_ref, demand_decrease \\ 0, state) do
    data = PadModel.get_data!(state, pad_ref)
    %{demand: demand, toilet: toilet, demand_pads: demand_pads} = data

    demand = demand - demand_decrease
    demand_request_size = state.demand_size

    demand =
      if demand <= div(demand_request_size, 2) and auto_demands_positive?(demand_pads, state) do
        if toilet do
          :atomics.sub(toilet, 1, demand_request_size - demand)
        else
          %{pid: pid, other_ref: other_ref} = data
          Message.send(pid, :demand, demand_request_size - demand, for_pad: other_ref)
        end

        demand_request_size
      else
        demand
      end

    PadModel.set_data!(state, pad_ref, :demand, demand)
  end

  defp auto_demands_positive?(demand_pads, state) do
    Enum.all?(demand_pads, &(PadModel.get_data!(state, &1, :demand) > 0))
  end

  defp exec_handle_demand?(%{end_of_stream?: true}) do
    Membrane.Logger.debug_verbose("""
    Demand controller: not executing handle_demand as :end_of_stream action has already been returned
    """)

    false
  end

  defp exec_handle_demand?(%{demand: demand}) when demand <= 0 do
    Membrane.Logger.debug_verbose("""
    Demand controller: not executing handle_demand as demand is not greater than 0,
    demand: #{inspect(demand)}
    """)

    false
  end

  defp exec_handle_demand?(_pad_data) do
    true
  end
end
