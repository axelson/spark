# defmodule Spark.Patch do
#   @moduledoc """
#   Functions to programmatically create and modify DSL files.
#   """

#   @type opts :: Keyword.t()

#   @spec create(Spark.Dsl.t(), name :: String.t(), opts :: opts(), spark_opts :: Keyword.t()) ::
#           {source :: Macro.t(), path :: String.t()}
#   def create(spark, name, opts, spark_opts) do
#     {module_name, path} = spark.module_and_file_name(name, base(), opts)

#     using_opts =
#       if spark.generator_includes_otp_app?() do
#         [otp_app: Mix.Project.config()[:app]]
#       else
#         []
#       end

#     comment =
#       if spark_opts[:explain] do
#         {:docs_v1, _, _, _, %{"en" => module_doc}, _metadata, _} = Code.fetch_docs(spark)

#         module_doc |> String.split("\n") |> Enum.at(0)
#       end

#     source =
#       if Enum.empty?(using_opts) do
#         if comment do
#           """
#           defmodule #{inspect(module_name)} do
#             # #{comment}
#             use #{inspect(spark)}
#           end
#           """
#         else
#           """
#           defmodule #{inspect(module_name)} do
#             use #{inspect(spark)}
#           end
#           """
#         end
#       else
#         if comment do
#           """
#           defmodule #{inspect(module_name)} do
#             # #{comment}
#             use #{inspect(spark)}, #{inspect(using_opts)}
#           end
#           """
#         else
#           """
#           defmodule #{inspect(module_name)} do
#             use #{inspect(spark)}, #{inspect(using_opts)}
#           end
#           """
#         end
#       end

#     {Sourceror.parse_string!(source), path, module_name}
#   end

#   defp base do
#     case Application.get_env(:spark, :generator)[:base] do
#       nil ->
#         Module.concat([Enum.at(Module.split(Mix.Project.get!()), 0)])

#       base ->
#         base
#     end
#   end
# end
