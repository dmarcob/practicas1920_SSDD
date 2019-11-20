# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario3.ex
# FECHA: 17-10-2019
# DESCRIPCIÓN: Código del servidor: master + pool + worker + detector fallos + fibonacci





	#//////////////////////////////////////////////
	#///////////////////DETECTOR FALLOS////////////
	#//////////////////////////////////////////////

defmodule DetectorFallos do

	def pedirWorkersPool(pool_dir, 1) do
		send({:pool,pool_dir}, {self(), :peticion})
		workers_map= receive do
					{worker_dir, worker_pid, n} -> [{worker_dir, worker_pid, n}]
					end
	  workers_map
  end

def pedirWorkersPool(pool_dir, n_replicas) when n_replicas > 1 do
	send({:pool,pool_dir}, {self(), :peticion})
	workers_map = receive do
					{worker_dir, worker_pid, n} -> [{worker_dir, worker_pid, n}]
				end
	workers_map ++ pedirWorkersPool(pool_dir, n_replicas - 1)
end

def detect(worker_map, detector_pid, pool_dir, timeout, args) do
	send(elem(elem(worker_map, 1),0), {:req, {self(), args}})
	resultado = receive do
		 						{pid_w, num} ->
														if is_float(num) do
															#Fallo response, necesita reiniciar
															send({:pool, pool_dir}, {self(), worker_map, :reset})
															-1
														else
															send({:pool, pool_dir}, {self(), elem(worker_map, 0),elem(worker_map, 1), elem(worker_map, 2) + 1, :fin})
															num
														end
					 			after
						  	timeout ->  #comprobamos si la maquina a la que esperamos sigue viva -> latido? si sigue viva hacer spawn remoto con System.halt() y volver a arrancar
						 						# si no sigue viva volver a arrancar
													   # send(pid_worker, :latido)           #REVISAR
														 # error = receive do
														 # 				 	{:ok} -> #Fallo omission / timing, necesita reiniciar
															# 										 send(pool_pid, {pid_w, :reset})
															# 										 -1
															# 		 		after
															# 			 			50 ->  #Fallo crash, necesita encenderse
															# 									 send(pool_pid, {pid_w, :turnon})
															# 									 -2
														 # end
														 send({:pool, pool_dir},{self(), worker_map, :reset})
														 -1
								end
	send(detector_pid, {resultado})
end

def receive_results(1) do
	respuesta = receive do
							{resultado} -> resultado
	end
	[respuesta]
end

def receive_results(num_workers) when num_workers > 1 do
	respuesta = receive do
							{resultado} -> resultado
	end
	[respuesta] ++ receive_results(num_workers - 1)
end

def detectorFallos(pool_dir, n_replicas, timeout, args) do
	workers_map = pedirWorkersPool(pool_dir, n_replicas)
	Enum.each(workers_map, spawn fn x -> detect(x, self(), pool_dir, timeout, args)end)
	respuestas = receive_results(length(workers_map))
	respuesta_valida = Enum.uniq(Enum.filter([respuestas], fn x -> x > 0 end)) #Filtro los resultados válidos y los comparo
	if respuesta_valida.length() == 1 do
		 respuesta_valida
	else
	   detectorFallos(pool_dir, n_replicas + 1, 1.25*timeout, args) #incrementamos timeout o no?
	end
 	end
end

#//////////////////////////////////////////////
#/////////////////// MASTER ///////////////
#//////////////////////////////////////////////

defmodule Master do

	def initMaster(pool_dir) do
		Process.register(self(), :server)
		Node.set_cookie(:cookie123)
		IO.puts("MASTER ACTIVO")
		master(pool_dir)
	end

	def master(pool_dir) do
		receive do
		{pid,args}  ->
														IO.puts("master: PETICION RECIBIDA")
														result = DetectorFallos.detectorFallos(pool_dir, 3, 300, args) #establecer timeout y numero de replicas iniciales
														if args == 1500 do
															 send(pid,{:result, result})
														end
		end
		master(pool_dir)
	end
end



  #////////////////////////////////////////////
  #///////////////////POOL/////////////////////
  #////////////////////////////////////////////

defmodule Pool do

def initPool(master_dir, workers_dir) do
    Process.register(self(), :pool)
		Node.set_cookie(:cookie123)
		Node.connect(master_dir)
		Enum.each(workers_dir, fn(x) -> Node.connect(x) end) #Conectamos workers
		#workerspid = Enum.map(workers_dir, fn(x) -> Node.spawn(x,Worker,:init,[])end) #Levantamos workers
		workers_map = Enum.map([workers_dir], fn x -> {x, Node.spawn(x,Worker,:init,[]),  0} end) # [{worker_dir, worker_pid, n}]
		IO.puts("POOL ACTIVO")
    poolWorkers(workers_map, 0)
end

def actualizar(workers_map, enEspera, detector_pid, worker_dir, worker_pid, n) do
	if enEspera>0 do
		 send(detector_pid, {worker_dir, worker_pid, n})
		 poolWorkers(workers_map, enEspera-1)
	else
		 poolWorkers(workers_map ++ [{worker_dir, worker_pid, n}], enEspera)
	end
end

def poolWorkers(workers_map, enEspera) do
	IO.puts("************************************")
	IO.puts("poolWorkers: enEspera= #{enEspera}")
	IO.puts("************************************")
	IO.inspect workers_map
	receive do
	{detector_pid, :peticion}  ->	if length(workers_map) > 0 do
										  							send(detector_pid, hd(workers_map))
										  							poolWorkers(tl(workers_map), enEspera)
																else
																	  poolWorkers(workers_map, enEspera+1)
																end

	{detector_pid,{worker_dir,worker_pid,  n}, :fin} ->	if n = 6 do
																												 #parar maquina
																												 Node.spawn(worker_dir, System,:halt,[])
																												 #Encender sistema y devolver worker a pool
																												 actualizar(workers_map, enEspera, detector_pid, worker_dir, Node.spawn(worker_dir, Worker,:init,[]), 0)
																										  else
																												 actualizar(workers_map, enEspera, detector_pid, worker_dir, worker_pid, n)
																											end

  {detector_pid,{worker_dir,worker_pid,  n}, :reset} -> #parar maquina
																											  Node.spawn(worker_dir, System,:halt,[])
																											  #Encender sistema y devolver worker a pool
																												actualizar(workers_map, enEspera, detector_pid, worker_dir, Node.spawn(worker_dir, Worker,:init,[]), 0)

	{detector_pid,{worker_dir,worker_pid,n}, :turnon} ->	#Encender sistema y devolver worker a pool
																								actualizar(workers_map, enEspera, detector_pid, worker_dir, Node.spawn(worker_dir, Worker,:init,[]), 0)
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
