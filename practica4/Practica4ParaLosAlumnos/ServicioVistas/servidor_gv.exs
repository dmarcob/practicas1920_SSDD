require IEx # Para utilizar IEx.pry

defmodule ServidorGV do
    @moduledoc """
        modulo del servicio de vistas
    """

    # Tipo estructura de datos que guarda el estado del servidor de vistas
    # COMPLETAR  con lo campos necesarios para gestionar
    # el estado del gestor de vistas
    defstruct   vista_t:  %{:num_vista => 0, :primario => :undefined, :copia => :undefined},
                vista_v:  %{:num_vista => 0, :primario => :undefined, :copia => :undefined},
                nodos_espera: [],
                valida: false,
                estado: :wait_primario


    # Constantes
    @latidos_fallidos 4

    @intervalo_latidos 50


    @doc """
        Acceso externo para constante de latidos fallios
    """
    def latidos_fallidos() do
        @latidos_fallidos
    end

    @doc """
        acceso externo para constante intervalo latido
    """
   def intervalo_latidos() do
       @intervalo_latidos
   end

   @doc """
        Generar un estructura de datos vista inicial
    """
    def vista_inicial() do
        %{:num_vista => 0, :primario => :undefined, :copia => :undefined}
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
    @spec startService(node) :: boolean
    def startService(nodoElixir) do
        NodoRemoto.esperaNodoOperativo(nodoElixir, __MODULE__)

        # Poner en marcha el código del gestor de vistas
        Node.spawn(nodoElixir, __MODULE__, :init_sv, [])
   end

    #------------------- FUNCIONES PRIVADAS ----------------------------------

    # Estas 2 primeras deben ser defs para llamadas tipo (MODULE, funcion,[])
    def init_sv() do
        Process.register(self(), :servidor_gv)

        spawn(__MODULE__, :init_monitor, [self()]) # otro proceso concurrente

        estadoGV = %ServidorGV{}

        bucle_recepcion(estadoGV, 0, 0)
    end

    def init_monitor(pid_principal) do
        send(pid_principal, :procesa_situacion_servidores)
        Process.sleep(@intervalo_latidos)
        init_monitor(pid_principal)
    end


    defp bucle_recepcion(estadoGV, timeouts_primario, timeouts_copia) do
      {new_estadoGV, timeouts_primario, timeouts_copia } = receive do
                    {:latido, n_vista_latido, nodo_emisor} ->
                       procesar_latido(estadoGV,timeouts_primario, timeouts_copia, n_vista_latido, nodo_emisor)

                    {:obten_vista_valida, pid} ->
                        send(pid,{:vista_valida, estadoGV.vista_v, estadoGV.valida})
                        {estadoGV, timeouts_primario, timeouts_copia }

                    :procesa_situacion_servidores ->
                        procesar_situacion_servidores(estadoGV,timeouts_primario + 1, timeouts_copia + 1)
        end

      bucle_recepcion(new_estadoGV,timeouts_primario, timeouts_copia)
    end

    # OTRAS FUNCIONES PRIVADAS VUESTRAS
    def procesar_latido(estadoGV,timeouts_primario, timeouts_copia, n_vista_latido, nodo_emisor) do
      case estadoGV.estado do
        :wait_primario ->
              new_vista_t = Map.update!(estadoGV.vista_t, :num_vista, &(&1 + 1))
              |> Map.put(:primario, nodo_emisor)
              new_estadoGV = Map.put(estadoGV, :vista_t, new_vista_t)
              |> Map.put(:estado, :wait_copia)
              send({:cliente_gv, nodo_emisor}, {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida})
              {new_estadoGV,0, 0}

        :wait_copia ->
              if nodo_emisor != estadoGV.vista_t.primario do
                      {new_estadoGV,timeouts_primario, 0} = cond do
                            estadoGV.vista_t.copia == :undefined ->
                                #nodo_espera pasa a copia
                                new_vista_t = Map.update!(estadoGV.vista_t, :num_vista, &(&1 + 1))
                                |> Map.put(:copia, nodo_emisor)
                                new_estadoGV = Map.put(estadoGV, :vista_t, new_vista_t)
                                send({:cliente_gv, nodo_emisor}, {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida})
                                {new_estadoGV,timeouts_primario, 0}

                            estadoGV.vista_t.copia == nodo_emisor ->
                                if n_vista_latido == 0 do
                                    #Caida rapida copia
                                    new_estadoGV = caida_copia(estadoGV)
                                    send({:cliente_gv, nodo_emisor}, {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida})
                                    {new_estadoGV,timeouts_primario, 0}
                                else
                                    #latido de copia
                                    send({:cliente_gv, nodo_emisor}, {:vista_tentativa, estadoGV.vista_t, estadoGV.valida})
                                    {estadoGV,timeouts_primario, 0}
                                end
                            true ->
                                #Añadir nodo en espera
                                new_estadoGV = Map.update!(estadoGV, :nodos_espera, &(&1 ++ [5]))
                                {estadoGV,timeouts_primario, timeouts_copia}
                      end
              else #nodo_emisor = primario
                    cond do
                            n_vista_latido == -1 ->
                                send({:cliente_gv, nodo_emisor}, {:vista_tentativa, estadoGV.vista_t, estadoGV.valida})
                                {estadoGV,0, timeouts_copia}

                            n_vista_latido == 0 and estadoGV.vista_t.copia != :undefined ->
                                #Caida rapida primario
                                new_estadoGV = caida_primario(estadoGV)
                                send({:cliente_gv, nodo_emisor}, {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida})
                                {new_estadoGV,0, timeouts_copia}

                            n_vista_latido == 0 and estadoGV.vista_t.copia == :undefined ->
                                new_vista_t = Map.put(estadoGV.vista_t, :num_vista, 0)
                                |> Map.put(:primario, :undefined)
                                new_estadoGV = Map.put(estadoGV, :vista_t, new_vista_t)
                                |> Map.put(:estado, :wait_primario)
                                send({:cliente_gv, nodo_emisor}, {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida})
                                {new_estadoGV,timeouts_primario, timeouts_copia}

                           true ->
                                #valido vista y voy a VALIDADO
                                new_estadoGV = Map.put(estadoGV, :vista_v, estadoGV.vista_t)
                                |> Map.put(:valida, true)
                                |> Map.put(:estado, :validado)
                                send({:cliente_gv, nodo_emisor}, {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida})
                                {new_estadoGV,0, timeouts_copia}
                    end
              end

       end
    end

    def procesar_situacion_servidores(estadoGV, timeouts_primario, timeouts_copia) do   #ME QUEDO AQUI
      case estadoGV.estado do
        :wait_primario ->
          {estadoGV,timeouts_primario, timeouts_copia }
        :wait_copia ->
          if timeouts_primario and estadoGV.vista_t.primario != :undefined do
            caida_primario(estadoGV)
                                        #ME QUEDO AQUI
          end
          {estadoGV,timeouts_primario, timeouts_copia }
      end
      {estadoGV,timeouts_primario, timeouts_copia }

    end

    def caida_copia(estadoGV) do
      if estadoGV.nodos_espera == [] do
         new_vista_t = Map.update!(estadoGV.vista_t, :num_vista, &(&1 + 1))
         |> Map.put(:copia, :undefined)
         Map.put(estadoGV, :vista_t, new_vista_t)
      else

         new_vista_t = Map.update!(estadoGV.vista_t, :num_vista, &(&1 + 1))
         |> Map.put(:copia, hd(estadoGV.nodos_espera))
         Map.put(estadoGV, :vista_t, new_vista_t)
         |> Map.put(:nodos_espera, tl(estadoGV.nodos_espera))
      end
    end

    def caida_primario(estadoGV) do
      if estadoGV.nodos_espera == [] do
         new_vista_t = Map.update!(estadoGV.vista_t, :num_vista, &(&1 + 1))
         |> Map.puts(:primario, estadoGV.vista_t.copia)
         |> Map.put(:copia, :undefined)
         Map.put(estadoGV, :vista_t, new_vista_t)

      else
         new_vista_t = Map.update!(estadoGV.vista_t, :num_vista, &(&1 + 1))
         |> Map.puts(:primario, copia)
         |> Map.put(:copia, hd(estadoGV.nodos_espera))
         Map.put(estadoGV, :vista_t, new_vista_t)
         |> Map.put(:nodos_espera, tl(estadoGV.nodos_espera))
      end
    end
    # def update_vista_t(estadoGV, campo, valor) do
    #   new_vista_t = if campo == :num_vista do
    #       Map.update!(estadoGV.vista_t, campo, &(&1 + 1))
    #   else
    #       #update primario o copia
    #       Map.put(estadoGV.vista_t, campo, valor)
    #   end
    #   new_estadoGV = Map.put(estadoGV, :vista_t, new_vista_t)
    # end
    #
    # def update_estado(estadoGV, estado) do
    #   Map.put(estadoGV, :estado, estado)
    # end
    #
    # def update_nodos_espera(estadoGV, nodo) do
    #   Map.update!(estadoGV, :nodos_espera, &(&1 ++ [5]))
    # end
    #
    # def validar_vista(estadoGV) do
    #   estadoGV = Map.put(estadoGV, :valida, true)
    #   estadoGV.vista_v = estadoGV.vista_t
    # end



end
