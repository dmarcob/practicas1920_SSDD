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
		#Node.set_cookie(:cookie123)
		Node.connect(:"servidor@127.0.0.1")
		Cliente.cliente({:server,:"servidor@127.0.0.1"},:tres)
		IO.puts("Cliente ya ha pedido")
	end


  def inicializarWorker(dirMaster) do
		#Node.connect(:"servidor@127.0.0.1")
		IO.puts("Worker conectado")
		Node.connect(dirMaster)
  end

	def primeroLibre(listaWorkers, procesosLibres)  do
		#COMPLETAR
		IO.puts("PRIMEROLIBRE")
		if elem(procesosLibres, 0) > 0 do
			IO.puts("primeroLibre: #{Enum.at(listaWorkers, 0)} PENEEE")
			procesosLibres = put_elem(procesosLibres, 0, elem(procesosLibres, 0) - 1)
			IO.puts("------------------------")
			IO.puts("primeroLibre: procesosLibres {#{elem(procesosLibres, 0)},#{elem(procesosLibres, 1)} }")
			IO.puts("------------------------")
			Enum.at(listaWorkers, 0)
	else if elem(procesosLibres, 1) > 0 do
		IO.puts("primeroLibre: #{ Enum.at(listaWorkers, 1)} Cacaaaa")
	  	procesosLibres = put_elem(procesosLibres, 1, elem(procesosLibres, 1) - 1)
		 Enum.at(listaWorkers, 1)
	 else -1
	   	  IO.puts("primeroLibre: NO HAY NINGÚN THREAD LIBRE")
	end
end
	end

  def recolectar(listaWorkers, procesosLibres, dirWorker) do
  	# COMPLETAR
		IO.puts("ACTUALIZAR")
		if dirWorker == Enum.at(listaWorkers, 0) do
			 IO.puts("recolectar: #{dirWorker} == #{ Enum.at(listaWorkers, 0)} ")
			 procesosLibres = put_elem(procesosLibres, 0, elem(procesosLibres, 0) + 1)
		else
				IO.puts("recolectar: #{dirWorker} != #{ Enum.at(listaWorkers, 0)}")
		   procesosLibres = put_elem(procesosLibres, 1, elem(procesosLibres, 1) + 1)
  end
end

  def worker(rango, op, pidCliente, pidMaster, dirWorker) do
		resultado = []
		t1 = Time.utc_now()
		if op == :fib do
			IO.puts("worker: :fib")
			resultado = Enum.map(rango, fn x -> Fib.fibonacci(x) end)
		else
			#op == :fib_tr
			IO.puts("worker: :fib_tr")
			resultado = Enum.map(rango, fn x -> Fib.fibonacci_tr(x) end)
		end
		t2 = Time.utc_now()
		tiempoAislado = Time.diff(t2,t1,:millisecond)
		IO.puts("#{tiempoAislado}ms")
		send(pidCliente,{:result,resultado,tiempoAislado})
		send(pidMaster, {:trabajado, dirWorker})
  end

	def inicializarMaster() do 																				#TODO: Ejecutar y terminar funciones primeroLibre y actualizar.
																																		#TODO: ERRORES: Devolver resultado
		IO.puts("MASTER ACTIVO")
    #registrarse
    Process.register(self(), :server)
    #añadir cookie
    #llamar a Servidor

		listaWorkers = [:"worker1@127.0.0.2", :"worker2@127.0.0.3"]
		procesosLibres = {4,4}
    master(listaWorkers, procesosLibres)
  end

  def master(listaWorkers, procesosLibres) do
		IO.puts("------------------------")
    IO.puts("master: procesosLibres {#{elem(procesosLibres, 0)},#{elem(procesosLibres, 1)} }")
		IO.puts("------------------------")
    receive do
		{pid,:fib,rango,num}  -> IO.puts("master: :  {pid,:fib,rango,num} ")
														dirWorker = primeroLibre(listaWorkers, procesosLibres)
														 Node.spawn(dirWorker, EscenarioTres,:worker, [rango,:fib, pid, self(), dirWorker])

		{pid,:fib_tr,rango,num} ->  IO.puts("master: :  {pid,:fib_tr,rango,num} ")
																dirWorker = primeroLibre(listaWorkers, procesosLibres)
														    Node.spawn(dirWorker, EscenarioTres,:worker, [rango, :fib_tr, pid, self(), dirWorker])

		{:trabajado, dirWorker} -> IO.puts("master: {:trabajado, dirWorker}")
															recolectar(listaWorkers, procesosLibres, dirWorker)
    end
    master(listaWorkers, procesosLibres)
  end
end
