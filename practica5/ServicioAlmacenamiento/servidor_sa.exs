Code.require_file("#{__DIR__}/cliente_gv.exs")

defmodule ServidorSA do

    # estado del servidor
    defstruct  base_datos: %{},
               estado: :init,
               vista: %{:num_vista => 0, :primario => :undefined, :copia => :undefined}
               valida: 0

    @intervalo_latido 50


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
        bucle_recepcion_principal(estadoSA, nodo_servidor_gv)
    end


    defp bucle_recepcion_principal(estadoSA, nodo_servidor_gv) do
        #??? = receive do
        receive do

                    # Solicitudes de lectura y escritura
                    # de clientes del servicio alm.
                  {op, param, nodo_origen}  ->


                        # ----------------- vuestro código
                        send(nodo_origen, {:resultado, 2})

                  # --------------- OTROS MENSAJES QUE NECESITEIS
                  {:late} ->
                        Map.put(estadoSA, :estado, :trans_prim)
                        procesa_latido(nodo_servidor_gv, estadoSA)

                  {:transf_copy, pid} -> transfiere_a_copia(pid, estadoSA)

               end

        bucle_recepcion_principal(estadoSA, nodo_servidor_gv)
    end

    #--------- Otras funciones privadas que necesiteis .......
    def monitor(pid_servidor_sa) do
      send(pid_servidor_sa, :late)
      Process.sleep(@intervalo_latido)
      monitor(pid_servidor_sa)
    end

    def procesa_latido(nodo_servidor_gv, estadoSA) do
      if estadoSA.valida == 0 and estadoSA.vista.num_vista == 0 do
          {vista, valida} = ClienteGV.latido(nodo_servidor_gv, 0)
      else if estadoSA.valida == 0 and estadoSA.vista.num_vista > 0 do
        {vista, valida} = ClienteGV.latido(nodo_servidor_gv, -1)
      else
        {vista, valida} = ClienteGV.latido(nodo_servidor_gv, estadoSA.vista.num_vista)
      end end
      Map.put(estadoSA, :vista, vista)
      Map.put(estadoSA, :valida, valida)
    end

    def transfiere_a_copia(pid, estadoSA) do
      send(pid, estadoSA.base_datos)
      receive do
        {:ok_transf} ->           #NOS QUEDAMOS AQUI
      end
    end
end
