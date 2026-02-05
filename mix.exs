defmodule Predicated.MixProject do
  use Mix.Project

  @source_url "https://github.com/themusicman/predicated"
  @version "1.1.2"

  def project do
    [
      app: :predicated,
      version: @version,
      elixir: "~> 1.13",
      package: package(),
      aliases: aliases(),
      deps: deps(),
      docs: docs()
    ]
  end

  def cli do
    [
      preferred_envs: [
        check: :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_parsec, "~> 1.2"},
      {:flamel, "~> 1.4"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:doctor, "~> 0.22.0", only: [:dev, :test]},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  def package do
    [
      description:
        "A library that allows for building predicates to query an in-memory data structure in Elixir",
      maintainers: ["Thomas Brewer"],
      contributors: ["Thomas Brewer"],
      licenses: ["MIT"],
      links: %{
        GitHub: @source_url
      }
    ]
  end

  defp aliases do
    [
      check: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo list --format=oneline",
        "doctor",
        "test"
      ]
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md",
        LICENSE: [title: "License"],
        "README.md": [title: "Readme"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      api_reference: false,
      formatters: ["html"]
    ]
  end
end
