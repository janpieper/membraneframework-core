defmodule Membrane.Support.DemandsTest.Pipeline do
  @moduledoc false
  use Membrane.Pipeline

  @impl true
  def handle_init(opts) do
    children = [
      source: opts.source,
      filter: opts.filter,
      sink: opts.sink
    ]

    links = [
      link(:source)
      |> via_in(:input, demand_excess_factor: 1.25)
      |> to(:filter)
      |> via_in(:input, demand_excess_factor: 1.25)
      |> to(:sink)
    ]

    spec = %Membrane.ParentSpec{
      children: children,
      links: links
    }

    {{:ok, spec: spec}, %{target: opts.target}}
  end

  @impl true
  def handle_other({:child_msg, name, msg}, _ctx, state) do
    {{:ok, forward: {name, msg}}, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, %{target: target} = state) do
    send(target, :playing)
    {:ok, state}
  end
end
