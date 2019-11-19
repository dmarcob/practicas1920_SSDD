#Fichero para hace pruebas

defmodule Test do

  #Tiempos funciones
  def uno() do
    t1 = Time.utc_now()
    resultado = Fib.fibonacci_tr(36)
    t2 = Time.utc_now()
    tiempoAislado = Time.diff(t2,t1,:millisecond)
    IO.puts("Tiempo ejecucion fibonacci_tr(36) : #{tiempoAislado}ms")

    #####

    t1 = Time.utc_now()
    resultado = Fib.fibonacci_tr(100)
    t2 = Time.utc_now()
    tiempoAislado = Time.diff(t2,t1,:millisecond)
    IO.puts("Tiempo ejecucion fibonacci_tr(100) : #{tiempoAislado}ms")

    ####

    t1 = Time.utc_now()
    resultado = Fib.fibonacci_tr(1500)
    t2 = Time.utc_now()
    tiempoAislado = Time.diff(t2,t1,:millisecond)
    IO.puts("Tiempo ejecucion fibonacci_tr(1500) : #{tiempoAislado}ms")

    ###

    t1 = Time.utc_now()
    resultado = Fib.fibonacci(36)
    t2 = Time.utc_now()
    tiempoAislado = Time.diff(t2,t1,:millisecond)
    IO.puts("Tiempo ejecucion fibonacci(36) : #{tiempoAislado}ms")
  end

  #Muestra las operaciones que ejecuta el worker en cada invocación
  def dos() do
    	worker_TEST2(&Fib.fibonacci_tr/1, 1, :rand.uniform(10))
  end





  	defp worker_TEST2(op, service_count, k) do
  		[new_op, omission] = if rem(service_count, k) == 0 do
  			behavioural_probability = :rand.uniform(100)
  			cond do
  				behavioural_probability >= 90 ->
  					[&System.halt/1, false]
  				behavioural_probability >= 70 ->
  					[&Fib.fibonacci/1, false]
  				behavioural_probability >=  50 ->
  					[&Fib.of/1, false]
  				behavioural_probability >=  30 ->
  					[&Fib.fibonacci_tr/1, true]
  				true	->
  					[&Fib.fibonacci_tr/1, false]
  			end
  		else
  			[op, false]
  		end
  	#	receive do
  	#		{pid, args} -> if not omission, do: send(pid, op.(args))
  	#	end
      IO.inspect [new_op, omission]
      Process.sleep(200)
      #new_op <> ", " <> omission
  		worker_TEST2(new_op, rem(service_count + 1, k), k)
end

#Media de invocaciones hasta que aparece el primer error
def tres(num) do
    total =tres_1(num)
    total / num
end


defp tres_1(num) do
  valor = worker_TEST3(99, 1, :rand.uniform(10), 1, 0)
  if num <= 1 do
    valor
  else
    valor + tres_1(num - 1)
  end
end

def worker_TEST3(op, service_count, k, correcto, cuenta) do
  [new_op, omission, correcto, cuenta] = if rem(service_count, k) == 0 do
    behavioural_probability = :rand.uniform(100)
    cond do
      behavioural_probability >= 90 -> [&System.halt/1, false, -1, cuenta]
      behavioural_probability >= 70 -> [&Fib.fibonacci/1, false, -1, cuenta]
      behavioural_probability >=  50 ->[&Fib.of/1, false, -1, cuenta]
      behavioural_probability >=  30 ->[&Fib.fibonacci_tr/1, true, -1, cuenta]
      true	-> [99, false, 1, cuenta + 1];
    end
  else

    if op == 99 do
        [op, false, 1, cuenta + 1]
    else
        [op, false, -1, cuenta]
    end
  end
  if (correcto != -1) do
    worker_TEST3(new_op, rem(service_count + 1, k), k, correcto, cuenta)
  else
    cuenta
  end
end
end
