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
		DEBUG.print("pedirWorkersPool 1 BEGIN")

		send({:pool,pool_dir}, {self(), :peticion})
		workers_map= receive do
					{worker_dir, worker_pid, n} -> [{worker_dir, worker_pid, n}]
					end
	  workers_map
  end

def pedirWorkersPool(pool_dir, n_replicas) when n_replicas > 1 do
	DEBUG.print("pedirWorkersPool #{n_replicas} BEGIN")
	send({:pool,pool_dir}, {self(), :peticion})
	workers_map = receive do
					{worker_dir, worker_pid, n} -> [{worker_dir, worker_pid, n}]
				end
	workers_map ++ pedirWorkersPool(pool_dir, n_replicas - 1)
end

def detect(worker_map, detector_pid, pool_dir, timeout, args) do
	DEBUG.print("detect: BEGIN")
	DEBUG.print("detect: worker_map")
	DEBUG.inspect(worker_map)
	DEBUG.print("detect:args")
	DEBUG.print("detect:Eniviado peticion....")

	send(elem(worker_map, 1), {:req, {self(), args}})
	resultado = receive do
		 						{pid_w, num} ->
														DEBUG.print("detect: Recibido repuesta")

														if is_float(num) do
															DEBUG.print("detect: Recibido repuesta. FALLO RESPONSE")

															#Fallo response, necesita reiniciar
															send({:pool, pool_dir}, {self(), worker_map, :reset})
															-1
														else
															DEBUG.print("detect: Recibido repuesta CORRECTA")

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
														 DEBUG.print("detect:HA CADUCADO TIMEOUT")

														 send({:pool, pool_dir},{self(), worker_map, :reset})
														 -1
								end
	DEBUG.print("detect: Enviando #{resultado} a detectors")

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
	DEBUG.print("detectorFallos: BEGIN")
	DEBUG.print("detectorFallos: n_replicas: #{n_replicas}")
	DEBUG.print("detectorFallos: args: #{args}")

	workers_map = pedirWorkersPool(pool_dir, n_replicas)
	DEBUG.print("detectorFallos:")
	DEBUG.inspect(workers_map)

	Enum.each(workers_map, fn x -> spawn(fn -> detect(x, self(), pool_dir, timeout, args) end) end)
	respuestas = receive_results(length(workers_map))
	DEBUG.print("detectorFallos: recibido de detect: ")
	DEBUG.inspect(respuestas)

	respuesta_valida = Enum.uniq(Enum.filter([respuestas], fn x -> x > 0 end)) #Filtro los resultados válidos y los comparo
	DEBUG.print("detectorFallos: respuesta_valida: #{respuesta_valida} ")

	if respuesta_valida.length() == 1 do
		DEBUG.print("detectorFallos: END ")

		 respuesta_valida
	else
		DEBUG.print("detectorFallos: Me reinvoco ")

	   detectorFallos(pool_dir, n_replicas + 1, 1.25*timeout, args) #incrementamos timeout o no?
	end
 	end
end

#//////////////////////////////////////////////
#/////////////////// MASTER ///////////////
#//////////////////////////////////////////////

defmodule Master do

	def init(pool_dir) do
		Process.register(self(), :server)
		#Node.set_cookie(:cookie123)
		IO.puts("MASTER ACTIVO")
		master(pool_dir)
	end

	def master(pool_dir) do
		receive do
		{pid,args}  ->
														DEBUG.print("master: peticion cliente recibida: #{args}")
														result = DetectorFallos.detectorFallos(pool_dir, 3, 500, args) #establecer timeout y numero de replicas iniciales
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
		#Node.set_cookie(:cookie123)
		Node.connect(master_dir)
		#Enum.each(workers_dir, fn(x) -> Node.connect(x) end) #Conectamos workers
  	workers_map = Enum.map(workers_dir, fn x -> {x, Node.spawn(x,Worker,:init,[]),  0} end) # [{worker_dir, worker_pid, n}]
		IO.inspect workers_map
		IO.puts("POOL ACTIVO")
    poolWorkers(workers_map, 0)
end

defmodule Prueba do
def encender() do
	System.cmd("bash", ["iex --name","worker2@127.0.0.2", "&"])
end
end

def encenderRemoto() do
	# System.cmd("ssh", [
	#   "a755232@155.210.154.209",
	#   "iex --name worker1@155.210.154.210 --cookie cookie123",
	#   "--erl  \'-kernel_inet_dist_listen_min 32000\'",
	#   "--erl  \'-kernel_inet_dist_listen_max 32049\'",
	# ])
end

def actualizar(workers_map, enEspera, detector_pid, worker_dir, worker_pid, n) do
	DEBUG.print("actualizar: BEGIN, enEspera: #{enEspera}")
	DEBUG.inspect(worker_dir)
	DEBUG.print("#{n}")
	if enEspera>0 do
		DEBUG.print("acttualizar: enEspera > 0 ")

		 send(detector_pid, {worker_dir, worker_pid, n})
		 poolWorkers(workers_map, enEspera-1)
	else
		DEBUG.print("acttualizar: enEspera == 0 ")

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
																		DEBUG.print("pool: :peticion, Worker concedido")

										  							send(detector_pid, hd(workers_map))
										  							poolWorkers(tl(workers_map), enEspera)
																else
																	DEBUG.print("pool: :peticion, Worker no concedidio, guardo peticion")

																	  poolWorkers(workers_map, enEspera+1)
																end

	{detector_pid,{worker_dir,worker_pid,  n}, :fin} ->	if n == 6 do
																												DEBUG.print("pool: :fin, n==6 ")

																												 #parar maquina
																												 Node.spawn(worker_dir, System,:halt,[])
																												 #Encender sistema y devolver worker a pool

																												 actualizar(workers_map, enEspera, detector_pid, worker_dir, Node.spawn(worker_dir, Worker,:init,[]), 0)
																										  else
																												DEBUG.print("pool: :fin, n= #{n}")

																												 actualizar(workers_map, enEspera, detector_pid, worker_dir, worker_pid, n)
																											end

  {detector_pid,{worker_dir,worker_pid,  n}, :reset} -> #parar maquina
																												DEBUG.print("pool: :reset ")
																												DEBUG.inspect(worker_dir)
																												DEBUG.print("#{n}")

																											  Node.spawn(worker_dir, System,:halt,[])
																											  #Encender sistema y devolver worker a pool
																												actualizar(workers_map, enEspera, detector_pid, worker_dir, Node.spawn(worker_dir, Worker,:init,[]), 0)

	{detector_pid,{worker_dir,worker_pid,n}, :turnon} ->	#Encender sistema y devolver worker a pool
																											DEBUG.print("pool: :turnon ")

																								actualizar(workers_map, enEspera, detector_pid, worker_dir, Node.spawn(worker_dir, Worker,:init,[]), 0)
  end
 end
end
#////////////////////////////////////////////
#///////////////////WORKER/////////////////////
#////////////////////////////////////////////

defmodule Worker do

	def init() do
		#Node.set_cookie(:cookie123)
		Process.sleep(10000)
		spawn(fn -> latido() end)
		worker(&Fib.fibonacci_tr/1, 1, :rand.uniform(10))
		DEBUG.print("BEGIN")
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
			{:req, {pid, args}} ->  DEBUG.print("Recibido petición: ")
														  DEBUG.inspect([op, omission, args])
															if not omission, do: send(pid, op.(args))
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
