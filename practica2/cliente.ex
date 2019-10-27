# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: cliente.ex
# FECHA: 27-09-2019
# DESCRIPCIÓN: Código de los lectores y escritores




#Process.info(self(), :messages), Para leer el mailbox
#flush, para vaciar el mailbox

defmodule Cliente do


############################### MUTEX + VARIABLES_GLOBALES #######################################     PROCESO 1
  #Mutex para gestionar concurrencia (1)y(2) con (11) en el algoritmo de Ricart Agrawala
  def mutex do
    receive do
      {pid, :coger_mutex} -> send(pid,{:ok_mutex, self()})
                              IO.puts("mutex: recibido coger")
    end
    receive do
      {pid, :soltar_mutex} -> IO.puts("mutex: recibido soltar")
                              mutex()
    end
  end

  #Mantiene el estado de las variables globales                                                        PROCESO 2
  def variables_globales ({state, clock, lrd}) do
      #state=0 -> out, state=1 -> trying, state=2 -> in
      {state_new, clock_new, lrd_new} = receive do
          {pid, :write_state, update} -> send(pid, :ok_write_state); {update, clock, lrd}
          {pid, :write_clock, update} -> send(pid, :ok_write_clock); {state, update, lrd}
          {pid, :write_lrd, update} -> send(pid, :ok_write_lrd); {state, clock, update}
          {pid, :read_state} -> send(pid, :ok_read_state, state); {state, clock, lrd}
          {pid, :read_clock} -> send(pid, :ok_read_clock, clock); {state, clock, lrd}
          {pid, :read_lrd} -> send(pid, :ok_read_lrd, lrd); {state, clock, lrd}
      end
      variables_globales({state_new, clock_new, lrd_new})
 end
############################### INICIALIZAR #######################################                    PROCESO 3
  #Levanta un escritor y lo conecta al servidor
  def initEscritor(dir_server, pid_clientes) do
    #COMPLETAR
  end

  #Levanta un lector y lo conecta al servidor
  def initLector(dir_server, pid_clientes) do
     #añadir cookie
     Node.set_cookie(:cookie123)
     #Conectar con servidor
     Node.connect(dirServer)
     receive do
       {pid, :empezar, pid_clientes} ->      pid_mutex = spawn(fn -> mutex() end)
                                             pid_variables = spawn(fn -> variables_globales(0, 0, 0) end)
                                             lector(dir_server, pid_clientes, pid_mutex, pid_variables, 0)
     end
  end


  def obtenerPid(dir_server, dir_clientes, 0, 1) do
      [Node.spawn(hd(dir_clientes),Cliente,:initLector,[dir_server])]
  end

  def obtenerPid(dir_server, dir_clientes, nEscritores, nLectores) when nLectores != 1 do
      if nEscritores != 0 do
        pid_clientes = [Node.spawn(hd(dir_clientes),Cliente,:initEscritor,[dir_server])]
        pid_clientes ++ obtenerPid(dir_server, tl(dir_clientes), nEscritores - 1, nLectores)
      else
        pid_clientes = [Node.spawn(hd(dir_clientes),Cliente,:initLector,[dir_server])]
        pid_clientes ++ obtenerPid(dir_server, tl(dir_clientes), nEscritores, nLectores - 1)
      end
  end

  def empezar(pid_clientes, 1, pid_clientes_copia) do
      send(hd(pid_clientes),{self(), :empezar, pid_clientes_copia})
  end

  def empezar(pid_clientes, nClientes, pid_clientes_copia) when nClientes != 1 do
     send(hd(pid_clientes),{self(), :empezar, pid_clientes_copia})
     empezar(tl(pid_clientes), nClientes - 1, pid_clientes_copia)
  end

  def init (dirServer, nEscritores, nLectores, dir_clientes) do
      pid_clientes = obtenerPid(dirServer, dir_clientes, nEscritores, nLectores)
      empezar(pid_clientes, nLectores + nEscritores, pid_clientes)
  end

############################### LECTOR/ESCRITOR ####################################
  def escritor do
    #COMPLETAR
  end

  def lector(dir_server, pid_clientes_copia, pid_mutex, pid_variables, time) do
    begin_op(pid_clientes, pid_mutex, pid_variables)
    cond do
      time == 0 ->  send({:server, dirServer}, {:read_resumen, self()}); Process.sleep(:rand.uniform(1000) + 1000)
      time == 1 ->  send({:server, dirServer}, {:read_principal, self()}); Process.sleep(:rand.uniform(1000) + 1000)
      time <= 2 ->  send({:server, dirServer}, {:read_entrega, self()}); Process.sleep(:rand.uniform(1000) + 1000)
    end
    end_op()
    lector(dir_server, pid_clientes_copia, pid_mutex, pid_variables, rem(time + 1, 3))
  end

############################### RICART AGRAWALA ###################################




  #Operacion para obtener el mutex distribuido
  def begin_op(lista_clientes, pid_mutex, pid_variables) do
      #cs_statei <- trying; lrdi <-clocki + 1;
      send(pid_mutex, {self(), :coger_mutex}) #Pido mutex
      receive do
        {:ok_mutex,pid} -> send(pid_variables,{self(), :write_state, 1}) #SECCIÓN CRÍTICA                                       #ARREGLAR: clock lrd
      end
      send(pid_mutex, {self(), :soltar_mutex}) #Dejo mutex
      #waiting fromi <-Ri: %Ri={1...n} \ {i}



  end
end
