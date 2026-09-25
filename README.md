# AIAgentAllowlist

Elixir client for [AI agent allow list lookups before each navigation](https://www.aiagentallowlist.com). If your application lets a language model browse (fetching pages, following links, filling forms), this package checks each target URL first. The service recognises sensitive page types such as login, checkout, upload and account settings, and returns a verdict you can enforce in one pattern match.

## Installation

```elixir
{:aiagentallowlist, "~> 1.0"}
```

## A check

```elixir
guard = AIAgentAllowlist.Client.new(System.fetch_env!("AQ_API_KEY"))

{:ok, result} = AIAgentAllowlist.Client.check(guard, "https://app.example.com/settings/delete-account")
result["verdict"]            #=> "deny"
result["matched"]["layer"]   #=> "rules"
result["matched"]["id"]      #=> the page type that triggered it
```

`check/2` sends the value as the `url` parameter and accepts either a full URL or a bare domain:

- **URL**: the answer includes `"verdict"` and `"matched"`. The `"layer"` inside it is `"rules"` for built-in path patterns or `"page_type_db"` for pages known from the site catalogue.
- **Domain**: the answer is the site record, with `"found"`, `"language"` and a `"page_types"` map from page type to URL.

## A guard for LLM tool calls

Elixir agent libraries, such as LangChain for Elixir, describe tools as functions the model can call. Put the check at the start of the browsing function and return plain text either way:

```elixir
defmodule MyAgent.Tools.Browse do
  @timeout 4_000

  def run(%{"url" => url}, guard) do
    task = Task.async(fn -> AIAgentAllowlist.Client.check(guard, url) end)

    case Task.yield(task, @timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, %{"verdict" => "allow"}}} ->
        MyAgent.Fetcher.text(url)

      {:ok, {:ok, %{"matched" => %{"id" => kind}}}} ->
        {:ok, "Stopped: #{kind} pages are handled by a person. Tell the user what is needed."}

      _ ->
        {:ok, "Stopped: the page could not be cleared by policy right now."}
    end
  end
end
```

The design choices behind that code:

- **Only `"allow"` proceeds.** Any other verdict, including ones added later, stops the step.
- **The refusal is a normal tool result.** The model can explain it to the user or try another source, instead of crashing the run.
- **A hard time limit.** `Task.yield/2` plus `Task.shutdown/2` bound the wait. A slow check stops the step instead of freezing the agent.

## Why page-level and not domain-level

Blocking whole domains either stops too much or too little. An agent comparing SaaS prices should read the pricing page of a vendor it must never log in to. The page-type catalogue knows where the sensitive pages live on many sites, and the rule layer catches common sensitive paths on sites it has never seen. Together they let agents read widely while action pages stay with people.

## Previewing a site's sensitive pages

```elixir
case AIAgentAllowlist.Client.check(guard, "atlassian.com") do
  {:ok, %{"found" => true, "page_types" => pages}} ->
    for {kind, url} <- pages, do: IO.puts("#{String.pad_trailing(kind, 12)} #{url}")

  {:ok, %{"found" => false}} ->
    IO.puts("not catalogued; path rules still apply to full URLs")

  {:error, reason} ->
    IO.inspect(reason, label: "lookup failed")
end
```

Showing this list to a person before a long run is a simple way to earn trust in automation.

## Failure modes

| Return value | What to do |
|---|---|
| `{:error, {:api_error, 401, _}}` | Fix the key |
| `{:error, {:api_error, 403, _}}` | Check the plan and monthly quota |
| `{:error, {:api_error, 429, _}}` | Slow down. Req already retried |
| `{:error, %Req.TransportError{}}` | Network trouble after retries. Treat as "not cleared" |

`new/2` and `check/2` both guard against empty strings with function-clause guards, so a missing key fails at startup rather than at the first agent step.

Lookups go through `Req.get/2`, which retries transient errors with backoff by default. Combine that with your own overall timeout, as in the tool example, so retries never push past what the agent can wait.

## Telemetry and audit

Emit an event per decision and attach handlers for logging or metrics:

```elixir
:telemetry.execute([:my_agent, :navigation, :checked], %{count: 1},
  %{run_id: run_id, url: url, verdict: verdict, page_type: kind})
```

These events answer the post-incident question of what the agent attempted. Over time they also show which workflows keep reaching sensitive pages, which usually means a human step belongs there.

## Rolling out safely

Run in observe mode first: check every URL and log the verdict, but do not block. After a week, the log shows what enforcement would change. Then enforce, starting with agents that can spend money or modify records.

## Configuration

```elixir
AIAgentAllowlist.Client.new(key, base_url: "https://www.aiagentallowlist.com/api")
```

`:base_url` is the only option. Point it at a stub server in tests, or at an internal gateway that adds logging.

## Related guardrails

Agents also call AI services. Use [allow/deny lists for tool-use guardrails](https://www.aitoolsblocklist.com/ai-blocklist-api.php) to cover them. Find [shadow AI usage before prompts leave employee devices](https://www.shadowaitools.com/detection-methodology.php) with a log audit. When policy depends on subject matter, look up the [IAB category](https://www.urlcategorizationdatabase.com/taxonomy.php) of each destination.

Other implementations: [the Go module](https://pkg.go.dev/github.com/explainableaixai/aiagentallowlist-go), [the Dart package](https://pub.dev/packages/aiagentallowlist) and [the PyPI release](https://pypi.org/project/aiagentallowlist/).

## License

MIT
