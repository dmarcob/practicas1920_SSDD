 # AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
 # NIAs: 739729, 755232
 # FICHERO: repositorio.exs
 # FECHA: 27-09-2019
 # DESCRIPCI'ON:  	Implementa un repositorio para gestionar el enunciado de un trabajo de asignatura.
 # 				El enunciado tiene tres partes: resumen, parte principal y descripci'on de la entrega.
 #				El repositorio consta de un servidor que proporciona acceso individual a cada parte del enunciado,
 #				bien en lectura o bien en escritura

defmodule Repositorio do

  def initServidor() do
    #Añadir cookie
		Node.set_cookie(:cookie123)
		#Registrar el proceso servidor
    Process.register(self(), :server)
		IO.puts("SERVIDOR ACTIVO")
    repo_server({"", "", ""})
  end

	defp repo_server({resumen, principal, entrega}) do
		{n_resumen, n_principal, n_entrega} = receive do
			{:update_resumen, c_pid, descripcion} -> send(c_pid, {:reply, :ok}); {descripcion, principal, entrega}
			{:update_principal, c_pid, descripcion} -> send(c_pid, {:reply, :ok}); {resumen, descripcion, entrega}
			{:update_entrega, c_pid, descripcion} -> send(c_pid, {:reply, :ok}); {resumen, principal, descripcion}
			{:read_resumen, c_pid} -> send(c_pid, {:reply, resumen}); {resumen, principal, entrega}
			{:read_principal, c_pid} -> send(c_pid, {:reply, principal}); {resumen, principal, entrega}
			{:read_entrega, c_pid} -> send(c_pid, {:reply, entrega}); {resumen, principal, entrega}
		end
		repo_server({n_resumen, n_principal, n_entrega})
	end
end
