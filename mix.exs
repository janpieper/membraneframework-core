defmodule Membrane.Mixfile do
  use Mix.Project

  @version "0.5.2"
  @source_ref "v#{@version}"

  def project do
    [
      app: :membrane_core,
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Membrane Multimedia Framework (Core)",
      dialyzer: [
        flags: [:error_handling, :underspecs]
      ],
      package: package(),
      name: "Membrane Core",
      source_url: link(),
      docs: docs(),
      aliases: ["test.all": "do espec, test"],
      preferred_cli_env: [
        espec: :test,
        "test.all": :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      test_coverage: [tool: ExCoveralls, test_task: "test.all"],
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [], mod: {Membrane, []}]
  end

  defp elixirc_paths(:test), do: ["lib", "spec/support", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp link do
    "https://github.com/membraneframework/membrane-core"
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: @source_ref,
      nest_modules_by_prefix: [
        Membrane.Bin,
        Membrane.Pipeline,
        Membrane.Element,
        Membrane.Element.CallbackContext,
        Membrane.Pipeline.CallbackContext,
        Membrane.Bin.CallbackContext,
        Membrane.Payload,
        Membrane.Buffer,
        Membrane.Caps,
        Membrane.Event,
        Membrane.EventProtocol,
        Membrane.Testing
      ],
      groups_for_modules: [
        Pipeline: [~r/^Membrane.Pipeline/],
        Bin: [~r/^Membrane.Bin/],
        Element: [
          ~r/^Membrane.Filter$/,
          ~r/^Membrane.Sink$/,
          ~r/^Membrane.Source$/,
          ~r/^Membrane.Element/,
          ~r/^Membrane.Core.InputBuffer/
        ],
        Parent: [~r/^Membrane.Parent.*/],
        Child: [~r/^Membrane.Child.*/],
        Communication: [
          ~r/^Membrane.(Buffer|Payload|Caps|Event|Notification).*/
        ],
        Logging: [~r/^Membrane.Logger/],
        Testing: [~r/^Membrane.Testing.*/],
        Utils: [
          ~r/^Membrane.Clock$/,
          ~r/^Membrane.Sync$/,
          ~r/^Membrane.Time.*/,
          ~r/^Membrane.Pad.*/,
          ~r/^Membrane.PlaybackState.*/
        ],
        Deprecated: [~r/^Membrane.Log\.?/]
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => link(),
        "Membrane Framework Homepage" => "https://membraneframework.org"
      }
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:espec, "~> 1.8", only: :test},
      {:excoveralls, "~> 0.11", only: :test},
      {:qex, "~> 0.3"},
      {:bunch, "~> 1.3"},
      {:ratio, "~> 2.0"}
    ]
  end
end
