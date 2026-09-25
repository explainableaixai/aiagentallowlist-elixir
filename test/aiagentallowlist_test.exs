defmodule AIAgentAllowlistTest do
  use ExUnit.Case

  test "constructs a client" do
    client = AIAgentAllowlist.Client.new("test")
    assert client.api_key == "test"
  end
end
