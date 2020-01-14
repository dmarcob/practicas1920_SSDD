Code.require_file("#{__DIR__}/servidor_gv.exs")

defmodule ClienteGV do

    @tiempo_espera_de_respuesta 50


    @doc """
        Solicitar al cliente que envie un ping al servidor de vistas
    """
    @spec latido(node, integer) :: ServidorGV.t_vista
    def latido(nodo_servidor_gv, num_vista) do
        send({:servidor_gv, nodo_servidor_gv}, {:latido, num_vista, Node.self()})

        receive do   # esperar respuesta del ping
            {:vista_tentativa, vista, encontrado?} ->  {vista, encontrado?}

            # otro -> IO.inspect otro
            #         IO.inspect Process.info(self(), :message_queue_len)
            #         exit(" ERROR: en funcion #latido# del modulo ClienteGV")


        after @tiempo_espera_de_respuesta ->
           IO.puts("latido: HA CADUCADO TIMEOUT")
           {ServidorGV.vista_inicial(), false}
        end
    end


    @doc """
        Solicitar al cliente que envie una petición de obtención de vista válida
    """
    @spec obten_vista(node) :: {ServidorGV.t_vista, boolean}
    def obten_vista(nodo_servidor_gv) do
      IO.puts("Obten_vista INIT")
      IO.inspect nodo_servidor_gv
       send({:servidor_gv, nodo_servidor_gv}, {:obten_vista_valida, self()})

        receive do   # esperar respuesta del ping
            {:vista_valida, vista, is_ok?} ->
                                          IO.puts("obten_vista:")
                                          IO.inspect vista
                                          {vista, is_ok?}

            _otro -> exit(" ERROR: en funcion #obten_vista# de modulo ClienteGV")

        after 50 ->
          IO.puts("obten_vista: HA CADUCADO TIMEOUT")



          {ServidorGV.vista_inicial(), false}
        end
    end


    @doc """
        Solicitar al cliente que consiga el primario del servicio de vistas
    """
    @spec primario(node) :: node
    def primario(nodo_servidor_gv) do
      IO.puts("primario INIT")
        resultado = obten_vista(nodo_servidor_gv)
        IO.puts("primario: MEDIO")
        case resultado do
            {vista, true} -> IO.inspect vista.primario
                            vista.primario
            {_vista, false} -> IO.puts("ERROR: vista invalida")
                              :undefined
            _ -> IO.puts("NO hace matching")
        end
    end
end
