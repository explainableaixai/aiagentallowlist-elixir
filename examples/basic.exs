client = AIAgentAllowlist.Client.new(System.fetch_env!("AQ_API_KEY"))
IO.inspect(AIAgentAllowlist.Client.check(client, "https://example.com/checkout"))
