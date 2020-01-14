Code.require_file("#{__DIR__}/cliente_gv.exs")

defmodule ServidorSA do

    # estado del servidor
    defstruct  base_datos: %{},
               estado: :init,
               vista: %{:num_vista => 0, :primario => :undefined, :copia => :undefined},
               valida: false
    @tiempo_espera_de_respuesta 50
    @tiempo_espera_a_copia 30
    @intervalo_latido 50

# ERRROR RARO ROJO Y COMPROBAR LECTURAS EN CLIENTE GV
#
#
#
#
    @doc """
        Obtener el hash de un string Elixir
            - Necesario pasar, previamente,  a formato string Erlang
         - Devuelve entero
    """
    def hash(string_concatenado) do
        String.to_charlist(string_concatenado) |> :erlang.phash2
    end

    @doc """
        Poner en marcha el servidor para gestión de vistas
        Devolver atomo que referencia al nuevo nodo Elixir
    """
    @spec startNodo(String.t, String.t) :: node
    def startNodo(nombre, maquina) do
                                         # fichero en curso
        NodoRemoto.start(nombre, maquina, __ENV__.file)
    end

    @doc """
        Poner en marcha servicio trás esperar al pleno funcionamiento del nodo
    """
    @spec startService(node, node) :: pid
    def startService(nodoSA, nodo_servidor_gv) do
        NodoRemoto.esperaNodoOperativo(nodoSA, __MODULE__)

        # Poner en marcha el código del gestor de vistas
        Node.spawn(nodoSA, __MODULE__, :init_sa, [nodo_servidor_gv])
   end

    #------------------- Funciones privadas -----------------------------

    def init_sa(nodo_servidor_gv) do
        Process.register(self(), :servidor_sa)
        estadoSA = %ServidorSA{}
        spawn(__MODULE__, :monitor, [self()])

    #------------- VUESTRO CODIGO DE INICIALIZACION AQUI..........


         # Poner estado inicial
        #bucle_recepcion_principal(???)
        IO.puts("servidor_sa INICIADO")
        bucle_recepcion_principal(estadoSA, nodo_servidor_gv)
    end


    defp bucle_recepcion_principal(estadoSA, nodo_servidor_gv) do
        new_estadoSA = receive do

                  #Solicitud para mandar latido al gestor de vistas
                  {:late} ->
                        IO.puts("recibido late")
                        new_estadoSA = procesa_late(nodo_servidor_gv, estadoSA)
                        # IO.puts("BUCLE despues de procesa_late")
                        # IO.inspect new_estadoSA
                            new_estadoSA = comprobar_si_soy_copia(nodo_servidor_gv, new_estadoSA)
                        
                        # IO.puts("BUCLE despues de comprobar_si_soy_copia")
                        # IO.inspect new_estadoSA


                  #Solicitud para transferir la base de datos al nodo copia
                  {:transf_total, pid_copia} ->
                          IO.puts("bucle: transf_total, primario recibe orden de transferir todo a la copia")
                          {vista, valida} = ClienteGV.latido(nodo_servidor_gv, estadoSA.vista.num_vista)

                          new_estadoSA = Map.put(estadoSA, :vista, vista)
                          if new_estadoSA.vista.primario == Node.self() do
                            new_estadoSA = procesa_transf_total(nodo_servidor_gv, new_estadoSA, pid_copia)

                          else
                            IO.puts("ERROR: bucle: transf_total: No soy primario")
                            estadoSA
                          end

                  #Solicitud de copia de operacion ejecutada en primario
                  {:transf_parcial, id_primario, param} ->
                          if id_primario == estadoSA.vista.primario and
                                    estadoSA.vista.copia == Node.self() do
                            IO.puts("bucle: transf_parcial, copia recibe orden de escritura del primario")
                            new_estadoSA = procesa_transf_parcial(estadoSA, :escribe_generico, param)
                            send({:servidor_sa, id_primario}, {:ok_solicitud})
                            IO.puts("BUCLE COPIA")
                            IO.inspect new_estadoSA
                            new_estadoSA
                          else
                            IO.puts("ERROR: bucle: transf_parcial")
                            estadoSA
                          end


                  {op, param, nodo_origen}  ->
                          IO.puts("BUCLE ANTES DE PROCESAR OPERACION")
                          IO.inspect estadoSA
                          IO.puts("recibido de ")
                          IO.inspect nodo_origen
                          IO.inspect op
                          IO.inspect param
                          new_estadoSA = procesa_operacion(estadoSA, op, param, nodo_origen)
                          IO.puts("BUCLE DESPUES DE PROCESAR OPERACION")
                          IO.inspect new_estadoSA

                          new_estadoSA
               end

        bucle_recepcion_principal(new_estadoSA, nodo_servidor_gv)
    end

    #--------- Otras funciones privadas que necesiteis .......

    #Proceso secundario que envía periódicamente peticiones al proceso principal
    #para que envíe latidos al gestor de vistas
    def monitor(pid_servidor_sa) do
      send(pid_servidor_sa, {:late})
      Process.sleep(@intervalo_latido)
      monitor(pid_servidor_sa)
    end

    #Procesa una operacion de escritura o lectura si el nodo es el primario
    #Procesa una operacion de lectura si el nodo es la copia
    #Devuelve el estadoSA actualizado
    def procesa_operacion(estadoSA, op, param, nodo_origen) do
      # IO.puts("INIT procesa_operacion")
      # IO.puts("------------------------------")
      # IO.puts("estadoSA->")
      # IO.inspect estadoSA
      # IO.puts("parametros->")
      # IO.inspect op
      # IO.inspect param
      # IO.inspect nodo_origen
      # IO.puts("------------------------------")
        new_estado = cond do
          estadoSA.vista.primario == Node.self() ->
                  IO.puts("procesa_operacion: soy primario")
                  #Primario transita a estado de tramitando solicitud
                  new_estadoSA = Map.put(estadoSA, :estado, :transf_prim)
                  new_estadoSA = procesa_operacion_primario(new_estadoSA, op, param, nodo_origen)
                  #Primario transita a estado inicial tras procesar la solicitud tanto el como la copia (si es necesario)
                  new_estadoSA = Map.put(new_estadoSA, :estado, :init)
          estadoSA.vista.copia == Node.self() ->
                  IO.puts("procesa_operacion: soy copia")
                  procesa_operacion_copia(estadoSA, op, param, nodo_origen)
                  estadoSA
          true -> send({:cliente_sa, nodo_origen}, {:resultado, :soy_nodo_en_espera})
                  estadoSA



        end
      # IO.puts("FIN procesa_operacion: nuevo estado ->")
      # IO.inspect estadoSA


      new_estado
    end

    #Genera un latido hacia el gestor de vistas con un número de vista que depende
    #de si el nodo es primario, copia o espera y de si la ultima vista que tiene el nodo
    #es valida o no.
    def procesa_late(nodo_servidor_gv, estadoSA) do
      #IO.puts("------INICIO--------")
      #IO.inspect estadoSA
      {vista, valida} = if estadoSA.valida or estadoSA.vista.primario != Node.self() do
           #IO.puts("IF")
           {vista, valida} = ClienteGV.latido(nodo_servidor_gv, estadoSA.vista.num_vista)
           IO.inspect vista
           {vista, valida}

      else
        #IO.puts("ELSE")
        #nodo es primario y vista no valida
           # {vista, valida} = cond do
           #      estadoSA.vista.num_vista == 0 ->
           #          #primer latido
           #          IO.puts("numvista = 0")
           #          {vista, valida} = ClienteGV.latido(nodo_servidor_gv, 0)
           #          {vista, valida}
           #      estadoSA.vista.num_vista > 0 ->
           #        IO.puts("numVista > 0")
                    #latido cuando la vista no es válida
           {vista, valida} = ClienteGV.latido(nodo_servidor_gv, -1)
           {vista, valida}
          #  end
      end
      #Se actualiza el estado de la vista
      new_estadoSA = Map.put(estadoSA, :vista, vista) |> Map.put(:valida, valida)
      # IO.puts("--------FINAL---------")
      # IO.inspect new_estadoSA

      new_estadoSA
    end

    #El nodo primario transfiere su base de datos a el nodo copia (pid_copia)
    #Devuelve estadoSA actualizado
    def procesa_transf_total(nodo_servidor_gv, estadoSA, pid_copia) do
      #IO.puts("INIT procesa_transf_total")
          if estadoSA.vista.primario == Node.self() do
            #primario transita a estado de transferencia de bd
            new_estadoSA = Map.put(estadoSA, :estado, :transf_prim)
            new_estadoSA = transfiere_a_copia(nodo_servidor_gv, pid_copia, new_estadoSA)
            #Primario vuelve a estado inicial
            new_estadoSA = Map.put(new_estadoSA, :estado, :init)
            IO.inspect new_estadoSA

            new_estadoSA
          else
            IO.puts("ERROR: procesa_transf_total")
            estadoSA
          end
    end

    #Ejecuta op, que es una operacion transferida del primario a la copia
    #Devuelve una tupla con el estado actualizado y el valor devuelto
    def procesa_transf_parcial(estadoSA, op, param) do
       {new_estadoSA, valor} = operacion(estadoSA, :escribe_generico, param)
       new_estadoSA
    end

    #El nodo primario transfiere su base de datos a el nodo copia (pid_copia)
    #y valida vista. Devuelve estadoSA actualizado
    def transfiere_a_copia(nodo_servidor_gv, pid_copia, estadoSA) do
      IO.puts("INIT procesa_transfiere_a_copia")
      #Se envía la BD a la copia
          send(pid_copia, {:bd, estadoSA.base_datos})
          {vista, valida} = receive do
                                {:ok_transf} ->  #Se recibe confirmación de la copia
                                      #realizamos latido al servidor_gv con último número de vista para que valide la vista actual
                                      IO.puts("procesa_transfiere_a_copia: recivo ok_transf de la copia")
                                      ClienteGV.latido(nodo_servidor_gv, -1) #Pedimos la vista tentativa al gestor de vistas
          end
          IO.puts("AQUIII: ")
          IO.inspect vista.num_vista
          {vista, valida} = ClienteGV.latido(nodo_servidor_gv, vista.num_vista) #validamos vista
          #Se actualiza el estado de la vista
          new_estadoSA = Map.put(estadoSA, :vista, vista) |> Map.put(:valida, valida)
          IO.puts("procesa_transfiere_a_copia:nuevo estado->")
          IO.inspect estadoSA

          new_estadoSA
    end

    #Si nodo_servidor_gv es el nodo copia y la vista no es válida,
    #le pide al primario que le transfiera una copia exacta de su base de datos
    #y devuelve el estadoSA actualizado, en caso contrario no hace nada
    def comprobar_si_soy_copia(nodo_servidor_gv, estadoSA) do
      IO.puts("------INIT comprobar_si_soy_copia")
      #IO.inspect estadoSA
      if !estadoSA.valida and estadoSA.vista.copia == Node.self() do
        IO.puts("comprobar_si_soy_copia: IF")
        #si la vista no se ha validado compruebo si soy la copia para iniciar la transferencia de datos
        new_estadoSA = Map.put(estadoSA, :estado, :transf_copia)
        send({:servidor_sa, new_estadoSA.vista.primario}, {:transf_total, self()}) #Pide la transferencia de la bd al primario
        new_estadoSA = receive do
          {:bd, bd} -> #Copia recibe base_datos del primario y se la guarda
                IO.puts("comprobar_si_soy_copia: recibido bd del primario")
                IO.inspect bd
                new_estadoSA = Map.put(new_estadoSA, :base_datos, bd)
        end
        send({:servidor_sa, new_estadoSA.vista.primario}, {:ok_transf}) #Envía confirmación al primario
        new_estadoSA = Map.put(new_estadoSA, :estado, :init) #La copia transita a su estado inicial tras completar la transferencia de la bd
        IO.puts("------FINAL----")
      #  IO.inspect estadoSA
        new_estadoSA
      else
        estadoSA
      end
    end

  #Ejecuta una operación de lectura o escritura en nodo primario.
  #Si es de escritura además envía una transferencia de la operación
  #al nodo copia.
  #Devuelve el estadoSA actualizado
  def procesa_operacion_primario(estadoSA, op, param, nodo_origen) do
    IO.puts("INIT procesa_operacion_primario")
        #caso :no_soy_primario_valido?????????????????????
        # IO.puts("OPERACION DEL PRIMARIO-----------")
        # IO.inspect op
        # IO.inspect param
        # IO.inspect nodo_origen
        # IO.puts("RESULTADO:")
        # IO.inspect valor
        # IO.inspect estadoSA
        # IO.puts("---------------------------------")
        if op != :lee do
          #reenvía solicitud a la copia para que la procese
          send({:servidor_sa, estadoSA.vista.copia}, {:transf_parcial, Node.self(), param})
          new_estadoSA = receive do
                {:ok_solicitud} ->
                  IO.puts("procesa_solicitud_primario: copia confirma operacion")
                  {new_estadoSA, valor} = operacion(estadoSA, op, param)
                  send({:cliente_sa, nodo_origen}, {:resultado, valor}) #envía resultado al cliente
                  new_estadoSA
                after @tiempo_espera_a_copia ->
                        IO.puts("COPIA NO RESPONDE A REDIRECCION DE PETICION")
                        send({:cliente_sa, nodo_origen}, {:resultado, :no_soy_primario_valido})
                        estadoSA
                end

        else
          {new_estadoSA, valor} = operacion(estadoSA, op, param)
          send({:cliente_sa, nodo_origen}, {:resultado, valor}) #envía resultado al cliente
          new_estadoSA
        end
  end

  #Ejecución de una operación de lectura en un nodo copia
  #DNo devuelve nada
  def procesa_operacion_copia(estadoSA, op, param, nodo_origen) do
    IO.puts("INIT procesa_operacion_copia")
        #caso :no_soy_primario_valido?????????????????????
        IO.puts("OPERACION DE LA COPIA-----------")
        IO.inspect op
        IO.inspect param
        IO.inspect nodo_origen

        if op == :lee do #Solo admite lecturas
          {new_estadoSA, valor} = operacion(estadoSA, op, param)
          send({:cliente_sa, nodo_origen}, {:resultado, valor}) #envía resultado al cliente
          IO.puts("RESULTADO:")
          IO.inspect valor
          IO.puts("---------------------------------")
        else
          IO.puts("procesa_operacion_copia: ERROR, operacion no es leer")
        end
  end

  #Devuelve una tupla con el estado actualizado resultante de ejecutar la operacion
  #op sobre estadoSA.base_datos y el valor resultante de la operacion
  def operacion(estadoSA, op, param) do
    {new_estadoSA, valor} = if op == :lee do #leer, #param = clave
          valor = leer(estadoSA, param)
          {estadoSA, valor}
    else  # escribir, param = {clave, nuevo_valor, con_hash}
          clave = elem(param, 0)
          nuevo_valor = elem(param, 1)
          con_hash = elem(param, 2)
          if op == :escribe_generico and con_hash do
              {new_estadoSA, valor} = escribe_hash(estadoSA, clave, nuevo_valor)
          else if  op == :escribe_generico and !con_hash do
              {new_estadoSA, valor} = escribe(estadoSA, clave, nuevo_valor)
          else
              IO.puts("ERROR: operacion desconocida")
              {estadoSA, ""}
          end end
    end
    {new_estadoSA, valor}
  end

  #Devuelve el valor asociado a la clave en estadoSA.base_datos o ""
  #si no existe la clave
  def leer(estadoSA, clave) do
    resul = if Map.has_key?(estadoSA.base_datos, clave) do
        resul = Map.get(estadoSA.base_datos, clave)
    else
        resul = ""
    end
    resul
  end

  #Actualiza en estadoSA.base_datos el valor asociado a clave
  #con el valor obtenido de ejecutar hash(antiguo_valor <> nuevo_valor)
  #Devuelve una tupla con estadoSA actualizado y
  # antiguo_valor si existe, o "" si no hay valor previo
  def escribe_hash(estadoSA, clave, nuevo_valor) do
     clave = to_string(clave)
     nuevo_valor = to_string(nuevo_valor)
     if Map.has_key?(estadoSA.base_datos, clave) do
       antiguo_valor = Map.get(estadoSA.base_datos, clave)
       new_estadoSA = Map.put(estadoSA, :base_datos, Map.put(estadoSA.base_datos,clave, to_string(hash(Map.get(estadoSA.base_datos, clave) <> nuevo_valor))))
       {new_estadoSA, antiguo_valor}
    else
      new_estadoSA = Map.put(estadoSA, :base_datos, Map.put_new(estadoSA.base_datos,clave, to_string(hash("" <> nuevo_valor))))
      {new_estadoSA, ""}
    end
  end

  #Actualiza en estadoSA.base_datos el valor asociado a clave con nuevo_valor,
  #si no existe clave, añade pareja (clave, nuevo_valor)
  #Devuelve una tupla con estadoSA actualizado y nuevo_valor
def escribe(estadoSA, clave, nuevo_valor) do
  clave = to_string(clave)
  nuevo_valor = to_string(nuevo_valor)
  if Map.has_key?(estadoSA.base_datos, clave) do
    new_estadoSA = Map.put(estadoSA, :base_datos, Map.put(estadoSA.base_datos,clave, nuevo_valor))
    {new_estadoSA, nuevo_valor}
  else
    new_estadoSA = Map.put(estadoSA, :base_datos, Map.put_new(estadoSA.base_datos,clave, nuevo_valor))
    {new_estadoSA, nuevo_valor}
  end
end


end
