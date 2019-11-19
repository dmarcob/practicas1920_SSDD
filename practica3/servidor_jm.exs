# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario3.ex
# FECHA: 17-10-2019
# DESCRIPCIÓN: Código del servidor: master + pool + worker + detector fallos + fibonacci





	#//////////////////////////////////////////////
	#///////////////////DETECTOR FALLOS////////////
	#//////////////////////////////////////////////

defmodule DetectorFallos do
	def init(detector_id, pool_dir) do
		Process.register(self(), :detector)
		detectorFallos( detector_dir, pool_dir, n_replicas, timeout, num)
	end

	def pedirWorkersPool(pid_pool, 1) do
		send({:pool,pid_pool}, {:peticion})
		pid = receive do
						{pidWorker, n} -> [{pidWorker, n}]
	  pid
  end

def pedirWorkersPool(pid_pool, n_replicas) when n_replicas > 1 do
	send({:pool,pid_pool}, {:peticion})
	pid = receive do
					{pidWorker, n} -> [{pidWorker, n}]
	pid ++ pedirWorkersPool(pid_pool, n_replicas - 1)
end

# def send_task(pidWorkers, 1, num) do
# 	send(hd(pidWorkers), {:req, {self(), num}})
# end
#
# def send_task(pidWorkers, n_replicas, num) when n_replicas > 1 do
# 	send(hd(pidWorkers), {:req, {self(), num}})
# 	send_task(tl(pidWorkers), n_replicas - 1, num)
# end

#no haria falta usar solucionar_error, en recieve_task ya se manda al pool lo que tiene que hacer con la maquina en cada caso de error
def solucionar_error(pid_pool, []) do
end

def solucionar_error(pid_pool, respuesta_valida) do
	if elem(hd(respuesta_valida), 1) == -1 do
		#avisar al pool para que apague y reinicie el worker
		send(pid_pool,{elem(hd(respuesta_valida), 0),:reset})
		#Node.spawn(hd(pid_workers),System,:halt,[]) # se hace asi el spawn remoto?
		#System.halt(hd(pid_workers))
		#Encender sistema y devolver worker a pool
		#send(pid_pool,{{Node.spawn(hd(pid_workers), Worker,:init,[]), 0}, :fin})
	else id hd(resultados) == -2
		#avisar al pool para que encienda el worker
		send(pid_pool,{elem(hd(respuesta_valida), 0),:turnon})
		#Encender sistema
		#send(pid_pool,{{Node.spawn(hd(pid_workers), Worker,:init,[]), 0}, :fin})
	end
	solucionar_error(pid_pool, tl(respuesta_valida))
end

def detect(pid_worker,detector_dir, pool_dir, timeout, num) do
	send(pid_worker, {:req, {self(), num}})
	resultado = receive do
		 						{pid_w, num} ->
														if is_float(num) do
															#Fallo response, necesita reiniciar
															send(pid_pool, {pid_w, :reset})
															-1
														else
															send(pid_pool, {{pid_w, n++}, :fin})
															num
					 			after
						  	timeout ->  #comprobamos si la maquina a la que esperamos sigue viva -> latido? si sigue viva hacer spawn remoto con System.halt() y volver a arrancar
						 						# si no sigue viva volver a arrancar
													   send(pid_w, :latido)
														 error = receive do
														 				 			{:ok} -> #Fallo omission / timing, necesita reiniciar
																									 send(pid_pool, {pid_w, :reset})
																									 -1
																	 		after
																		 			50 ->  #Fallo crash, necesita encenderse
																								 send(pid_pool, {pid_w, :turnon})
																								 -2
														 end
													   error
								end end)
	#solucionar_error(pid_pool, pid_workers, resultados)
	send ({:detector, detector_dir},{pid_worker,resultado})
end

def receive_results(num_workers) do when num_workers > 0
	respuesta = receive do
							{pid_worker, resultado} -> {pid_worker, resultado}
	end
	[respuesta] ++ receive:results(num_workers - 1)
end

def detectorFallos(detector_dir, pid_pool, n_replicas, timeout, num) do
	pid_workers = pedirWorkersPool(pid_pool, n_replicas)
	#send_task(pid_workers, num)
	#resultados = receive_task(pid_pool, pid_workers, timeout)
	Enum.each(pid_workers, spawn fn -> detect(x,detector_dir, pid_pool, timeout, num) end end)
	respuesta_valida = receive_results(pid_workers.length())
	solucionar_error(pid_pool,respuesta_valida)
	respuesta_valida = Enum.uniq(Enum.filter(Enum.map(respuesta_valida, fn x -> elem(x,1) end), fn x -> x > 0 end)) #Filtro los resultados válidos y los comparo
	if respuesta_valida.length() == 1 do
		 respuesta_valida
	else
		detectorFallos(pid_pool, n_replicas + 1, 1.25*timeout, num) #incrementamos timeout o no?
	end
end


#//////////////////////////////////////////////
#///////////////////MASTER~PROXY///////////////
#//////////////////////////////////////////////

defmodule MasterProxy do

	def initMaster(pool_dir, detector_id) do
		Process.register(self(), :server)
		Node.set_cookie(:cookie123)
		IO.puts("MASTER ACTIVO")
		spawn(fn -> DetectorFallos.init(detector_id, pool_dir) end)
		masterProxy(pool_dir)
	end

 def masterProxy(pool_dir) do
	receive do
	{pid,num}  ->
													IO.puts("master: PETICION RECIBIDA")
													result = detectorFallos(pool_dir, n_replicas, timeout, num) #establecer timeout y numero de replicas iniciales
													send(pid,{:result, result})
	end
 end
end


  #////////////////////////////////////////////
  #///////////////////POOL/////////////////////
  #////////////////////////////////////////////

defmodule Pool do

def initPool(detector_dir, workers_dir) do
    Process.register(self(), :pool)
		Node.set_cookie(:cookie123)
		Node.connect(master_dir)
		Enum.each(workers_dir, fn(x) -> Node.connect(x) end) #onectamos workers
		workerspid = Enum.map(workers_dir, fn(x) -> Node.spawn(x,Worker,:init,[])end) #Levantamos workers
		IO.puts("POOL ACTIVO")
    poolWorkers(detector_dir, workerspid, 0)
end

def poolWorkers(detector_pid, workers, enEspera) do
	IO.puts("************************************")
	IO.puts("poolWorkers: enEspera= #{enEspera}")
	IO.puts("************************************")
	IO.inspect workers
	receive do
	{detector_pid, :peticion}  ->
									if length(workers)>0 do
										send(detector_pid, {hd(workers)})
										poolWorkers(detector_pid, tl(workers), enEspera)
									else
										poolWorkers(detector_pid, workers, enEspera+1)
									end

	{{pid_w, n}, :fin} ->
									if n = 6 do
										#parar maquina
										Node.spawn(hd(pid_workers),System,:halt,[]) # se hace asi el spawn remoto?
										#Encender sistema y devolver worker a pool
										if enEspera>0 do
											send(detector_pid, {Node.spawn(hd(pid_workers), Worker,:init,[]), 0})
											poolWorkers(detector_pid, workers, enEspera-1)
										else
											poolWorkers(detector_pid, workers ++ [{Node.spawn(hd(pid_workers), Worker,:init,[]), 0}], enEspera)
										end
									else if enEspera>0 do
										send(detector_pid, {pid_w, n})
										poolWorkers(detector_pid, workers, enEspera-1)
									else
										poolWorkers(detector_pid, workers ++ [{pid_w, n}], enEspera)
									end
  {pid_w, :reset} ->
									#parar maquina
									Node.spawn(pid_w, System, :halt,[]) # se hace asi el spawn remoto?
									#Encender sistema
									if enEspera>0 do
										send(detector_pid, {Node.spawn(pid_w, Worker, :init,[]), 0})
										poolWorkers(detector_pid, workers, enEspera-1)
									else
										poolWorkers(detector_pid, workers ++ [{Node.spawn(pid_w, Worker, :init,[]), 0}], enEspera)
									end
	{pid_w, :turnon} ->
									#Encender sistema
									if enEspera>0 do
										send(detector_pid, {Node.spawn(pid_w, Worker, :init,[]), 0})
										poolWorkers(detector_pid, workers, enEspera-1)
									else
										poolWorkers(detector_pid, workers ++ [{Node.spawn(pid_w, Worker, :init,[]), 0}], enEspera)
									end
  end
end


#////////////////////////////////////////////
#///////////////////WORKER/////////////////////
#////////////////////////////////////////////

defmodule Worker do

	def init() do
		Process.sleep(10000)
		spawn(fn -> latido() end)
		worker(&Fib.fibonacci_tr/1, 1, :rand.uniform(10))
	end

	def latido() do
		receive do
			{pid, :latido} -> send(pid, {:ok})
		end
	end

	defp worker(op, service_count, k) do
		[new_op, omission] = if rem(service_count, k) == 0 do
			behavioural_probability = :rand.uniform(100)
			cond do
				behavioural_probability >= 90 ->
					[&System.halt/1, false]
				behavioural_probability >= 70 ->
					[&Fib.fibonacci/1, false]
				behavioural_probability >=  50 ->
					[&Fib.of/1, false]
				behavioural_probability >=  30 ->
					[&Fib.fibonacci_tr/1, true]
				true	->
					[&Fib.fibonacci_tr/1, false]
			end
		else
			[op, false]
		end
		receive do
			{:req, {pid, args}} -> if not omission, do: send(pid, op.(args))
		end
		worker(new_op, rem(service_count + 1, k), k)
	end
end

defmodule Fib do
	def fibonacci(0), do: 0
	def fibonacci(1), do: 1
	def fibonacci(n) when n >= 2 do
		fibonacci(n - 2) + fibonacci(n - 1)
	end
	def fibonacci_tr(n), do: fibonacci_tr(n, 0, 1)
	defp fibonacci_tr(0, _acc1, _acc2), do: 0
	defp fibonacci_tr(1, _acc1, acc2), do: acc2
	defp fibonacci_tr(n, acc1, acc2) do
		fibonacci_tr(n - 1, acc2, acc1 + acc2)
	end

	@golden_n :math.sqrt(5)
  	def of(n) do
 		(x_of(n) - y_of(n)) / @golden_n
	end
 	defp x_of(n) do
		:math.pow((1 + @golden_n) / 2, n)
	end
	def y_of(n) do
		:math.pow((1 - @golden_n) / 2, n)
	end
end
