defmodule Membrane.Element.Manager.Pad do
  alias Membrane.Element.Manager.{State, PlaybackBuffer}
  use Membrane.Helper
  use Membrane.Mixins.Log, tags: :core

  def handle_message(message, mode, state) do
    with {:ok, state} <- do_handle_message(message, mode, state)
    do {:ok, state}
    else
      {:error, reason} ->
        warn_error """
        Pad: cannot handle message: #{inspect message}, mode: #{inspect mode}
        """, {:cannot_handle_message, message: message, mode: mode, reason: reason}
    end
  end

  def handle_playback_state(old, new, state) do
    with \
      {:ok, state} <- forward(:handle_playback_state, [old, new], state),
      {:ok, state} <- state |> PlaybackBuffer.eval,
    do: {:ok, state}
  end

  defp do_handle_message({type, args}, :info, state)
  when type in [:membrane_demand, :membrane_buffer, :membrane_caps, :membrane_event]
  do {type, args} |> PlaybackBuffer.store(state)
  end

  defp do_handle_message({:membrane_new_pad, args}, :call, state), do:
    forward(:handle_new_pad, args, state)

  defp do_handle_message(:membrane_linking_finished, :call, state), do:
    forward(:handle_linking_finished, state)

  defp do_handle_message({:membrane_set_message_bus, args}, :call, state), do:
    forward(:handle_message_bus, args, state)

  defp do_handle_message({:membrane_handle_link, args}, :call, state), do:
    forward(:handle_link, args, state)

  defp do_handle_message(:membrane_unlink, :call, state) do
    with :ok <- forward(:unlink, state),
    do: {:ok, state}
  end

  defp do_handle_message({:membrane_handle_unlink, args}, :call, state), do:
    forward(:handle_unlink, args, state)

  defp do_handle_message({:membrane_demand_in, args}, :call, state), do:
    forward(:handle_demand_in, args, state)

  defp do_handle_message({:membrane_self_demand, args}, :info, state), do:
    forward(:handle_self_demand, args, state)

  defp do_handle_message(other, :info, state), do:
    forward(:handle_message, other, state)

  defp forward(callback, args \\ [], %State{module: module} = state) do
    apply module.manager_module, callback, (args |> Helper.listify) ++ [state]
  end


end
