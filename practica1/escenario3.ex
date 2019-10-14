# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario3.ex
# FECHA: 27-09-2019
# DESCRIPCIÓN:

defmodule EscenarioTres do
	def inicializarCliente() do
		#registrarse
		#Process.register(self(), :client)
		#añadir cookie

		#Conectar con maquina servidor
		Cliente.cliente({:server,:"servidor@127.0.0.1"},:tres)
		IO.puts("cliente ya ha pedido")
	end



	def inicializarServidor() do
    #registrarse
    Process.register(self(), :server)
    #añadir cookie
    #llamar a Servidor
		IO.puts("SERVIDOR ACTIVO")
    servidor()
  end

  def master() do

		#Número de workers y nucleos disponible por worker.
		workers = [:"node1@127.0.0.1": 4, :"node2@127.0.0.1": 4]

    receive do
	  {pid,:fib,rango,num}  ->
															asignar()


															t1 = Time.utc_now()
		                          resultado = Enum.map(rango, fn x -> Fib.fibonacci(x) end)
		                          t2 = Time.utc_now()
		                          #Medición aislada
		                          tiempoAislado = Time.diff(t2,t1,:millisecond)
															IO.puts("#{tiempoAislado}ms")
															IO.puts("Servidor mandado-->")
															send(pid,{:result,resultado, tiempoAislado})
    end
    master()
  end
end
