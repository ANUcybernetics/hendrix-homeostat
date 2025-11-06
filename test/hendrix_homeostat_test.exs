defmodule HendrixHomeostatTest do
  use ExUnit.Case, async: true
  doctest HendrixHomeostat

  test "greets the world" do
    assert HendrixHomeostat.hello() == :world
  end
end
