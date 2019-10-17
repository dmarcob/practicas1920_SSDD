# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario2.ex
# FECHA: 27-09-2019
# DESCRIPCIÓN:

defmodule EscenarioDos do
	def inicializarCliente(pid_s) do
		#registrarse
		#Process.register(self(), :client)
		#añadir cookie
		#Conectar con maquina servidor
		Node.set_cookie(:cookie123)
		Cliente.cliente({:server,pid_s},:dos)
		IO.puts("cliente ya ha pedido")
	end



	def inicializarServidor() do
    #registrarse
    Process.register(self(), :server)
    #añadir cookie
			Node.set_cookie(:cookie123)
    #llamar a Servidor
		IO.puts("SERVIDOR ACTIVO")
    servidor()
  end

  def servidor() do
    receive do
	  {pid,:fib,rango,1}  -> 	  spawn( fn ->
															t1 = Time.utc_now()
		                          resultado = Enum.map(rango, fn x -> Fib.fibonacci(x) end)
		                          t2 = Time.utc_now()
		                          #Medición aislada
		                          tiempoAislado = Time.diff(t2,t1,:millisecond)
															IO.puts("#{tiempoAislado}ms")
															send(pid,{:result,resultado,tiempoAislado}) end)

    {pid,:fib,rango,num} -> spawn( fn ->
                          		t1 = Time.utc_now()
                          		resultado = Enum.map(rango, fn x -> Fib.fibonacci(x) end)
                          		t2 = Time.utc_now()
                          		#Medición aislada
                          		tiempoAislado = Time.diff(t2,t1,:millisecond)
															IO.puts("#{tiempoAislado}ms") end)



    end
    servidor()
  end
end
