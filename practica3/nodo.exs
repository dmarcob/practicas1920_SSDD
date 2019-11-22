defmodule Nodo do
  def encender(nodo) do
    #LOCAL
		IO.inspect nodo
		nodo = String.Chars.to_string(nodo)
		IO.puts("despues")
		IO.inspect nodo
			System.cmd("iex", ["--name","#{nodo}", "--erl", "-detached"])
		Node.connect(String.to_atom(nodo))

    #REMOTO
    #
    # nodo = to_string(nodo)
    # ip = elem(String.split(nodo,"@"), 1)
    # IO.puts("---> #{ip}")
    # System.cmd("ssh", [
    #   "a755232@#{ip}",
    #   "iex --name #{nodo} --cookie cookie123",
    #   "--erl  \'-kernel_inet_dist_listen_min 32000\'",
    #   "--erl  \'-kernel_inet_dist_listen_max 32049\'",
    #   "--erl -detached"
    # ])
	end

  def apagarTodo(lista) do
    Enum.each(lista, fn x -> Node.spawn(x, System, :halt, []) end)
  end


end
