defmodule Mix.Tasks.Goatmire.GleamAssets do
  @shortdoc "Copy Lustre server-component client runtime into priv/static"
  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("deps.compile", ["lustre"])

    src =
      Path.join([
        Mix.Project.deps_path(),
        "lustre",
        "priv",
        "static",
        "lustre-server-component.min.mjs"
      ])

    dest_dir = Path.join([File.cwd!(), "priv", "static", "assets", "gleam"])
    File.mkdir_p!(dest_dir)
    dest = Path.join(dest_dir, "lustre-server-component.min.mjs")

    unless File.exists?(src) do
      Mix.raise("Lustre client runtime not found at #{src}")
    end

    File.cp!(src, dest)
    Mix.shell().info("Copied Lustre server component runtime → #{dest}")
    :ok
  end
end
