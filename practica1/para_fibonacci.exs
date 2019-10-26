# AUTORES: José Manuel Vidarte Llera, Diego Marco Beisty
# NIAs: 739729, 755232
# FICHERO: escenario3.ex
# FECHA: 27-09-2019
# DESCRIPCIÓN: Código añadido a los ḿódulos de los profesores
#							Código de fibonacci y del cliente

defmodule Fib do
	def fibonacci(0), do: 0
	def fibonacci(1), do: 1
	def fibonacci(n) when n >= 2 do
		fibonacci(n - 2) + fibonacci(n - 1)
	end
	def fibonacci_tr(n), do: fibonacci_tr(n, 0, 1)
	defp fibonacci_tr(0, _acc1, _acc2), do: 0
	defp fibonacci_tr(1, _acc1, acc2), do: acc2
	defp fibonacci_tr(n, acc1, acc2) do
		fibonacci_tr(n - 1, acc2, acc1 + acc2)
	end

	@golden_n :math.sqrt(5)
  	def of(n) do
 		(x_of(n) - y_of(n)) / @golden_n
	end
 	defp x_of(n) do
		:math.pow((1 + @golden_n) / 2, n)
	end
	def y_of(n) do
		:math.pow((1 - @golden_n) / 2, n)
	end
end

defmodule Cliente do

  def launch(pid, op, 1) do
		t_inicial = Time.utc_now()
		#Se recibe la petición en otro proceso para que el volumen de carga del servidor
		#implementado en cada escenario, no se vea afectado.
		pidRecibir = spawn( fn ->
		receive do
			{:result, l, tiempoAislado} -> l
											t_final = Time.utc_now()
											#Métricas obtenidas de la tarea mandada
											IO.puts("Recibido resultado--->")
											IO.inspect l
											tiempoTotal = Time.diff(t_final,t_inicial,:millisecond)
											IO.puts("Tiempo aislado tarea: #{tiempoAislado}")
											IO.puts("Tiempo total tarea: #{tiempoTotal}ms")
											#Comprobamos que se cumple el requisito de tiempo de respuesta
											if tiempoTotal < 1.5*tiempoAislado do
												IO.puts("OK: Se cumple tiempo de respuesta")
											else
												IO.puts("VIOLACION: Tiempo de respuesta")
											end
											IO.puts("_____________________________________")
			end end)
		send(pid, {pidRecibir, op, 1..36, 1})

  end

  def launch(pid, op, n) when n != 1 do
	send(pid, {self(), op, 1..36, n})
	launch(pid, op, n - 1)
  end

  def genera_workload(server_pid, escenario, time) do
	cond do
		time <= 3 ->  launch(server_pid, :fib, 8);IO.puts(Time.utc_now()); Process.sleep(2000)
		time == 4 ->  launch(server_pid, :fib, 8);IO.puts(Time.utc_now());Process.sleep(round(:rand.uniform(100)/100 * 2000))
		time <= 8 ->  launch(server_pid, :fib, 8);IO.puts(Time.utc_now());Process.sleep(round(:rand.uniform(100)/1000 * 2000))
		time == 9 -> launch(server_pid, :fib_tr, 8);IO.puts(Time.utc_now());Process.sleep(round(:rand.uniform(2)/2 * 2000))
	end
  	genera_workload(server_pid, escenario, rem(time + 1, 10))
  end

  def genera_workload(server_pid, escenario) do
  	if escenario == 1 do
		launch(server_pid, :fib, 1)
	else
		launch(server_pid, :fib, 4)
	end
	Process.sleep(2000)
  	genera_workload(server_pid, escenario)
  end

  def cliente(server_pid, tipo_escenario) do
  	case tipo_escenario do
		:uno -> IO.puts("----ESCENARIO1----")
						genera_workload(server_pid, 1)
		:dos -> IO.puts("----ESCENARIO2----")
						genera_workload(server_pid, 2)
		:tres ->IO.puts("----ESCENARIO4----")
						genera_workload(server_pid, 3, 1)
	end
  end
end
