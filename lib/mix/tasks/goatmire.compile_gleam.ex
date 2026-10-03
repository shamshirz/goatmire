defmodule Mix.Tasks.Goatmire.CompileGleam do
  @shortdoc "Build assets/gleam for the Erlang (server component) target"
  use Mix.Task

  @impl true
  def run(_args) do
    gleam = System.find_executable("gleam") || Mix.raise("gleam not found on PATH")
    dir = Path.expand("assets/gleam")

    Mix.shell().info("Compiling Gleam (erlang) in #{dir}…")

    {output, status} =
      System.cmd(gleam, ["build", "--target", "erlang"],
        cd: dir,
        stderr_to_stdout: true
      )

    Mix.shell().info(output)

    if status != 0 do
      Mix.raise("gleam build --target erlang failed with status #{status}")
    end

    :ok
  end
end
