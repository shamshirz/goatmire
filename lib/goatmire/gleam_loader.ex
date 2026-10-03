defmodule Goatmire.GleamLoader do
  @moduledoc false

  @doc """
  Append the compiled `goatmire_gleam` ebin path so `:goatmire_gleam` is
  callable from Elixir. Gleam deps (lustre, stdlib, …) come from Mix.
  """
  def ensure_loaded! do
    ebin =
      Path.join([
        File.cwd!(),
        "assets/gleam/build/dev/erlang/goatmire_gleam/ebin"
      ])

    unless File.dir?(ebin) do
      raise """
      Gleam Erlang build missing at #{ebin}.

      Run: mix goatmire.compile_gleam
      """
    end

    true = Code.append_path(ebin)
    :ok
  end
end
