# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario3.ex
# FECHA: 15-12-2019
# DESCRIPCIÓN: Servidor de vistas para una arquitectura primario/copia

defmodule ServidorGV do
  @moduledoc """
      modulo del servicio de vistas
  """

  # Tipo estructura de datos que guarda el estado del servidor de vistas
  # COMPLETAR  con lo campos necesarios para gestionar
  # el estado del gestor de vistas
  defstruct vista_t: %{:num_vista => 0, :primario => :undefined, :copia => :undefined},
            vista_v: %{:num_vista => 0, :primario => :undefined, :copia => :undefined},
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
  @spec startNodo(String.t(), String.t()) :: node
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

  # ------------------- FUNCIONES PRIVADAS ----------------------------------

  # Estas 2 primeras deben ser defs para llamadas tipo (MODULE, funcion,[])
  def init_sv() do
    Process.register(self(), :servidor_gv)
    # otro proceso concurrente
    spawn(__MODULE__, :init_monitor, [self()])
    estadoGV = %ServidorGV{}
    bucle_recepcion(estadoGV, 0, 0)
  end

  def init_monitor(pid_principal) do
    send(pid_principal, :procesa_situacion_servidores)
    Process.sleep(@intervalo_latidos)
    init_monitor(pid_principal)
  end

  defp bucle_recepcion(estadoGV, timeouts_primario, timeouts_copia) do
    {new_estadoGV, timeouts_primario, timeouts_copia} =
      receive do
        {:obten_vista_valida, pid} ->
          send(pid, {:vista_valida, estadoGV.vista_v, estadoGV.valida})
          {estadoGV, timeouts_primario, timeouts_copia}

        {:latido, n_vista_latido, nodo_emisor} ->
          procesar_latido(estadoGV, timeouts_primario, timeouts_copia,
          n_vista_latido, nodo_emisor)

        :procesa_situacion_servidores ->
          procesar_situacion_servidores(estadoGV, timeouts_primario + 1, timeouts_copia + 1)
      end

    bucle_recepcion(new_estadoGV, timeouts_primario, timeouts_copia)
  end

  # OTRAS FUNCIONES PRIVADAS VUESTRAS
  def procesar_latido(estadoGV, timeouts_primario, timeouts_copia, n_vista_latido, nodo_emisor) do
    case estadoGV.estado do
      :wait_primario ->
        new_estadoGV =
          update_estadoGV(estadoGV, [
            {:num_vista},
            {:primario, nodo_emisor},
            {:estado, :wait_copia}
          ])
        send(
          {:servidor_sa, nodo_emisor},
          {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida}
        )

        {new_estadoGV, 0, 0}

      :wait_copia ->
        if nodo_emisor != estadoGV.vista_t.primario do
          #nodo_emisor no es el nodo primario
          procesar_latido_no_primario(
            estadoGV,
            timeouts_primario,
            timeouts_copia,
            n_vista_latido,
            nodo_emisor
          )
        else
          #nodo_emisor es el nodo primario
          cond do
            n_vista_latido == -1 ->
              #primario no confirma vista
              send(
                {:servidor_sa, nodo_emisor},
                {:vista_tentativa, estadoGV.vista_t, estadoGV.valida}
              )

              {estadoGV, 0, timeouts_copia}

            n_vista_latido == 0 and estadoGV.vista_t.copia != :undefined ->
              # Caida del primario con copia
              new_estadoGV = caida_primario(estadoGV)

              send(
                {:servidor_sa, nodo_emisor},
                {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida}
              )

              {new_estadoGV, timeouts_copia, 0}

            n_vista_latido == 0 and estadoGV.vista_t.copia == :undefined ->
              #Caida del primario sin copia
              new_estadoGV =
                caida_primario_sin_copia(estadoGV)
                |> Map.put(:estado, :wait_primario)

              send(
                {:servidor_sa, nodo_emisor},
                {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida}
              )

              {new_estadoGV, 0, 0}

            true ->
              # Primario valida vista
              new_estadoGV =
                update_estadoGV(estadoGV, [{:valida, true}, {:estado, :validado}])
                |> Map.put(:vista_v, estadoGV.vista_t)

              send(
                {:servidor_sa, nodo_emisor},
                {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida}
              )

              {new_estadoGV, 0, timeouts_copia}
          end
        end

      :validado ->
        {new_estadoGV, timeouts_primario, timeouts_copia} =
          cond do
            nodo_emisor == estadoGV.vista_t.primario ->
              #Latido del primario
              if n_vista_latido != 0 do
                #Primario sigue vivo
                send(
                  {:servidor_sa, nodo_emisor},
                  {:vista_tentativa, estadoGV.vista_t, estadoGV.valida}
                )

                {estadoGV, 0, timeouts_copia}
              else
                #Primario ha caido
                new_estadoGV =
                  update_estadoGV(estadoGV, [{:valida, false}, {:estado, :caida}])
                  |> caida_primario()

                send(
                  {:servidor_sa, nodo_emisor},
                  {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida}
                )

                {new_estadoGV, timeouts_copia, 0}
              end

            nodo_emisor == estadoGV.vista_t.copia ->
              #Latido de copia
              if n_vista_latido != 0 do
                #Copia sigue viva
                send(
                  {:servidor_sa, nodo_emisor},
                  {:vista_tentativa, estadoGV.vista_t, estadoGV.valida}
                )

                {estadoGV, timeouts_primario, 0}
              else
                #Copia ha caido
                new_estadoGV =
                  update_estadoGV(estadoGV, [{:valida, false}, {:estado, :caida}])
                  |> caida_copia()

                send(
                  {:servidor_sa, nodo_emisor},
                  {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida}
                )

                {new_estadoGV, timeouts_copia, 0}
              end

            true ->
              # Latido de nodo distinto al primario y a la copia
              send(
                {:servidor_sa, nodo_emisor},
                {:vista_tentativa, estadoGV.vista_t, estadoGV.valida}
              )

              new_estadoGV = update_estadoGV(estadoGV, [{:nodos_espera, nodo_emisor}])
              {new_estadoGV, timeouts_primario, timeouts_copia}
          end

      :caida ->
        if nodo_emisor != estadoGV.vista_t.primario do
          #Latido de nodo distinto del primario
          procesar_latido_no_primario(
            estadoGV,
            timeouts_primario,
            timeouts_copia,
            n_vista_latido,
            nodo_emisor
          )
        else
          #Latido del primario
          cond do
            n_vista_latido == 0 ->
              #Caida del primario
              new_vista_t =
                Map.put(estadoGV.vista_t, :primario, :undefined)
                |> Map.put(:copia, :undefined)
                |> Map.put(:num_vista, 0)

              new_estadoGV =
                Map.put(estadoGV, :vista_t, new_vista_t)
                |> Map.put(:estado, :error)

              send(
                {:servidor_sa, nodo_emisor},
                {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida}
              )

              {new_estadoGV, 0, 0}

            n_vista_latido != estadoGV.vista_t.num_vista ->
              #Primario no confirma vista
              send(
                {:servidor_sa, nodo_emisor},
                {:vista_tentativa, estadoGV.vista_t, estadoGV.valida}
              )

              {estadoGV, 0, timeouts_copia}

            true ->
              #Primario confirma vista
              new_estadoGV =
                update_estadoGV(estadoGV, [{:valida, true}, {:estado, :validado}])
                |> Map.put(:vista_v, estadoGV.vista_t)

              send(
                {:servidor_sa, nodo_emisor},
                {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida}
              )

              {new_estadoGV, 0, timeouts_copia}
          end
        end

      :error ->
        send({:servidor_sa, nodo_emisor}, {:vista_tentativa, estadoGV.vista_t, estadoGV.valida})
        {estadoGV, timeouts_primario, timeouts_copia}
    end
  end

  def procesar_situacion_servidores(estadoGV, timeouts_primario, timeouts_copia) do
    {new_estadoGV, timeouts_primario, timeouts_copia} =
      case estadoGV.estado do
        :wait_primario ->
          {estadoGV, timeouts_primario, timeouts_copia}

        :wait_copia ->
          {new_estadoGV, timeouts_primario, timeouts_copia} =
            cond do
              timeouts_primario >= latidos_fallidos() and estadoGV.vista_t.primario != :undefined and
                  estadoGV.vista_t.copia != :undefined ->
                {caida_primario(estadoGV), timeouts_copia, 0}

              timeouts_primario >= latidos_fallidos() and estadoGV.vista_t.primario != :undefined and
                  estadoGV.vista_t.copia == :undefined ->
                new_estadoGV =
                  caida_primario_sin_copia(estadoGV)
                  |> Map.put(:estado, :wait_primario)

                {new_estadoGV, 0, 0}

              timeouts_copia >= latidos_fallidos() and estadoGV.vista_t.copia != :undefined ->
                {caida_copia(estadoGV), timeouts_primario, 0}

              true ->
                {estadoGV, timeouts_primario, timeouts_copia}
            end

        :validado ->
          {new_estadoGV, timeouts_primario, timeouts_copia} =
            cond do
              timeouts_primario >= latidos_fallidos() ->
                new_estadoGV =
                  update_estadoGV(estadoGV, [{:valida, false}, {:estado, :caida}])
                  |> caida_primario()

                {new_estadoGV, timeouts_copia, 0}

              timeouts_copia >= latidos_fallidos() ->
                new_estadoGV =
                  update_estadoGV(estadoGV, [{:valida, false}, {:estado, :caida}])
                  |> caida_copia()

                {new_estadoGV, timeouts_copia, 0}

              true ->
                {estadoGV, timeouts_primario, timeouts_copia}
            end

        :caida ->
          {new_estadoGV, timeouts_primario, timeouts_copia} = cond do
              timeouts_primario >= latidos_fallidos() ->
                new_estadoGV =
                  caida_primario_sin_copia(estadoGV)
                  |> Map.put(:estado, :error)

                {new_estadoGV, 0, 0}

              timeouts_copia >= latidos_fallidos() and estadoGV.vista_t.copia != :undefined ->
                {caida_copia(estadoGV), timeouts_primario, 0}

              true ->
                {estadoGV, timeouts_primario, timeouts_copia}
            end

        :error ->
          {estadoGV, timeouts_primario, timeouts_copia}
      end
  end

  defp procesar_latido_no_primario(
         estadoGV,
         timeouts_primario,
         timeouts_copia,
         n_vista_latido,
         nodo_emisor
       ) do
    {new_estadoGV, timeouts_primario, timeouts_copia} =
      cond do
        estadoGV.vista_t.copia == :undefined ->
          # nodo_espera pasa a copia
          new_estadoGV = update_estadoGV(estadoGV, [{:num_vista}, {:copia, nodo_emisor}])

          send(
            {:servidor_sa, nodo_emisor},
            {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida}
          )

          {new_estadoGV, timeouts_primario, 0}

        estadoGV.vista_t.copia == nodo_emisor ->
          if n_vista_latido == 0 do
            # Caida rapida copia
            new_estadoGV = caida_copia(estadoGV)

            send(
              {:servidor_sa, nodo_emisor},
              {:vista_tentativa, new_estadoGV.vista_t, new_estadoGV.valida}
            )

            {new_estadoGV, timeouts_primario, 0}
          else
            # latido de copia
            send(
              {:servidor_sa, nodo_emisor},
              {:vista_tentativa, estadoGV.vista_t, estadoGV.valida}
            )

            {estadoGV, timeouts_primario, 0}
          end

        true ->
          # Añadir nodo en espera
          send({:servidor_sa, nodo_emisor}, {:vista_tentativa, estadoGV.vista_t, estadoGV.valida})
          new_estadoGV = update_estadoGV(estadoGV, [{:nodos_espera, nodo_emisor}])
          {new_estadoGV, timeouts_primario, timeouts_copia}
      end
  end

  def caida_copia(estadoGV) do

    if estadoGV.nodos_espera == [] do
      update_estadoGV(estadoGV, [{:num_vista}, {:copia, :undefined}])
    else
      new_vista_t =
        Map.update!(estadoGV.vista_t, :num_vista, &(&1 + 1))
        |> Map.put(:copia, hd(estadoGV.nodos_espera))

      Map.put(estadoGV, :vista_t, new_vista_t)
      |> Map.put(:nodos_espera, tl(estadoGV.nodos_espera))
    end
  end

  def caida_primario(estadoGV) do
    if estadoGV.nodos_espera == [] do
      update_estadoGV(estadoGV, [
        {:num_vista},
        {:primario, estadoGV.vista_t.copia},
        {:copia, :undefined}
      ])
    else
      new_vista_t =
        Map.update!(estadoGV.vista_t, :num_vista, &(&1 + 1))
        |> Map.put(:primario, estadoGV.vista_t.copia)
        |> Map.put(:copia, hd(estadoGV.nodos_espera))

      Map.put(estadoGV, :vista_t, new_vista_t)
      |> Map.put(:nodos_espera, tl(estadoGV.nodos_espera))
    end
  end

  def caida_primario_sin_copia(estadoGV) do

    new_vista_t =
      Map.put(estadoGV.vista_t, :num_vista, 0)
      |> Map.put(:primario, :undefined)

    Map.put(estadoGV, :vista_t, new_vista_t)
  end

  def update_estadoGV(estadoGV, []) do
    estadoGV
  end

  def update_estadoGV(estadoGV, new) do
    new_estadoGV =
      case elem(hd(new), 0) do
        :num_vista ->
          Map.put(estadoGV, :vista_t, Map.update!(estadoGV.vista_t, :num_vista, &(&1 + 1)))

        :primario ->
          Map.put(estadoGV, :vista_t, Map.put(estadoGV.vista_t, :primario, elem(hd(new), 1)))

        :copia ->
          Map.put(estadoGV, :vista_t, Map.put(estadoGV.vista_t, :copia, elem(hd(new), 1)))

        :nodos_espera ->
          if elem(hd(new), 1) == [] or
               Enum.find_value(estadoGV.nodos_espera, fn x -> x == elem(hd(new), 1) end) do
            estadoGV
          else
            Map.update!(estadoGV, :nodos_espera, &(&1 ++ [elem(hd(new), 1)]))
          end

        :valida ->
          Map.put(estadoGV, :valida, elem(hd(new), 1))

        :estado ->
          Map.put(estadoGV, :estado, elem(hd(new), 1))
      end

    update_estadoGV(new_estadoGV, tl(new))
  end
end
