defmodule Crow.Worker do
  @moduledoc false
  @version Mix.Project.config()[:version]

  require Logger
  use GenServer

  def start_link([[conn]]) do
    GenServer.start_link(__MODULE__, conn)
  end

  @doc false
  @impl true
  def init(conn) do
    {:ok, conn, {:continue, :send_banner}}
  end

  @doc false
  @impl true
  def handle_continue(:send_banner, conn) do
    {:ok, {ip, port}} = :inet.peername(conn)
    {:ok, hostname} = :inet.gethostname()
    :ok = :gen_tcp.send(conn, '# crow node at #{hostname}\n')
    Logger.info("CONNECT TCP peer #{:inet.ntoa(ip)}:#{port}")
    {:noreply, conn}
  end

  @doc false
  @impl true
  def handle_info({:tcp, sock, "cap\n"}, state) do
    :ok = :gen_tcp.send(sock, 'cap\n')
    {:noreply, state}
  end

  def handle_info({:tcp, sock, "nodes\n"}, state) do
    {:ok, hostname} = :inet.gethostname()
    :ok = :gen_tcp.send(sock, '#{hostname}\n.\n')
    {:noreply, state}
  end

  def handle_info({:tcp, sock, "version\n"}, state) do
    :ok = :gen_tcp.send(sock, 'crow node version #{@version}\n')
    {:noreply, state}
  end

  def handle_info({:tcp, sock, "quit\n"}, state) do
    :ok = :gen_tcp.close(sock)
    Logger.debug("Closed socket due to user command.")
    {:stop, :normal, state}
  end

  def handle_info({:tcp, sock, _message}, state) do
    :ok = :gen_tcp.send(sock, '# unknown command. try cap, nodes, version, quit\n')
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _sock}, state) do
    Logger.info("Peer disconnected.")
    {:stop, :normal, state}
  end
end