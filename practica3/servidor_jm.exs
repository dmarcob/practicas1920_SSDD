# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario3.ex
# FECHA: 17-10-2019
# DESCRIPCIÓN: Código del servidor: master + pool + worker + detector fallos + fibonacci





	#//////////////////////////////////////////////
	#///////////////////DETECTOR FALLOS////////////
	#//////////////////////////////////////////////

defmodule Proxy do
		import IO.ANSI


def deteccion(worker_map, detector_pid, timeout, args) do
	send(elem(worker_map, 1), {:req, {self(), args}})
	resultado = receive do                      #resultado = -1 -> reiniciar, resultado = -2 -> encender
		 						num ->
														#Recibimos resultado. Si es real, entonces fallo RESPONSE, sino, respuesta correcta
														if is_float(num)  do
															 	IO.write("Response error detected in ")
																IO.inspect worker_map
															 -1
														else
														  num
														end
					 			after
														#No recibimos resultado. Si sigue vivo, fallo TIMING, OMISSION, sino, fallo CRASH
						  	timeout ->
									 if Node.ping(elem(worker_map, 0)) == :pong
									 do
										 IO.write("Omission/Timing error detected in ")
										 IO.inspect worker_map
										 -1
									 else
										 IO.write("Crash error detected in ")
										 IO.inspect worker_map
										 -2
									 end
								end
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

def correccion_reactiva(respuestas, 1) do
	dir = elem(elem(hd(respuestas), 0), 0)
	pid = elem(elem(hd(respuestas), 0), 1)
	n = elem(elem(hd(respuestas), 0), 2)
	resp = elem(hd(respuestas), 1)

	if resp == -1 do
	 Node.spawn(dir, System, :halt, [])
	end
	if resp < 0 do
	 IO.write green <> "Reactive correction in " <>white
	 IO.inspect hd(respuestas)
	 Nodo.encender(dir)
	 Process.sleep(150)
	 if (Node.ping(dir) == :pang), do: IO.puts("correccion_reactiva1: NODO ERROR")
	 pid_new = Node.spawn(dir, Worker, :init, [])
	 [{dir, pid_new, 0}]
  else
	 [{dir, pid, n + 1}]
  end
end

def correccion_reactiva(respuestas, num) when num > 1 do #respuestas = [{{dir, pid, n}, resp}]
	 dir = elem(elem(hd(respuestas), 0), 0)
	 pid = elem(elem(hd(respuestas), 0), 1)
	 n = elem(elem(hd(respuestas), 0), 2)
	 resp = elem(hd(respuestas), 1)

	 if resp == -1 do
	 	Node.spawn(dir, System, :halt, [])
	 end
	 if resp < 0 do
	  IO.write green <> "Reactive correction in " <> white
		IO.inspect hd(respuestas)
	 	Nodo.encender(dir)
		Process.sleep(150)
		if (Node.ping(dir) == :pang), do: IO.puts("correccion_reactiva #{num}: NODO ERROR")
		pid_new = Node.spawn(dir, Worker, :init, [])
		[{dir, pid_new, 0}] ++ correccion_reactiva(tl(respuestas), num - 1)
	 else
		[{dir, pid, n + 1}] ++ correccion_reactiva(tl(respuestas), num - 1)
	 end
end

def correccion_preventiva(workers, 1) do
	dir = elem(hd(workers), 0)
	pid = elem(hd(workers), 1)
	n = elem(hd(workers), 2)

	if n >= 6 do
		IO.write green <> "Preventive correction (n==6), in " <>white
		IO.inspect hd(workers)
		Node.spawn(dir, System, :halt, [])
		Nodo.encender(dir)
		Process.sleep(150)
		if (Node.ping(dir) == :pang), do: IO.puts("correccion_reactiva 1: NODO ERROR")
		pid_new = Node.spawn(dir, Worker, :init, [])
		[{dir, pid_new, 0}]
	else
		[{dir, pid, n}]
	end
end

def correccion_preventiva(workers, num) when num > 1 do
	dir = elem(hd(workers), 0)
	pid = elem(hd(workers), 1)
	n = elem(hd(workers), 2)
	if n >= 6 do
		IO.write green <> "Preventive correction (n==6), in "<> white
		IO.inspect hd(workers)
		Node.spawn(dir, System, :halt, [])
		Nodo.encender(dir)
		Process.sleep(150)
		if (Node.ping(dir) == :pang), do: IO.puts("correccion_reactiva #{num}: NODO ERROR")
		pid_new = Node.spawn(dir, Worker, :init, [])
		[{dir, pid_new, 0}] ++ correccion_preventiva(tl(workers), num - 1)
	else
		[{dir, pid, n}] ++ correccion_preventiva(tl(workers), num - 1)
	end
end

def init(master_pid, pool_pid, tres_worker, timeout, cliente_pid, args) do
	proxy_id = self()
	Enum.each(tres_worker, fn x -> spawn(fn -> deteccion(x, proxy_id, timeout, args) end) end)
	respuestas = receive_results(length(tres_worker)) #[{{dir, pid, n}, resp}]
	respuesta_valida = Enum.uniq(Enum.map(respuestas, fn x -> elem(x, 1) end), fn x -> x > 0 end) #Filtro los resultados válidos y los comparo
	if length(respuesta_valida) == 1 do
		 if args == 1500 do
			#caso ultima peticion
		 	send(master_pid, {cliente_pid, List.first(respuesta_valida), :respuesta})
		 end
		 #Reinicio las máquinas que corresponden
		 tres_worker_fixed = correccion_reactiva(respuestas, 3) #[{dir, pid, n}]
		 #Reinicio las máquinas que se han ejecutado correctamente n veces
		 tres_worker_fixed = correccion_preventiva(tres_worker_fixed, 3)  #[{dir, pid, n}]
		 #Devuelvo workers
		 send(pool_pid, {tres_worker_fixed, :fin})
	else
		 #Reinicio todas las maquinas
		 tres_worker_fixed = correccion_reactiva(respuestas, 3) #[{dir, pid, n}]
	   init(master_pid, pool_pid, tres_worker_fixed, timeout, cliente_pid, args) #incrementamos timeout o no?
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
		master({:pool, pool_dir}, [])
	end

	def master(pool_pid, listaPendientes) do
		receive do
		{cliente_pid, args}  ->
															send(pool_pid, {self(), :peticion})
															master(pool_pid, listaPendientes ++ [{cliente_pid, args}])

		{[w1, w2, w3], :worker, :toma} ->
											tres_worker = [w1, w2, w3]
											master_pid = self()
											spawn(fn -> Proxy.init(master_pid, pool_pid,tres_worker, 300, elem(hd(listaPendientes), 0), elem(hd(listaPendientes), 1)) end)
											master(pool_pid, tl(listaPendientes))

		{cliente_pid, result, :respuesta}  ->
																					send(cliente_pid,{:result, result})
																					master(pool_pid, listaPendientes)
		end
	end
end



  #////////////////////////////////////////////
  #///////////////////POOL/////////////////////
  #////////////////////////////////////////////

defmodule Pool do

def initPool(master_dir, worker_dir, n) do
    Process.register(self(), :pool)
		#Node.set_cookie(:cookie123)
		Node.connect(master_dir)
		workers_dir = Enum.map(1..n, fn x -> String.to_atom("worker" <> "#{x + 3}@" <> worker_dir) end)
		IO.inspect workers_dir
		Enum.each(workers_dir, fn x -> Nodo.encender(x) end)
		Process.sleep(2000)
  	workers_map = Enum.map(workers_dir, fn x -> {x, Node.spawn(x,Worker,:init,[]),  0} end) # [{worker_dir, worker_pid, n}]
		IO.puts("POOL ACTIVO")
    poolWorkers({:server, master_dir}, workers_map, 0)
end





def poolWorkers(master_pid, workers_map, enEspera) do
	IO.puts("************************************")
	IO.puts("poolWorkers: enEspera= #{enEspera}")
	IO.puts("************************************")
	IO.inspect workers_map
	receive do
	{master_pid, :peticion}  ->	if length(workers_map) > 2 do
																		IO.puts("pool: :peticion, 3 Worker concedidos")
										  							send(master_pid, {[hd(workers_map), hd(tl(workers_map)), hd(tl(tl(workers_map)))], :worker, :toma})
										  							poolWorkers(master_pid, tl(tl(tl(workers_map))), enEspera)
																else
																  	IO.puts("pool: :peticion, 3 Worker no concedidios, guardo peticion")
																	  poolWorkers(master_pid, workers_map, enEspera+1)
																end

	{tres_worker, :fin} ->			 if enEspera>0 do
																		IO.puts("pool: :fin, enEspera > 0 ")
																		send(master_pid, {tres_worker, :worker, :toma})
																		poolWorkers(master_pid, workers_map, enEspera-1)
																 else
																	  IO.puts("pool: :fin, enEspera == 0 ")
																		poolWorkers(master_pid, workers_map ++ tres_worker, enEspera)
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
		#Process.sleep(10000)
		#spawn(fn -> latido() end)
		worker(&Fib.fibonacci_tr/1, 1, :rand.uniform(10))
		IO.puts("WORKER BEGIN")
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
			{:req, {pid, args}} ->
															if not omission, do: send(pid, op.(args))
		end
		worker(new_op, rem(service_count + 1, k), k)
	end
end


defmodule Pow do
  require Integer

  def pow(_, 0), do: 1
  def pow(x, n) when Integer.is_odd(n), do: x * pow(x, n - 1)
  def pow(x, n) do
    result = pow(x, div(n, 2))
    result * result
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
		#:math.pow((1 + @golden_n) / 2, n)
		Pow.pow((1 + @golden_n) / 2, n)
	end
	def y_of(n) do
		#:math.pow((1 - @golden_n) / 2, n)
		Pow.pow((1 - @golden_n) / 2, n)
	end
end
