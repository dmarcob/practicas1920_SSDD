# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: cliente.exs
# FECHA: 18-10-2019
# DESCRIPCIÓN: Código del cliente: inicialización + carga


defmodule Cliente do

	def init(server_dir) do
	#	Node.set_cookie(:cookie123)
		Node.connect(server_dir)
		IO.puts("CLIENTE ACTIVO")
		genera_workload({:server, server_dir})
	end

  defp launch(pid, 1) do
		t_inicial = Time.utc_now()
		pidRecibir = spawn( fn ->
		#send(pid, {self(), 1500})
			receive do
				{:result, l} -> l
												t_final = Time.utc_now()
												tiempoTotal = Time.diff(t_final,t_inicial,:millisecond)
												IO.puts("Tiempo total tarea: #{tiempoTotal}ms")
												#Comprobamos que se cumple el requisito de tiempo de respuesta
												if tiempoTotal < 2500 do
												IO.puts("OK: Se cumple tiempo de respuesta")
												else
												IO.puts("VIOLACION: Tiempo de respuesta")
												end
												IO.puts("--------------------------------------")
			#end
			 end end)
			 send(pid, {pidRecibir, 1500})
	end


  defp launch(pid, n) when n != 1 do
  	number = if rem(n, 3) == 0, do: 100, else: 36
		send(pid, {self(), :random.uniform(number)})
		launch(pid, n - 1)
  end

  def genera_workload(server_pid) do
		launch(server_pid, 6 + :random.uniform(2))													#cambiaar
		Process.sleep(2000 + :random.uniform(200))
  	genera_workload(server_pid)
  end

end
defmodule Stop do
	def todo(num, worker_dir) when num > 1 do
		stop(String.to_atom("worker" <> "#{num}@" <> worker_dir))
		todo(num - 1, worker_dir)
	end
	def todo(1, worker_dir) do
		stop(String.to_atom("worker" <> "#{1}@" <> worker_dir))
	end
	defp stop(nodo) do
        # :rpc.block_call(nodo, :init, :stop, [])   estilo kill -15
				Node.connect(nodo)
        Node.spawn(nodo, System, :halt, []) # estilo kill -9, ahora nos va

        # tambien habría que eliminar epmd,
        # en el script shell externo
	end
end
