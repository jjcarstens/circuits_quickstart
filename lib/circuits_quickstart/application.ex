defmodule CircuitsQuickstart.Application do
  @moduledoc false

  use Application

  @spec start(Application.start_type(), any()) :: {:error, any} | {:ok, pid()}
  def start(_type, _args) do
    # Start the ssh server. In a real application, we'd need to link to the
    # daemon pid that's returned and put it in a supervision tree so that
    # crashes get handled properly.
    _ = start_ssh()

    opts = [strategy: :one_for_one, name: CircuitsQuickstart.Supervisor]

    Supervisor.start_link([], opts)
  end

  def start_ssh() do
    # Nerves stores a system default iex.exs. It's not in IEx's search path,
    # so run a search with it included.
    iex_opts = [dot_iex_path: find_iex_exs()]

    devpath = Nerves.Runtime.KV.get("nerves_fw_devpath") || "/dev/mmcblk0"

    :ssh.daemon(22, [
      {:id_string, :random},
      {:key_cb, CircuitsQuickstart.Keys.key_cb()},
      {:user_passwords, [{'circuits', 'circuits'}]},
      {:shell, {Elixir.IEx, :start, [iex_opts]}},
      {:exec, &start_exec/3},
      {:subsystems,
       [:ssh_sftpd.subsystem_spec(cwd: '/'), NervesFirmwareSSH2.subsystem_spec(devpath: devpath)]}
    ])
  end

  defp find_iex_exs() do
    [".iex.exs", "~/.iex.exs", "/etc/iex.exs"]
    |> Enum.map(&Path.expand/1)
    |> Enum.find("", &File.regular?/1)
  end

  defp start_exec(cmd, user, peer) do
    spawn(fn -> exec(cmd, user, peer) end)
  end

  defp exec(cmd, _user, _peer) do
    try do
      {result, _env} = Code.eval_string(to_string(cmd))
      IO.inspect(result)
    catch
      kind, value ->
        IO.puts("** (#{kind}) #{inspect(value)}")
    end
  end
end
