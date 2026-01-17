defmodule ZimageClientTest do
  use ExUnit.Case
  doctest ZimageClient.Client

  test "greets the world" do
    assert :ok = ZimageClient.Client.ping()
  end
end