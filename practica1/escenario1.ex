# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario1.ex
# FECHA: 27-09-2019
# DESCRIPCIÓN: Código de inicialización de cliente y servidor, escenario uno.
#							 Código del servidor secuencial

defmodule EscenarioUno do
	@moduledoc """
	Arwuitectura cliente-servidor secuencial
	"""
	def inicializarCliente(pid_s) do
		#Añadir cookie
		Node.set_cookie(:cookie123)
		#Conectar con maquina servidor
		Cliente.cliente({:server,pid_s},:uno)
	end

	def inicializarServidor() do
    #Añadir cookie
		Node.set_cookie(:cookie123)
		#Registrar el proceso servidor
    Process.register(self(), :server)
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
															#Envía resultado a cliente
															send(pid,{:result,resultado, tiempoAislado})

    end
    servidor()
  end
end
