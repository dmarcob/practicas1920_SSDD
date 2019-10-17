# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario3.ex
# FECHA: 27-09-2019
# DESCRIPCIÓN:

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
  workers = [:"worker1@127.0.0.1", :"worker@127.0.0.1"]
  lEspera = []

    receive do
    {pid_m, :peticion}  ->
                  //COMPROBAR SI HAY ALGUN WORKER LIBRE
                  //SINO HAY AGNADIR A LISTA DE ESPERA
                  send(pid_m, {worker})

    {pid_w, :fin} ->
                  //SI HAY PETICIONES EN LA LISTA DE ESPERA, SE LE ASIGNA A LA PRIMERA EL WORKER QUE HA ACABADO
                  //SI NO SE AGNADE A LA LISTA DE WORKERS LIBRES EL pid recibido


    end
    poolWorkers()
  end

end
