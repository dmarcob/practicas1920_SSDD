# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario3.ex
# FECHA: 27-09-2019
# DESCRIPCIÓN:

//agnadir elementos a lista con [] ++ []
//sacar primero de la lista hd([])
//quitar primero de la lista [] = tl([])
//tamagno de una lista length([])

defmodule EscenarioTres do
	def inicializarCliente() do
		#registrarse
		#Process.register(self(), :client)
		#añadir cookie

		#Conectar con maquina servidor
		Cliente.cliente({:server,:"servidor@127.0.0.1"},:tres)
		IO.puts("cliente ya ha pedido")
	end



	def inicializarServidor() do
    #registrarse
    Process.register(self(), :server)
    #añadir cookie
    #llamar a Servidor
		IO.puts("SERVIDOR ACTIVO")
    servidor()
  end


  //////////////////////////////////////////////
  ///////////////////MASTER/////////////////////
  //////////////////////////////////////////////
  def master() do

    pidPool = pool@127.0.0.1
    //RECIBE 1 Fibonacci a realizar
    receive do
	  {pid,:fib,rango,num}  ->

															//SEND PETICION DE WORKER A POOL DE WORKERS
                              send(pidPool, {self,:peticion})

                              //RECIEVE DE POOL DE WORKERS A QUE WORKER MANDAR LA TAREA
                              //SI HAY WORKERS DISPONIBLES, LE MANDA EL FIBONACCI
                              //SI NO HAY WORKERS DISPONIBLES SE QUEDA ESPERANDO
                              recieve do
                              {pidWorker} -> send(pidWorker, {pid,pidPool,:fib,rango,num})
    end
    master()
  end

//////////////////////////////////////////////
///////////////////WORKER/////////////////////
//////////////////////////////////////////////
  def worker() do

  receive do
  {pid_m,pid_pool:fib,rango,num}  -> 	  spawn( fn ->
                            resultado = Enum.map(rango, fn x -> Fib.fibonacci(x) end)
                            //se comunica al pool de workers de que hemos terminado
                            send(pid_pool, {self,:fin})

  {pid_m,pid_pool,:fib_tr,rango,num} -> spawn( fn ->
                            resultado = Enum.map(rango, fn x -> Fib.fibonacci(x) end)
                            //se comunica al pool de workers de que hemos terminado
                            send(pid_pool, {self,:fin})

    end
    worker()
  end

  //////////////////////////////////////////////
  ///////////////////POOL/////////////////////
  //////////////////////////////////////////////
  def poolWorkers() do

  #pids de los workers.
  workers = [:"worker1@127.0.0.2",:"worker2@127.0.0.2",:"worker3@127.0.0.2",:"worker4@127.0.0.2", :"worker5@127.0.0.3",:"worker6@127.0.0.3",:"worker7@127.0.0.3",:"worker8@127.0.0.3"]
  espera = 0
	pid_m =
    receive do
    {pid_m, :peticion}  ->
                  if length(workers)>0 do
                  	send(pid_m, {hd(workers)})
										workers = tl(workers)
									else
										espera = espera+1
									end

    {pid_w, :fin} ->
                  if espera>0 do
										send(pid_m, {pid_w})
									else
										workers = workers ++ [pid_w]

    end
    poolWorkers()
  end

end
