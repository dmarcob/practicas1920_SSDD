# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario3.ex
# FECHA: 27-09-2019
# DESCRIPCIÓN:

#agnadir elementos a lista con [] ++ []
#sacar primero de la lista hd([])
#quitar primero de la lista [] = tl([])
#tamagno de una lista length([])

defmodule EscenarioTres do
	def inicializarCliente(pid_m) do
		#añadir cookie
		#Conectar con maquina master
			Node.set_cookie(:cookie123)
		Node.connect(pid_m)
		Cliente.cliente({:server,pid_m},:tres)
		IO.puts("cliente inicializado...")
	end

	def inicializarMaster(pid_pool) do
    #registrarse
			Node.set_cookie(:cookie123)
    Process.register(self(), :server)
    #añadir cookie
    #llamar a Servidor
		IO.puts("MASTER ACTIVO")
    master(pid_pool,[])
  end

	def inicializarPool(pid_m, workers) do
		#registrarse
    Process.register(self(), :pool)
		#añadir cookie
		#Conectar con maquina master
		Node.set_cookie(:cookie123)
		Node.connect(pid_m)
    #llamar a Servidor
		IO.puts("POOL ACTIVO")
		#declaracion de la informacion respectiva al pool de recursos
		#,:"worker3@127.0.0.2",:"worker4@127.0.0.2", :"worker5@127.0.0.3",:"worker6@127.0.0.3",:"worker7@127.0.0.3",:"worker8@127.0.0.3"
		workerspid = [Node.spawn(hd(workers),EscenarioTres,:worker,[self()])]
		IO.puts("inicializarPool:")
		IO.inspect workerspid
    poolWorkers(pid_m, workerspid, 0)

	end

	def inicializarWorker(pid_m, pid_pool) do
    #añadir cookie
		Node.set_cookie(:cookie123)
		#conectar con MASTER
		Node.connect(pid_m)
    #llamar a Servidor
		IO.puts("WORKER ACTIVO")
    #worker(pid_pool)
  end


  #//////////////////////////////////////////////
  #///////////////////MASTER/////////////////////
  #//////////////////////////////////////////////
  def master(pid_pool,listaPendientes) do
    #RECIBE 1 Fibonacci a realizar
		IO.puts("-------------------------------------------")
		#IO.puts("master: listaPendientes= #{listaPendientes}")
		IO.puts("-------------------------------------------")
    receive do
	  {pid,op,rango,num}  ->
			#	IO.puts("master: RECIBO PETICION CLIENTE #{pid} #{op} #{rango} #{num}")
				#//SEND PETICION DE WORKER A POOL DE WORKERS
				#IO.puts("master: PIDO MASTER A POOL #{pid_pool}")
					IO.puts("master: PETICION RECIBIDA")
        send({:pool,pid_pool}, {:peticion})
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
	                            send({:pool,pid_pool}, {self(),:fin})
															send(pid,{:result,resultado,tiempoAislado})

		{pid,:fib,rango,num}  ->
		                    			IO.puts("worker: trabajo :fib")
															t1 = Time.utc_now()
		                          resultado = Enum.map(rango, fn x -> Fib.fibonacci(x) end)
															t2 = Time.utc_now()
															tiempoAislado = Time.diff(t2,t1,:millisecond)
															IO.puts("#{tiempoAislado}ms")
		                          #//se comunica al pool de workers de que hemos terminado
		                          send({:pool,pid_pool}, {self(),:fin})
															send(pid,{:result,resultado,tiempoAislado})

	  {pid,:fib_tr,rango,1} -> IO.puts("worker: trabajo :fib_tr")
															t1 = Time.utc_now()
															resultado = Enum.map(rango, fn x -> Fib.fibonacci_tr(x) end)
															t2 = Time.utc_now()
															tiempoAislado = Time.diff(t2,t1,:millisecond)
															IO.puts("#{tiempoAislado}ms")
															#//se comunica al pool de workers de que hemos terminado
															send({:pool,pid_pool}, {self(),:fin})
															send(pid,{:result,resultado,tiempoAislado})

	  {pid,:fib_tr,rango,num} -> IO.puts("worker: trabajo :fib_tr")
															t1 = Time.utc_now()
															resultado = Enum.map(rango, fn x -> Fib.fibonacci_tr(x) end)
															t2 = Time.utc_now()
															tiempoAislado = Time.diff(t2,t1,:millisecond)
														IO.puts("#{tiempoAislado}ms")
	                            #//se comunica al pool de workers de que hemos terminado
	                            send({:pool,pid_pool}, {self(),:fin})
	  end
    worker(pid_pool)
  end

  #//////////////////////////////////////////////
  #///////////////////POOL/////////////////////
  #//////////////////////////////////////////////
  def poolWorkers(pid_m, workers, enEspera) do
		IO.puts("************************************")
		IO.puts("poolWorkers: enEspera= #{enEspera}")
		#IO.puts("poolWorkers: workers= #{workers}")
     IO.inspect workers
    receive do
    {:peticion}  ->
                  if length(workers)>0 do
                  	send({:server,pid_m}, {hd(workers)})
										poolWorkers(pid_m, tl(workers), enEspera)
									else
										poolWorkers(pid_m, workers, enEspera+1)
									end

    {pid_w, :fin} ->
                  if enEspera>0 do
										send({:server,pid_m}, {pid_w})
										poolWorkers(pid_m, workers, enEspera-1)
									else
										poolWorkers(pid_m, workers ++ [pid_w], enEspera)
									end

    end
  end

end
