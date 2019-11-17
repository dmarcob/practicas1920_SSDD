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
		IO.puts("POOL ACTIVO")
		workerspid = [Node.spawn(hd(workers),EscenarioTres,:worker,[self()])]
		IO.puts("inicializarPool:")
		IO.inspect workerspid
    poolWorkers(pid_m, workerspid, 0)

	end


def pedirWorkersPool(pid_pool, 1) do
	send({:pool,pid_pool}, {:peticion})
	pid = receive do
					{pidWorker} -> [pidWorker]
	pid
end

def pedirWorkersPool(pid_pool, n_replicas) when n_replicas > 1 do
	send({:pool,pid_pool}, {:peticion})
	pid = receive do
					{pidWorker} -> [pidWorker]
	pid ++ pedirWorkersPool(pid_pool, n_replicas - 1)
end

def send_task(pidWorkers, 1, num) do
	send(hd(pidWorkers), {:req, {self(), num}})
end

def send_task(pidWorkers, n_replicas, num) when n_replicas > 1 do
	send(hd(pidWorkers), {:req, {self(), num}})
	send_task(tl(pidWorkers), n_replicas - 1, num)
end

#vamos a forzar a recibir resultados de todas replicas que hemos realizado????
def receive_task(pid_pool, pid_workers, 1) do
	result = receive do
		 					{hd(pid_workers), num} -> #como hacer que pid haga matching con un pid en concreto de la lista de workers
														#el worker ya ha acabado de realizar la operacion, se le devuelve al pool
														#comprobar si hay un fallo de tipos, es decir, si se ha recibido un real en vez de un entero, en ese caso no anadir a la lista de result
														send(pid_pool, {pid, :fin))
														[num]
					 after
						 timeout ->  #comprobamos si la maquina a la que esperamos sigue viva -> latido? si sigue viva hacer spawn remoto con System.halt() y volver a arrancar
						 						# si no sigue viva volver a arrancar
														[]
	result
end

def receive_task(pid_pool, pid_workers, n_replicas, timeout) when n_replicas > 1 do
	result = receive do
		 					{hd(pid_workers), num} -> #como hacer que pid haga matching con un pid en concreto de la lista de workers
														#el worker ya ha acabado de realizar la operacion, se le devuelve al pool
														#comprobar si hay un fallo de tipos, es decir, si se ha recibido un real en vez de un entero, en ese caso no anadir a la lista de result
														send(pid_pool, {pid, :fin))
														[num]
					 after
						 timeout ->  #comprobamos si la maquina a la que esperamos sigue viva -> latido? si sigue viva hacer spawn remoto con System.halt() y volver a arrancar
						 						# si no sigue viva volver a arrancar
														[]
	result ++ receive_task(pid_pool, tl(pid_workers), n_replicas - 1, timeout)
end

def compare_results([last], res) do
	if last = res
		res
	else
		-1
end

def compare_results(results, res) do
	if hd(results) = res
		compare_results(tl(results), res)
	else
		-1
end

def deteccionFallos(pid_pool, n_replicas, timeout, num) do
	pid_workers = pedirWorkersPool(pid_pool, n_replicas)
	send_task(pid_workers, n_replicas, num)
	results = receive_task(pid_pool, pid_workers, n_replicas, timeout)
	correcto = compare_results(tl(results), hd(results))
	if correcto >=0
		correcto
	else
		deteccionFallos(pid_pool, n_replicas + 1, 1.25*timeout, num)
end

#///////////////NUEVO MASTER~PROXY//////////////////////////
def masterProxy(pid_pool) do
	receive do
	{pid,num}  ->
													IO.puts("master: PETICION RECIBIDA")
													result = deteccionFallos(pid_pool, n_replicas, timeout, num) #establecer timeout
													send(pid,{:result, result})
	end
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
