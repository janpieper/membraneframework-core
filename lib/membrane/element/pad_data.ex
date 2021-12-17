defmodule Membrane.Element.PadData do
  @moduledoc """
  Struct describing current pad state.

  The public fields are:
    - `:accepted_caps` - specification of possible caps that are accepted on the pad.
      See `Membrane.Caps.Matcher` for more information.
    - `:availability` - see `Membrane.Pad.availability_t`
    - `:caps` - the most recent `Membrane.Caps` that have been sent (output) or received (input)
      on the pad. May be `nil` if not yet set.
    - `:demand` - current demand requested on the pad working in pull mode.
    - `:direction` - see `Membrane.Pad.direction_t`
    - `:end_of_stream?` - flag determining whether the stream processing via the pad has been finished
    - `:mode` - see `Membrane.Pad.mode_t`.
    - `:name` - see `Membrane.Pad.name_t`. Do not mistake with `:ref`
    - `:options` - options passed in `Membrane.ParentSpec` when linking pad
    - `:ref` - see `Membrane.Pad.ref_t`
    - `:start_of_stream?` - flag determining whether the stream processing via the pad has been started

  Other fields in the struct ARE NOT PART OF THE PUBLIC API and should not be
  accessed or relied on.
  """
  use Bunch.Access

  alias Membrane.{Caps, Pad}

  @type private_field :: term()

  @type t :: %__MODULE__{
          accepted_caps: Caps.Matcher.caps_specs_t(),
          availability: Pad.availability_t(),
          caps: Caps.t() | nil,
          demand: integer() | nil,
          start_of_stream?: boolean(),
          end_of_stream?: boolean(),
          direction: Pad.direction_t(),
          mode: Pad.mode_t(),
          name: Pad.name_t(),
          ref: Pad.ref_t(),
          options: %{optional(atom) => any},
          demand_unit: private_field,
          other_demand_unit: private_field,
          pid: private_field,
          other_ref: private_field,
          sticky_messages: private_field,
          input_buf: private_field,
          toilet: private_field,
          demand_mode: private_field,
          associated_pads: private_field
        }

  @enforce_keysx [
    :accepted_caps,
    :availability,
    :direction,
    :mode,
    :name,
    :caps,
    :ref,
    :pid,
    :other_ref,
    :start_of_stream?,
    :end_of_stream?,
    :options,
    :toilet,
    :associated_pads
  ]

  defstruct @enforce_keysx ++
              [
                input_buf: nil,
                demand: nil,
                demand_mode: nil,
                demand_unit: nil,
                other_demand_unit: nil,
                sticky_messages: []
              ]
end