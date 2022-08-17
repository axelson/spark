defmodule Mix.Tasks.Spark.Gen do
  @shortdoc "Generates the specified DSL entity"
  @moduledoc @shortdoc
  use Mix.Task

  alias Spark.Patch.Group

  @spec run(term) :: no_return
  def run([type, name | opts]) do
    Mix.Task.run("compile")

    {opts, build_opts} = Enum.split_while(opts, &(&1 != "--"))

    {spark_opts, opts} =
      OptionParser.parse!(opts,
        strict: [explain: :boolean, dry_run: :boolean, path: :string],
        aliases: [e: :explain, d: :dry_run, p: :path]
      )

    build_opts =
      case build_opts do
        [] ->
          build_opts

        ["--" | rest] ->
          rest
      end

    spark = find_dsl(type)

    if !spark do
      raise "No generator for `#{inspect(type)}`"
    end

    {create_opts, _remaining_opts} =
      case List.wrap(spark.create_options()) do
        [] ->
          {[], opts}

        schema ->
          OptionParser.parse!(opts, schema)
      end

    group =
      spark
      |> Group.create_file(name, spark_opts, create_opts, build_opts)
      |> Group.dry_run()

    # if spark_opts[:dry_run] do
    #   Group.dry_run(group)
    # else
    #   Group.run(group)
    # end
  end

  defp find_dsl(name) do
    get_modules_from_applications()
    |> Enum.find(fn module ->
      try do
        _ = Code.ensure_compiled(module)

        function_exported?(module, :module_info, 0) &&
          Spark.implements_behaviour?(module, Spark.Dsl) && module.generator_name() &&
          module.generator_name() == name
      rescue
        _ ->
          false
      end
    end)
  end

  defp get_modules_from_applications() do
    for [app] <- loaded_applications(),
        {:ok, modules} = :application.get_key(app, :modules),
        module <- modules do
      module
    end
  end

  defp loaded_applications do
    # If we invoke :application.loaded_applications/0,
    # it can error if we don't call safe_fixtable before.
    # Since in both cases we are reaching over the
    # application controller internals, we choose to match
    # for performance.
    :ets.match(:ac_tab, {{:loaded, :"$1"}, :_})
  end
end
