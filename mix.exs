defmodule AIAgentAllowlist.MixProject do
  use Mix.Project

  def project,
    do: [
      app: :aiagentallowlist,
      version: "1.0.0",
      elixir: "~> 1.14",
      description: "Elixir client for AI Agent Allowlist.",
      package: package(),
      deps: deps(),
      docs: [main: "readme", extras: ["README.md"]],
      source_url: "https://github.com/explainableaixai/aiagentallowlist-elixir",
      homepage_url: "https://www.aiagentallowlist.com"
    ]

  def application, do: [extra_applications: [:logger]]
  defp deps, do: [{:req, "~> 0.5"}, {:ex_doc, "~> 0.34", only: :dev, runtime: false}]

  defp package,
    do: [
      licenses: ["MIT"],
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE),
      links: %{
        "Homepage" => "https://www.aiagentallowlist.com",
        "GitHub" => "https://github.com/explainableaixai/aiagentallowlist-elixir"
      }
    ]
end
