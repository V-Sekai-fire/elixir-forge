defmodule ZimageTest do
  use ExUnit.Case
  doctest Zimage

  test "greets the world" do
    assert Zimage.hello() == :world
  end
end