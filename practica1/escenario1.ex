# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario1.ex
# FECHA: 27-09-2019
# DESCRIPCIÓN:

defmodule EscenarioUno do
	def inicializarCliente(pid_s) do
		#registrarse
		#Process.register(self(), :client)
		Node.set_cookie(:cookie123)
		#Conectar con maquina servidor
		Cliente.cliente({:server,pid_s},:uno)
		#IO.puts("cliente ya ha pedido")
	end



	def inicializarServidor() do
    #registrarse
		Node.set_cookie(:cookie123)
    Process.register(self(), :server)
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
																IO.puts("#{tiempoAislado}ms")
															send(pid,{:result,resultado, tiempoAislado})

    end
    servidor()
  end
end
