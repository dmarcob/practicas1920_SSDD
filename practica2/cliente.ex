# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: cliente.ex
# FECHA: 27-09-2019
# DESCRIPCIÓN: Código de los lectores y escritores

defmodule Cliente do


############################### MUTEX + VARIABLES_GLOBALES #######################################     PROCESO 1
  #Mutex para gestionar concurrencia (1)y(2) con (11) en el algoritmo de Ricart Agrawala
  def mutex do
    receive do
      {pid, :coger_mutex} -> send(pid, :ok_mutex)
    end
    receive do
      {pid, :soltar_mutex} -> mutex()
    end
  end

  #Mantiene el estado de las variables globales
  def variables_globales (state, lrd) do
      #state=0 -> out, state=1 -> trying, state=2 -> in
      receive do
          {pid, :set, state_new, lrd_new} -> send(pid, :ok_set)
                                             variables_globales(state_new, lrd_new)
      end
 end
############################### INICIALIZAR #######################################
  #Levanta un escritor y lo conecta al servidor
  def initEscritor(dirServer, nClientes) do
    #COMPLETAR
  end

  #Levanta un lector y lo conecta al servidor
  def initLector(dirServer, nClientes) do
     #añadir cookie
     Node.set_cookie(:cookie123)
     #Conectar con servidor
     Node.connect(dirServer)
     pid_mutex = spawn(fn -> mutex() end)
     pid_variables = spawn(fn -> variables_globales(0, 1) end)
     lector(pid_mutex, pid_variables,0, 1)

  end

############################### LECTOR/ESCRITOR ####################################
  def escritor do
    #COMPLETAR
  end

  def lector(pid_mutex, pid_variables, state, lrd) do

    # spawn( fn -> REQUEST end)
    # spawn( fn -> PERMISION end)
    # begin_op(pid_mutex, pid_variables)
    #SECCION CRITICA
    #end_op()
  end

############################### RICART AGRAWALA ###################################




  #Operacion para obtener el mutex distribuido
  def begin_op(pid_mutex, pid_variables) do
      #cs_statei <- trying; lrdi <-clocki + 1;
      send(pid_mutex, {self(), :coger_mutex})
      send(pid_variables, {:set, 1, 1})
      send(pid_mutex, {self(), :soltar_mutex})
      #waiting fromi <-Ri: %Ri={1...n} \ {i}                              #TODO: Implementar esperar a todos los cliente ¡s para ver cuantos somos LOL

  end
end
