# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario3.ex
# FECHA: 17-10-2019
# DESCRIPCIÓN: Código del servidor: master + pool + worker + detector fallos + fibonacci





	#//////////////////////////////////////////////
	#///////////////////DETECTOR FALLOS////////////
	#//////////////////////////////////////////////

defmodule DetectorFallos do

def detect(worker_map, detector_pid, timeout, args) do
	DEBUG.print("detect: BEGIN")
	DEBUG.print("detect: worker_map")
	DEBUG.inspect(worker_map)
	DEBUG.print("detect:args")
	DEBUG.print("detect:Eniviado peticion....")

	send(elem(worker_map, 1), {:req, {self(), args}})
	resultado = receive do                      #resultado = -1 -> reiniciar, resultado = -2 -> encender
		 						{pid_w, num} ->
														if is_float(num) do
															#Fallo response, necesita reiniciar
															-1
														else
															num
														end
					 			after
						  	timeout ->  if ping(elem(worker_map, 0)) == :pong
														#Fallo omission, timing
														 -1
													 else #:pang
													   #Fallo crash
													 	 -2
								end
	DEBUG.print("detect: Enviando #{resultado} a detectors")
	send(detector_pid, {worker_map, resultado})
end

def receive_results(1) do
	[{worker_map, resultado}]  = receive do
															{worker_map, resultado} -> [{worker_map, resultado}]
	end
	[{worker_map, resultado}]
end

def receive_results(num_workers) when num_workers > 1 do
	[{worker_map, resultado}] = receive do
													    {worker_map, resultado} -> [{worker_map, resultado}]
	end
	[{worker_map, resultado}] ++ receive_results(num_workers - 1)
end

def detectorFallos(master_pid, pool_pid, tres_worker, timeout, cliente_pid, args) do

	Enum.each(tres_worker, fn x -> spawn(fn -> detect(x, self(), timeout, args) end) end)
	respuestas = receive_results(length(tres_worker))
	respuesta_valida = Enum.uniq(Enum.map(respuestas, fn x -> elem(x, 1) end), fn x -> x > 0 end)) #Filtro los resultados válidos y los comparo
	if respuesta_valida.length() == 1 do
		 if args == 1500 do
			#caso ultima peticion
		 	send(master_pid, )
		 end
		 #Reinicio las máquinas que corresponden
		 correccion_reactiva(respuestas)
		 #Reinicio las máquinas que se han ejecutado correctamente n veces
		 correccion_preventiva(respuestas)
		 #Devuelvo workers
		 send(pool_pid, ...)
	else
		 #Reinicio todas las maquinas
		 correccion_reactiva(respuestas)
	   detectorFallos(master_pid, pool_pid, [elem(hd(respuestas),0), elem(hd(tl(respuestas)),0), elem(hd(tl(tl(respuestas))),0)], timeout, args) #incrementamos timeout o no?
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
		master({pool_dir, :pool}, [])
	end

	def master(pool_pid, listaPendientes) do
		receive do
		{cliente_pid, args}  ->	  send(pool_pid, {self(), :peticion})
															master(pool_pid, listaPendientes ++ [{cliente_pid, args}])

		[tres_worker] ->  spawn(fn -> DetectorFallos.detectorFallos(master_pid, pool_pid,[tres_worker], 500, elem(hd(listaPendientes), 0), elem(hd(listaPendientes), 1)) end)
											master(pool_pid, tl(listaPendientes))

		{cliente_pid, :respuesta}  -> send(cliente_pid,{:result, result})
																	master(pool_pid, listaPendientes)
		end
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
    poolWorkers({master_dir, :server}, workers_map, 0)
end


def encender(nodo) do
	to_string(nodo)
	System.cmd("iex", ["--name","#{nodo}", "--detached"])
end

defmodule Prueba do
def encenderRemoto(nodo) do
	nodo = to_string(nodo)
	ip = elem(String.split(nodo,"@"), 1)
	IO.puts("---> #{ip}")
	System.cmd("ssh", [
	  "a755232@#{ip}",
	  "iex --name #{nodo} --cookie cookie123",
	  "--erl  \'-kernel_inet_dist_listen_min 32000\'",
	  "--erl  \'-kernel_inet_dist_listen_max 32049\'",
		"--erl -detached"
	])
end
end


def poolWorkers(master_pid, workers_map, enEspera) do
	IO.puts("************************************")
	IO.puts("poolWorkers: enEspera= #{enEspera}")
	IO.puts("************************************")
	IO.inspect workers_map
	receive do
	{master_pid, :peticion}  ->	if length(workers_map) > 2 do
																		DEBUG.print("pool: :peticion, Worker concedido")
										  							send(detector_pid, [hd(workers_map), hd(tl(workers_map)), hd(tl(tl(workers_map)))])
										  							poolWorkers(tl(tl(tl(workers_map))), enEspera)
																else
																	DEBUG.print("pool: :peticion, Worker no concedidio, guardo peticion")
																	  poolWorkers(workers_map, enEspera+1)
																end

	{[tres_worker], :fin} ->			 if enEspera>0 do
																		DEBUG.print("acttualizar: enEspera > 0 ")
																		send(master_pid, [tres_worker])
																		poolWorkers(workers_map, enEspera-1)
																 else
																	  DEBUG.print("acttualizar: enEspera == 0 ")
																		poolWorkers(workers_map ++ [tres_worker], enEspera)
																 end
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
