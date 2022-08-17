defmodule Spark.FilePatchers.Spark do
  import ExPatcher

  def extend_spark(code, spark, name, type) do
    name = Module.concat([name]) |> IO.inspect()
    type = String.to_atom(type) |> IO.inspect()
    single? = name in spark.single_extension_kinds()

    if single? do
      code
      |> parse_string!()
      |> enter_defmodule()
      |> halt_if(& &1, :already_patched)
    else
      code
      |> parse_string!()
      |> enter_defmodule()
      |> IO.inspect()
      |> enter_call(:use, fn args ->
        false
      end)
      |> halt_if(& &1, :already_patched)
    end
  end

  # def use_spark(code, module, spark) do

  #   code
  #   |> parse_string!()
  #   |> enter_defmodule(module)
  #   |> append_code(use_code)
  # end
end
