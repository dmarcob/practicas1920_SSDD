defmodule Nodo do
  def encender(nodo) do
    #LOCAL
	#	nodo = String.Chars.to_string(nodo)
	#		System.cmd("iex", ["--name","#{nodo}","--cookie","cookie123", "--erl", "-detached"])
	#	Node.connect(String.to_atom(nodo))

    #REMOTO
     nodo = Atom.to_string(nodo)
     ip = tl(String.split(nodo,"@"))
     System.cmd("ssh", [
       "a755232@#{ip}",
       "iex --name #{nodo} --cookie cookie123",
       "--erl  \'-kernel_inet_dist_listen_min 32000\'",
       "--erl  \'-kernel_inet_dist_listen_max 32049\'",
       "--erl -detached",
       "servidor_jm.exs"
     ])
	end

  def esperarNodoOperativo(nodo) do
      Process.sleep(50)
      if Node.ping(nodo) == :pang do
         esperarNodoOperativo(nodo)
      end
  end
  def apagarTodo(lista) do
    Enum.each(lista, fn x -> Node.spawn(x, System, :halt, []) end)
  end


end
