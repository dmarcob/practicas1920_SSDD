# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario3.ex
# FECHA: 17-10-2019
# DESCRIPCIÓN: Código de inicialiación del cliente, pool de recursos, master y worker.
#						   Código del master, worker y pool de recursos.


defmodule EscenarioTres do
	@moduledoc """
	Arquitectura cliente-servidor concurrente
	"""
	def inicializarCliente(pid_m) do
		#añadir cookie
		Node.set_cookie(:cookie123)
		#Conectarse al master
		Node.connect(pid_m)
		Cliente.cliente({:server,pid_m},:tres)
	end

	def inicializarMaster(pid_pool) do
    #añadir cookie
		Node.set_cookie(:cookie123)
		#Registrar el proceso master
    Process.register(self(), :server)
    #llamar a Servidor
		IO.puts("MASTER ACTIVO")
    master(pid_pool,[])
  end

	def inicializarPool(pid_m, workers) do
		#registrarse
    Process.register(self(), :pool)
		#añadir cookie
		Node.set_cookie(:cookie123)
		#Conectar con maquina master
		Node.connect(pid_m)
		IO.puts("inicializarPool: POOL ACTIVO")
		IO.puts("InicializarPool: ******** workersAntes: ")
		IO.inspect workers
		IO.puts("********************** ")
		worker1 = Enum.at(workers, 0)
		worker2 = Enum.at(workers, 1)

		worker1pid = [Node.spawn(worker1,EscenarioTres,:worker,[self()])] ++ [Node.spawn(worker1,EscenarioTres,:worker,[self()])] ++
									 [Node.spawn(worker1,EscenarioTres,:worker,[self()])]++ [Node.spawn(worker1,EscenarioTres,:worker,[self()])]

		worker2pid = [Node.spawn(worker2,EscenarioTres,:worker,[self()])] ++ [Node.spawn(worker2,EscenarioTres,:worker,[self()])] ++
							 		 [Node.spawn(worker2,EscenarioTres,:worker,[self()])]++ [Node.spawn(worker2,EscenarioTres,:worker,[self()])]

		IO.puts("******** workersDespues: ")
		IO.inspect workers
		IO.puts("*********workersPid despues ")
		IO.inspect worker1pid ++ worker2pid
		IO.puts("*************************** ")
    poolWorkers(pid_m, worker1pid ++ worker2pid, 0)

	end

	def inicializarWorker(pid_m, pid_pool) do
    #añadir cookie
		Node.set_cookie(:cookie123)
		#conectar con MASTER
		Node.connect(pid_m)
    #llamar a Servidor
		IO.puts("WORKER ACTIVO")
    worker(pid_pool)
  end


  #//////////////////////////////////////////////
  #///////////////////MASTER/////////////////////
  #//////////////////////////////////////////////
  def master(pid_pool,listaPendientes) do
    receive do
	  {pid,op,rango,num}  ->
														IO.puts("master: PETICION CLIENTE RECIBIDA")
														IO.inspect listaPendientes
														IO.puts("pid_pool: #{pid_pool}")
        										send({:pool,pid_pool}, {self(),:peticion})
														#AGNADE A LA LISTA DE ESPERA LA PETICION HASTA QUE RECIBA UN WORKER PARA MANDARLA
														master(pid_pool, listaPendientes ++ [{pid,op,rango,num}])


		{pidWorker} ->
														#recibe worker
														IO.puts("master: RECIBO MASTER DISPONIBLE")
														send(pidWorker, hd(listaPendientes))
														master(pid_pool, tl(listaPendientes))
    end
  end

#//////////////////////////////////////////////
#///////////////////WORKER/////////////////////
#//////////////////////////////////////////////
  def worker(pid_pool) do
	  receive do
	  {pid,:fib,rango,1}  ->
															IO.puts("worker: trabajo :fib")
															t1 = Time.utc_now()
	                            resultado = Enum.map(rango, fn x -> Fib.fibonacci(x) end)
															t2 = Time.utc_now()
															tiempoAislado = Time.diff(t2,t1,:millisecond)
															IO.puts("#{tiempoAislado}ms")
	                            #//se comunica al pool de workers de que hemos terminado
	                            send(pid_pool, {self(),:fin})
															send(pid,{:result,resultado,tiempoAislado})

		{pid,:fib,rango,num}  ->
		                    			IO.puts("worker: trabajo :fib")
															t1 = Time.utc_now()
		                          resultado = Enum.map(rango, fn x -> Fib.fibonacci(x) end)
															t2 = Time.utc_now()
															tiempoAislado = Time.diff(t2,t1,:millisecond)
															IO.puts("#{tiempoAislado}ms")
		                          #//se comunica al pool de workers de que hemos terminado
		                          send(pid_pool, {self(),:fin})
															send(pid,{:result,resultado,tiempoAislado})

	  {pid,:fib_tr,rango,1} -> IO.puts("worker: trabajo :fib_tr")
															t1 = Time.utc_now()
															resultado = Enum.map(rango, fn x -> Fib.fibonacci_tr(x) end)
															t2 = Time.utc_now()
															tiempoAislado = Time.diff(t2,t1,:millisecond)
															IO.puts("#{tiempoAislado}ms")
															#//se comunica al pool de workers de que hemos terminado
															send(pid_pool, {self(),:fin})
															send(pid,{:result,resultado,tiempoAislado})

	  {pid,:fib_tr,rango,num} -> IO.puts("worker: trabajo :fib_tr")
															t1 = Time.utc_now()
															resultado = Enum.map(rango, fn x -> Fib.fibonacci_tr(x) end)
															t2 = Time.utc_now()
															tiempoAislado = Time.diff(t2,t1,:millisecond)
													  	IO.puts("#{tiempoAislado}ms")
	                            #//se comunica al pool de workers de que hemos terminado
	                            send(pid_pool, {self(),:fin})
	  end
    worker(pid_pool)
  end

  #//////////////////////////////////////////////
  #///////////////////POOL/////////////////////
  #//////////////////////////////////////////////
  def poolWorkers(pid_m, workers, enEspera) do
		IO.puts("************************************")
		IO.puts("poolWorkers: enEspera= #{enEspera}")
		IO.puts("************************************")
    IO.inspect workers
    receive do
    {pid_m, :peticion}  -> IO.puts("poolWorkers: PETICION MASTER RECIBIDA")
                  	if length(workers)>0 do
											IO.puts("poolWorkers: 1IF longitud > 0")
                  		send(pid_m, {hd(workers)})
											poolWorkers(pid_m, tl(workers), enEspera)
										else
											IO.puts("poolWorkers: 1ELSE longitud == 0")
											poolWorkers(pid_m, workers, enEspera+1)
										end

    {pid_w, :fin} ->
										IO.puts("poolWorkers: WORKER HA TERMINADO TAREA")
                  	if enEspera>0 do
											IO.puts("poolWorkers: 2IF longitud > 0")
											send(pid_m, {pid_w})
											poolWorkers(pid_m, workers, enEspera-1)
										else
											IO.puts("poolWorkers: 2ELSE longitud == 0")
											poolWorkers(pid_m, workers ++ [pid_w], enEspera)
										end
    end
  end

end
