# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario1.ex
# FECHA: 27-09-2019
# DESCRIPCIÓN:

defmodule EscenarioUno do
	def inicializarCliente() do
		#registrarse
		#Process.register(self(), :client)
		#añadir cookie

		#Conectar con maquina servidor
		Cliente.cliente({:server,:"servidor@127.0.0.1"},:uno)
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
		                          aislado = Time.diff(t2,t1,:millisecond)
															IO.puts(aislado)
															send(pid,{:result,resultado})

    {pid,:fib,rango,num} ->
                          t1 = Time.utc_now()
                          resultado = Enum.map(rango, fn x -> Fib.fibonacci(x) end)
                          t2 = Time.utc_now()
                          #Medición aislada
                          aislado = Time.diff(t2,t1,:millisecond)
													IO.puts(aislado)

    end
    servidor()
  end
end
