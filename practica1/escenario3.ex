# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario3.ex
# FECHA: 27-09-2019
# DESCRIPCIÓN:

defmodule EscenarioDos do
	def inicializarCliente() do
		#registrarse
		#Process.register(self(), :client)
		#añadir cookie

		#Conectar con maquina servidor
		Cliente.cliente({:server,:"servidor@127.0.0.1"},:dos)
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

  def servidor() do
    receive do
	  {pid,:fib,rango,1}  -> 	  t1 = Time.utc_now()
		                          resultado = Enum.map(rango, fn x -> Fib.fibonacci(x) end)
		                          t2 = Time.utc_now()
		                          #Medición aislada
		                          tiempoAislado = Time.diff(t2,t1,:millisecond)
															IO.puts("#{aislado},1")
															IO.puts("Servidor mandado-->")
															send(pid,{:result,resultado, tiempoAislado})

    {pid,:fib,rango,num} -> spawn( fn ->
                          		t1 = Time.utc_now()
                          		resultado = Enum.map(rango, fn x -> Fib.fibonacci(x) end)
                          		t2 = Time.utc_now()
                          		#Medición aislada
                          		aislado = Time.diff(t2,t1,:millisecond)
															IO.puts(aislado) end)



    end
    servidor()
  end
end
