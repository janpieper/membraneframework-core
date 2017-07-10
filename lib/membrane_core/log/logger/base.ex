defmodule Membrane.Logger.Base do
  @moduledoc """
    This is a base module used by all logger implementations.
  """


  @doc """
  Callback invoked when logger is initialized, right after new process is
  spawned.

  On success it should return `{:ok, initial_logger_state}`.
  """
  @callback handle_init(Membrane.Logger.logger_options_t) ::
    {:ok, any} |
    {:error, any}


  @doc """
  Callback invoked when new log message is received.

  Callback delivers 5 arguments:
  * log level: atom, one of: :debug, :info, :warn
  * message: basic element or list of basic elements
  * timestamp
  * tags (list of atoms, e.g. module name)
  * logger state


  Basic elements are:
  * atom
  * charlist
  * integer
  * float
  * bitstring


  On success, it returns `{:ok, new_state}`. it will just update logger's state
  to the new state.

  If it returns `{:error, reason, new_state}` it indicates that something
  went wrong, and logger was unable to handle log. State will be updated to
  the new state.
  """
  @callback handle_log(Membrane.Logger.msg_level_t, Membrane.Logger.message_t, Membane.Time.native_t, list(Membrane.Logger.tag_t), any) ::
    {:ok, any} |
    {:error, any, any}


  @doc """
  Callback invoked when logger is shutting down just before process is exiting.
  It will receive the logger state.

  Return value is ignored.
  """
  @callback handle_shutdown(any) :: any


  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Membrane.Logger.Base

      # Default implementations

      @doc false
      def handle_init(_opts), do: {:ok, %{}}

      @doc false
      def handle_shutdown(_state), do: :ok


      defoverridable [
        handle_init: 1,
        handle_shutdown: 1,
      ]
    end
  end
end
