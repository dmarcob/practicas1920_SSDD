# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: cliente.ex
# FECHA: 27-09-2019
# DESCRIPCIÓN: Código de los lectores y escritores




#Process.info(self(), :messages), Para leer el mailbox
#flush, para vaciar el mailbox


defmodule Arrancar do

  #############################################################################
  ##############Arrancar todos los clientes con todos sus procesos#############
  #############################################################################

  def obtenerPidCliente(dir_server, dir_clientes, 1, 0, argumento1, argumento2,argumento3, argumento4) do
     [Node.spawn(hd(dir_clientes),Cliente,:initLector,[dir_server, 1, argumento1, argumento2,hd(argumento3), hd(argumento4)])]
  end

  def obtenerPidCliente(dir_server, dir_clientes, 0, 1, argumento1, argumento2,argumento3, argumento4) do
     [Node.spawn(hd(dir_clientes),Cliente,:initEscritor,[dir_server, 1, argumento1, argumento2,hd(argumento3), hd(argumento4)])]
  end

  def obtenerPidCliente(dir_server, dir_clientes, nLectores, nEscritores, argumento1, argumento2,argumento3, argumento4) when (nLectores > 0 or nEscritores > 1) and (nLectores > 1 or nEscritores > 0) do
      if nLectores != 0 do
        pid_clientes = [Node.spawn(hd(dir_clientes),Cliente,:initLector,[dir_server, nLectores + nEscritores, argumento1, argumento2, hd(argumento3), hd(argumento4)])]
        pid_clientes ++ obtenerPidCliente(dir_server, tl(dir_clientes), nLectores - 1, nEscritores, argumento1, argumento2,tl(argumento3), tl(argumento4))
      else
        pid_clientes = [Node.spawn(hd(dir_clientes),Cliente,:initEscritor,[dir_server, nLectores + nEscritores,argumento1, argumento2, hd(argumento3), hd(argumento4)])]
        pid_clientes ++ obtenerPidCliente(dir_server, tl(dir_clientes), nLectores, nEscritores - 1, argumento1, argumento2, tl(argumento3), tl(argumento4))
      end
  end

  def obtenerPidRequest(dir_server, dir_clientes, 1, 0, argumento, matriz) do
      [Node.spawn(hd(dir_clientes),Cliente,:request,[argumento, 1, matriz, 0])]
  end

  def obtenerPidRequest(dir_server, dir_clientes, 0, 1, argumento, matriz) do
      [Node.spawn(hd(dir_clientes),Cliente,:request,[argumento, 1, matriz, 1])]
  end

  def obtenerPidRequest(dir_server, dir_clientes, nLectores, nEscritores, argumento, matriz) when (nLectores > 0 or nEscritores > 1) and (nLectores > 1 or nEscritores > 0) do
    if nLectores != 0 do
        pid_clientes = [Node.spawn(hd(dir_clientes),Cliente,:request,[argumento, nLectores + nEscritores, matriz, 0])]
        pid_clientes ++ obtenerPidRequest(dir_server, tl(dir_clientes),  nLectores - 1, nEscritores, argumento, matriz)
    else
       pid_clientes = [Node.spawn(hd(dir_clientes),Cliente,:request,[argumento, nLectores + nEscritores, matriz, 1])]
       pid_clientes ++ obtenerPidRequest(dir_server, tl(dir_clientes),  nLectores, nEscritores - 1, argumento, matriz)
    end
  end

  def obtenerPidPermission(dir_server, dir_clientes, 1, argumento1) do
      [Node.spawn(hd(dir_clientes),Cliente,:permission,[argumento1, argumento1])]
  end

  def obtenerPidPermission(dir_server, dir_clientes, nClientes, argumento1) when nClientes > 1 do
        pid_clientes = [Node.spawn(hd(dir_clientes),Cliente,:permission,[argumento1, argumento1])]
        pid_clientes ++ obtenerPidPermission(dir_server, tl(dir_clientes), nClientes - 1, argumento1)
  end

  def empezar(pid_clientes, 1) do
      send(hd(pid_clientes),{self(), :empezar})
  end

  def empezar(pid_clientes, nClientes) when nClientes > 1 do
     send(hd(pid_clientes),{self(), :empezar})
     empezar(tl(pid_clientes), nClientes - 1)
  end

  def init(dirServer, nEscritores, nLectores, dir_clientes) do
    ###IO.puts("init: PRINCIPIO");
    Node.set_cookie(:cookie123)
    Node.connect(dirServer)
    #Defino matriz de exclusion,
    #         lector    escritor
    #         ------- ---------
    #lector  |bool   | bool    |
    #escritor|bool   | bool    |
    #        -------- ---------
    exclude = {
      {false, true},
      {true, true}
    }


    #Lanzo remotamente en cada cliente el proceso que atiende los reply de los demás clientes
    pid_permissions = obtenerPidPermission(dirServer, dir_clientes, nLectores + nEscritores, nLectores + nEscritores)
  ###  IO.puts("init: pid_permissions: ")
  ###  IO.inspect pid_permissions
  ###  IO.puts("-------------------------------------------------")
    #Lanzo remotamente en cada cliente el proceso que atiende las request de los demás clientes
    pid_requests = obtenerPidRequest(dirServer, dir_clientes, nLectores, nEscritores, pid_permissions, exclude)
  ###  IO.puts("init: pid_requests")
  ###  IO.inspect pid_requests
  ###    IO.puts("-------------------------------------------------")
    #Lanzo remotamente en cada cliente el proceso que inicializa el cliente y ejecuta el lector/escritor
    pid_clientes = obtenerPidCliente(dirServer, dir_clientes, nLectores, nEscritores, pid_requests, pid_permissions, pid_requests, pid_permissions)
  ###  IO.puts("init: pid_clientes")
  ###  IO.inspect pid_clientes
  ###    IO.puts("-------------------------------------------------")
    #Ya existen todos los procesos cliente, les doy permiso para empezar a ejecutarse
    empezar(pid_clientes, nLectores + nEscritores)
  ###  IO.puts("init:FINAL")
  end

end




defmodule Cliente do
#TODO:
#      Cambiar estructura, en init otras dos instrucciones para node spawn de permission y eso...

##################################################################################################
############################### MUTEX + VARIABLES_GLOBALES #######################################     PROCESO 1
##################################################################################################
  #Mutex para gestionar concurrencia (1)y(2) con (11) en el algoritmo de Ricart Agrawala
  def mutex do
    receive do
      {pid, :coger_mutex} -> send(pid,{:ok_mutex, self()})
                            ###  IO.puts("mutex: recibido coger")
    end
    receive do
      {pid, :soltar_mutex} -> ###IO.puts("mutex: recibido soltar")
                              mutex()
    end
  end

  #Mantiene el estado de las variables globales                                                        PROCESO 2
  def variables_globales ({state, clock, lrd, perm_delayed}) do
    ### IO.puts("variables_globales: state #{state}, clock=#{clock}, lrd=#{lrd}")
      #state=0 -> out, state=1 -> trying, state=2 -> in
      {state_new, clock_new, lrd_new, perm_delayed_new} = receive do
          {pid, :write_state, update} ->  {update, clock, lrd, perm_delayed}
          {pid, :write_clock, update} ->  {state, update, lrd, perm_delayed}
          {pid, :write_lrd, update} ->    {state, clock, update, perm_delayed}
          #------------------------------------------------------
          {pid, :read_state} -> send(pid, {:ok_read_state, state}); {state, clock, lrd, perm_delayed}
          {pid, :read_clock} -> send(pid, {:ok_read_clock, clock}); {state, clock, lrd, perm_delayed}
          {pid, :read_lrd} -> send(pid, {:ok_read_lrd, lrd}); {state, clock, lrd, perm_delayed}
          #-----------------------------------------------------
          {pid, :add_perm_delayed, process} -> {state, clock, lrd, perm_delayed ++ process}
          {pid, :read_perm_delayed} -> send(pid, {:ok_read_perm_delayed, perm_delayed}); {state, clock, lrd, perm_delayed}
          {pid, :reset_perm_delayed} -> {state, clock, lrd, []}
      end
      variables_globales({state_new, clock_new, lrd_new, perm_delayed_new})
 end

###########################################################################################
############################### INICIALIZAR CLIENTE #######################################                    PROCESO 3
###########################################################################################
  #Levanta un escritor y lo conecta al servidor
  def initEscritor(dir_server, identificador, pid_requests, pid_permissions, pid_request, pid_permission) do

    #Conectar con servidor
    Node.connect(dir_server)
    receive do
      {pid, :empezar} ->      pid_mutex = spawn(fn ->  Process.register(self(), :mutex)
                                                       mutex() end)
                              spawn(fn -> Process.register(self(),:variables)
                                          variables_globales({0, 0, 0, []}) end)
                              Process.register( self(), :cliente)
                              escritor(dir_server,pid_mutex,pid_requests, pid_permissions,pid_request, pid_permission, identificador, 0, 1)
    end
  end

  #Levanta un lector y lo conecta al servidor
  def initLector(dir_server,identificador, pid_requests, pid_permissions, pid_request, pid_permission) do
     #Conectar con servidor
     Node.connect(dir_server)
     receive do
       {pid, :empezar} ->      pid_mutex = spawn(fn ->  Process.register(self(), :mutex)
                                                        mutex() end)
                               spawn(fn -> Process.register(self(),:variables)
                                           variables_globales({0, 0, 0, []}) end)
                               Process.register( self(), :cliente)
                               lector(dir_server,pid_mutex,pid_requests, pid_permissions,pid_request, pid_permission, identificador, 0, 0)
     end
  end


####################################################################################
############################### LECTOR/ESCRITOR ####################################
####################################################################################
  def escritor(dir_server, pid_mutex, pid_requests, pid_permissions,pid_request, pid_permission, identificador, time, type_op) do
    IO.puts("escritor #{identificador}: REQUEST")
    begin_op( pid_mutex, pid_requests, pid_request,pid_permission, identificador, type_op)
  #  IO.puts("-------------------")
    IO.puts("escritor #{identificador}: ENTRAR")
    cond do
      time == 0 ->  send({:server, dir_server}, {:update_resumen, self(),"resumen" }) #;IO.puts("escritor #{identificador}: actualiza resumen")
      time == 1 ->  send({:server, dir_server}, {:update_principal, self(), "principal"})#;IO.puts("escritor #{identificador}: actualiza principal")
      time <= 2 ->  send({:server, dir_server}, {:update_entrega, self(), "entrega"})#; IO.puts("escritor #{identificador}: actualiza entrega")
    end
    receive do
        {:reply, :ok} -># IO.puts("escritor #{identificador} ha actualizado")
    end
       Process.sleep(:rand.uniform(1000) + 1000)

    IO.puts("escritor#{identificador}: SALIR ")
    #IO.puts("-------------------")
    end_op()
    escritor(dir_server, pid_mutex, pid_requests,pid_permissions, pid_request, pid_permission, identificador, rem(time + 1, 3), type_op)
  end

  def lector(dir_server, pid_mutex, pid_requests, pid_permissions,pid_request, pid_permission, identificador, time, type_op) do
    IO.puts("lector #{identificador}: REQUEST")
    begin_op( pid_mutex, pid_requests, pid_request,pid_permission, identificador, type_op)
    #  IO.puts("-------------------")
    IO.puts("lector #{identificador}: ENTRAR")
    cond do
      time == 0 ->  send({:server, dir_server}, {:read_resumen, self()});  #IO.puts("lector #{identificador}: Leer resumen")
      time == 1 ->  send({:server, dir_server}, {:read_principal, self()});#IO.puts("lector #{identificador}: Leer principal")
      time <= 2 ->  send({:server, dir_server}, {:read_entrega, self()}); #IO.puts("lector #{identificador}: Leer entrega")
    end
    receive do
        {:reply, descripcion} -> #IO.puts("lector #{identificador} ha leido: " <> descripcion)
    end
       Process.sleep(:rand.uniform(1000) + 1000)

    IO.puts("lector#{identificador}: SALIR ")
  #  IO.puts("-------------------")
    end_op()
    lector(dir_server, pid_mutex, pid_requests,pid_permissions, pid_request, pid_permission, identificador, rem(time + 1, 3), type_op)
  end

####################################################################################
############################### RICART AGRAWALA ####################################
####################################################################################

  def send_request(1, pids,lrd,pid_request,pid_permission, identificador, op_type) do
    if hd(pids) != pid_request do
      #IO.inspect self()
      send(hd(pids), {:request,pid_permission, lrd, identificador, op_type})
    end
  end

  def send_request(n, pids,lrd, pid_request,pid_permission, identificador, op_type) when n > 1 do
    if hd(pids) != pid_request do
      send(hd(pids), {:request, pid_permission, lrd, identificador, op_type})
    end
    send_request(n - 1, tl(pids),lrd, pid_request,pid_permission, identificador, op_type)
  end

  def send_permission(1, pids) do
     if hd(pids) != self() do
      send(hd(pids), {:permission, self()})
    end
  end

def send_permission(n, pids) when n > 1 or n == 0 do
   if n != 0 do
    send(hd(pids), {:permission, self()})
    send_permission(n - 1, tl(pids))
  end
end


  #Operacion para obtener el mutex distribuido
  def begin_op( pid_mutex, pid_requests,pid_request, pid_permission, identificador, type_op) do
      #Pido mutex
      send(pid_mutex, {self(), :coger_mutex})
      #Actualizo estado, leo clock y actualizo lrd
      clock=receive do
        {:ok_mutex,pid} ->  send({:variables,node},{self(), :write_state, 1})
                            send({:variables,node},{self(), :read_clock})
                            clock = receive do
                              {:ok_read_clock, clock} ->
                                                         clock
                            end
                            send({:variables,node},{self(), :write_lrd, clock + 1})
                            clock
      end
      #Dejo mutex
      send(pid_mutex, {self(), :soltar_mutex})
      #Envío request a los demás clientes para entrar a la S.C
      ###IO.puts("rbegin_op: cliente #{identificador} mandando peticion")
      send_request(length(pid_requests), pid_requests,clock + 1, pid_request,pid_permission, identificador, type_op)
      #Espero a que el proceso que espera los replies de los demás clientes me de permiso
      send(pid_permission,{:entrar, self()})
      receive do
        {pid, :ok_seccion_critica} -> ###IO.puts("begin_op: cliente #{identificador} Recibido permiso de permission para entrar")
      end
      send({:variables,node},{self(), :write_state, 2});
  end


  #Operación para soltar el mutex distribuido
  def end_op() do
      send({:variables,node},{self(), :write_state, 0})
      send({:variables,node},{self(), :read_perm_delayed})
      perm_delayed = receive do
          {:ok_read_perm_delayed, perm_delayed} ->
                                                   perm_delayed
      end
      send({:variables,node},{self(), :reset_perm_delayed})
      send_permission(length(perm_delayed), perm_delayed)
  end


  def request(pid_permissions, identificador, matriz, type_op) do
    receive do
      {:request,pid, k, j, op_t} ->      send({:variables,node},{self(), :read_clock})
                                     clock = receive do
                                          {:ok_read_clock, clock} ->
                                                                     clock
                                     end
                                     send({:variables,node}, {self(),:write_clock, max(clock, k)})

                                     #Pido mutex
                                     send({:mutex,node}, {self(), :coger_mutex})
                                     #Actualizo estado, leo clock y actualizo lrd
                                     {state, lrd} = receive do
                                        {:ok_mutex,pid} ->  send({:variables,node},{self(), :read_state})
                                                            state = receive do
                                                                {:ok_read_state, state} ->
                                                                                           state
                                                            end
                                                            send({:variables,node}, {self(), :read_lrd})
                                                            lrd = receive do
                                                                {:ok_read_lrd, lrd} ->
                                                                                       lrd
                                                            end
                                                            {state, lrd}
                                     end
                                     #Dejo mutex
                                     send({:mutex,node}, {self(), :soltar_mutex})
                                     #IO.puts("request: state= #{state}, lrd= #{lrd},clock=#{clock}, k= #{k}, identificador=#{identificador}, j=#{j}, type_op=#{type_op}, op_t=#{op_t}")
                                     prio = (state != 0) and ((lrd < k) or ((lrd == k) and (identificador < j))) and elem(elem(matriz,type_op),op_t)
                                     if prio do
                                      # IO.puts("request: #{identificador} NO doy permiso, mi lrd=#{lrd}, el otro=#{k}")
                                       send({:variables,node}, {self(), :add_perm_delayed, [pid]}); #IO.puts("request: Añadiendo--> #{j}");
                                     else
                                      # IO.puts("request: #{identificador} doy permiso, mi lrd=#{lrd}, el otro=#{k}")
                                       send(pid, {:permission, self()})
                                     end
    end
    request(pid_permissions, identificador, matriz, type_op)
  end

  def permission(nClientes, nClientes_copia) do #ARREGLAR
  ###  IO.puts("permission: INICIO")
    if nClientes_copia == 1 do

      receive do
        {:entrar, pid} -> send({:cliente, node}, {self(), :ok_seccion_critica})
                          permission(nClientes_copia, nClientes_copia)
      end
    else
        if nClientes > 1 do
            receive do
                {:permission, pid} ->
                                   permission(nClientes - 1, nClientes_copia)
            end
        else
          receive do
                {:entrar, pid} -> send({:cliente, node}, {self(), :ok_seccion_critica})
                                  permission(nClientes_copia, nClientes_copia)
          end
        end
      end
  end
end
