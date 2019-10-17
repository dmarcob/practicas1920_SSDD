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
		Node.connect(pid_m)
		Cliente.cliente({:server,pid_m},:tres)
		IO.puts("cliente inicializado...")
	end

	def inicializarMaster(pid_pool) do
    #registrarse
    Process.register(self(), :server)
    #añadir cookie
    #llamar a Servidor
		IO.puts("MASTER ACTIVO")
    master(pid_pool,[])
  end

	def inicializarWorkers([], workerspid,pid_pool) do

	end

	def inicializarWorkers(workers, workerspid, pid_pool) do
		#lanzamos 4 threads remotos
		pid1 = Node.spawn(hd(workers),EscenarioTres,:worker,[pid_pool])
		pid2 = Node.spawn(hd(workers),EscenarioTres,:worker,[pid_pool])
		pid3 = Node.spawn(hd(workers),EscenarioTres,:worker,[pid_pool])
		pid4 = Node.spawn(hd(workers),EscenarioTres,:worker,[pid_pool])
		IO.puts("#{Node.spawn(hd(workers),EscenarioTres,:worker,[pid_pool])}")
		IO.puts("#{pid2}")
		IO.puts("#{pid3}")
		IO.puts("#{pid4}")
		inicializarWorkers(tl(workers), workerspid ++ [pid1] ++ [pid2] ++ [pid3] ++ [pid4], pid_pool)
	end

	def inicializarPool(pid_m, workers) do
		#registrarse
    Process.register(self(), :pool)
		#añadir cookie
		#Conectar con maquina master
		Node.connect(pid_m)
    #llamar a Servidor
		IO.puts("POOL ACTIVO")
		#declaracion de la informacion respectiva al pool de recursos
		#,:"worker3@127.0.0.2",:"worker4@127.0.0.2", :"worker5@127.0.0.3",:"worker6@127.0.0.3",:"worker7@127.0.0.3",:"worker8@127.0.0.3"
		workerspid = []
		IO.puts("inicializando workers...")
		inicializarWorkers(workers, workerspid, self())
		IO.inspect workerspid
		IO.puts("inicializando pool...")
    poolWorkers(pid_m, workerspid, 0)

	end

	def inicializarWorker(pid_m, pid_pool) do
    #añadir cookie
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
    receive do
	  {pid,op,rango,num}  ->

				#//SEND PETICION DE WORKER A POOL DE WORKERS
				IO.puts("")
        send({:pool,pid_pool}, {:peticion})
				#AGNADE A LA LISTA DE ESPERA LA PETICION HASTA QUE RECIBA UN WORKER PARA MANDARLA
				master(pid_pool, listaPendientes ++ [{pid,op,rango,num}])
		{pidWorker} ->
				#recibe worker
				send(pidWorker, hd(listaPendientes))
				master(pid_pool, tl(listaPendientes))
    end
  end

#//////////////////////////////////////////////
#///////////////////WORKER/////////////////////
#//////////////////////////////////////////////
  def worker(pid_pool) do
	  receive do
	  {pid,:fib,rango,num}  -> 	  spawn( fn ->
	                            resultado = Enum.map(rango, fn x -> Fib.fibonacci(x) end)
															IO.inspect resultado
	                            #//se comunica al pool de workers de que hemos terminado
	                            send({:pool,pid_pool}, {self(),:fin}) end)

	  {pid,:fib_tr,rango,num} -> spawn( fn ->
	                            resultado = Enum.map(rango, fn x -> Fib.fibonacci(x) end)
															IO.inspect resultado
	                            #//se comunica al pool de workers de que hemos terminado
	                            send({:pool,pid_pool}, {self(),:fin}) end)
	  end
    worker(pid_pool)
  end

  #//////////////////////////////////////////////
  #///////////////////POOL/////////////////////
  #//////////////////////////////////////////////
  def poolWorkers(pid_m, workers, enEspera) do

    receive do
    {:peticion}  ->
                  if length(workers)>0 do
                  	send({:server,pid_m}, {hd(workers)})
										poolWorkers(pid_m, tl(workers), enEspera)
									else
										poolWorkers(pid_m, workers, enEspera-1)
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
