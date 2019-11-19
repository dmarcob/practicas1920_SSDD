# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario3.ex
# FECHA: 17-10-2019
# DESCRIPCIÓN: Código del servidor: master + pool + worker + detector fallos + fibonacci





	#//////////////////////////////////////////////
	#///////////////////DETECTOR FALLOS////////////
	#//////////////////////////////////////////////

defmodule DetectorFallos do
	def init() do
		Process.register(self(), :detector)
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


def solucionar_error([], []) do
end

def solucionar_error(pid_workers, resultados) do
	if hd(resultados) == -1 do
		System.halt(hd(pid_workers))
		#Encender sistema
	else id hd(resultados) == -2
		System.halt(hd(pid_workers))
	end
	solucionar_error(tl(pid_workers, tl(resultados)))
end
# #vamos a forzar a recibir resultados de todas replicas que hemos realizado????
# def receive_task(pid_pool, pid_workers, 1) do
# 	result = receive do
# 		 					{hd(pid_workers), num} -> #como hacer que pid haga matching con un pid en concreto de la lista de workers
# 														#el worker ya ha acabado de realizar la operacion, se le devuelve al pool
# 														#comprobar si hay un fallo de tipos, es decir, si se ha recibido un real en vez de un entero, en ese caso no anadir a la lista de result
# 														send(pid_pool, {pid, :fin})
# 														[num]
# 					 after
# 						 timeout ->  #comprobamos si la maquina a la que esperamos sigue viva -> latido? si sigue viva hacer spawn remoto con System.halt() y volver a arrancar
# 						 						# si no sigue viva volver a arrancar
# 														[]
# 	result
# end

def receive_task(pid_pool, pid_workers, timeout) do
#	Enum map itera sobre los pid y devuelve una lista con por ejemplo [num, -1, -2] siendo -1 y -2 errores del segundo y tercer worker de la lista pid_workers
resultados = Enum.map(pid_workers, fn x ->
						  	receive do
		 						{x, num} ->
														if is_float(num) do
															-1 #Fallo response, necesita reiniciar
														else
															send(pid_pool, {self(), :fin))
															num
					 			after
						  	timeout ->  #comprobamos si la maquina a la que esperamos sigue viva -> latido? si sigue viva hacer spawn remoto con System.halt() y volver a arrancar
						 						# si no sigue viva volver a arrancar
													   send(x, :latido)
														 error = receive do
														 				 			{:ok} -> -1 #Fallo omission / timing, necesita reiniciar
																	 		after
																		 			50 -> -2 #Fallo crash, necesita iniciar
														 end
													   error
								end end)
	solucionar_error(pid_workers, resultados)
	resultados
	#result ++ receive_task(pid_pool, tl(pid_workers), n_replicas - 1, timeout)
end

# def compare_results([last], res) do
# 	if last = res
# 		res
# 	else
# 		-1
# end
#
# def compare_results(results, res) do
# 	if hd(results) = res
# 		compare_results(tl(results), res)
# 	else
# 		-1
# end

def detectorFallos(pid_pool, n_replicas, timeout, num) do
	pid_workers = pedirWorkersPool(pid_pool, n_replicas)
	send_task(pid_workers, num)
	resultados = receive_task(pid_pool, pid_workers, timeout)
#	correcto = compare_results(tl(results), hd(results))
#	if correcto >=0
#	correcto
	respuesta_valida = Enum.uniq(Enum.filter(resultados, fn x -> x > 0 end)) #Filtro los resultados válidos y los comparo
	if respuesta_valida.length == 1 do
		 respuesta_valida
	else
	detectorFallos(pid_pool, n_replicas + 1, 1.25*timeout, num)
	end
end


#//////////////////////////////////////////////
#///////////////////MASTER~PROXY///////////////
#//////////////////////////////////////////////

defmodule MasterProxy do

	def initMaster(pool_pid) do
		Process.register(self(), :server)
		Node.set_cookie(:cookie123)
		IO.puts("MASTER ACTIVO")
		spawn(fn -> DetectorFallos.init() end)
		masterProxy(pool_pid)
	end

 def masterProxy(pool_pid) do
	receive do
	{pid,num}  ->
													IO.puts("master: PETICION RECIBIDA")
													result = detectorFallos(pid_pool, n_replicas, timeout, num) #establecer timeout
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

{pid_w, :fin} ->
								if enEspera>0 do
								end
								end
									send(detector_pid, {pid_w})
									poolWorkers(detector_pid, workers, enEspera-1)
								else
									poolWorkers(detector_pid, workers ++ [pid_w], enEspera)
								end
    end
  end
end


#////////////////////////////////////////////
#///////////////////WORKER/////////////////////
#////////////////////////////////////////////

defmodule Worker do

	def init do
		Process.sleep(10000)
		worker(&Fib.fibonacci_tr/1, 1, :rand.uniform(10))
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
