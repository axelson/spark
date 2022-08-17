defmodule Spark.Patch.Group do
  alias Spark.Patch

  defmodule PatchFile do
    defstruct [:path, contents: "", patches: [], create?: false]
  end

  defstruct files: %{}

  alias Spark.Patch.Command

  def create_file(
        group \\ %Spark.Patch.Group{},
        spark,
        name,
        spark_opts,
        create_opts,
        additional_commands
      ) do
    {module, path} = spark.module_and_file_name(name, module_base(), create_opts)

    commands =
      Spark.Patch.Command.parse_command_list(path, module, spark, additional_commands) ++
        spark.after_create(path, module)

    group
    |> create_file_with_module(path, module, spark, spark_opts)
    |> apply_commands(commands, spark_opts)
  end

  def apply_commands(group \\ %Spark.Patch.Group{}, commands, spark_opts) do
    Enum.reduce(commands, group, &apply_command(&2, &1, spark_opts))
  end

  def apply_command(
        group,
        %Command.Extend{
          name: name,
          type: type,
          file: file,
          module: module,
          spark: spark
        },
        _spark_opts
      ) do
    patch_file(group, file, &Spark.FilePatchers.Spark.extend_spark(&1, spark, name, type))
  end

  def apply_command(group, _, _) do
    group
  end

  # def apply_command(
  #       group,
  #       %Command.Create{
  #         spark: spark,
  #         name: name,
  #         opts: opts,
  #         additional_commands: additional_commands
  #       },
  #       spark_opts
  #     ) do
  #   create_file(group, spark, name, spark_opts, opts, additional_commands)
  # end

  # def apply_command(
  #       group,
  #       %Command.Add{
  #         path: path,
  #         args: args,
  #         file: file,
  #         module: module,
  #         spark: spark
  #       },
  #       spark_opts
  #     ) do
  #   extensions = get_extensions(group, file, module, spark)

  #   [top_section_name | rest_path] = path |> String.split(".") |> Enum.map(&String.to_atom/1)

  #   top_section =
  #     Enum.find_value(extensions, fn extension ->
  #       Enum.find(extension.sections(), &(&1.name == top_section_name))
  #     end) || raise "Invalid DSL path: #{path}"

  #   %{
  #     group
  #     | files:
  #         Map.update!(group.files, file, fn file ->
  #           %{file | contents: add(file.contents, top_section, rest_path, args, spark_opts)}
  #         end)
  #   }
  # end

  # defp add(contents, %{name: section_or_entity_name} = section_or_entity, path, args, spark_opts) do
  #   Macro.prewalk(contents, false, fn
  #     {^section_or_entity_name, meta, [[do: {:__block__, block_meta, block_contents}]]}, false ->
  #       case path do
  #         [name] ->
  #           new_contents = {name, [], {[[do: {:__block__, [], []}]]}}

  #           meta =
  #             if false do
  #               text =
  #                 section_or_entity.doc |> String.split("\n") |> Enum.map_join("\n", &"# #{&1}")

  #               Keyword.put(
  #                 meta,
  #                 :leading_comments,
  #                 Keyword.get(meta, :leading_comments, []) ++
  #                   [
  #                     %{
  #                       column: 1,
  #                       next_eol_count: 0,
  #                       previous_eol_count: 1,
  #                       text: text
  #                     }
  #                   ]
  #               )
  #             else
  #               meta
  #             end

  #           {{section_or_entity_name, meta,
  #             [[do: {:__block__, block_meta, block_contents ++ [new_contents]}]]}, true}

  #         [next | rest] ->
  #           next_section_or_entity =
  #             case section_or_entity do
  #               %Spark.Dsl.Section{} = section ->
  #                 Enum.find(section.sections, &(&1.name == next)) ||
  #                   Enum.find(section.entities, &(&1.name == next))
  #             end

  #           {{section_or_entity_name, meta,
  #             [
  #               [
  #                 do:
  #                   {:__block__, block_meta,
  #                    add(block_contents, next_section_or_entity, rest, args, spark_opts)}
  #               ]
  #             ]}, true}
  #       end

  #     ast, other ->
  #       {ast, other}
  #   end)
  # end

  # defp extend(contents, type, name, spark) do
  #   type = String.to_atom(type)
  #   name = Module.concat([name])
  #   single? = type in (spark.single_extension_kinds() || [])

  #   Macro.prewalk(contents, fn
  #     {:use, meta, [mod | rest]} ->
  #       # if spark == Macro.expand_once(mod) ?
  #       opts = Enum.at(rest, 0) || []

  #       {default, updater} =
  #         if single? do
  #           {name, fn _ -> name end}
  #         else
  #           {[name], fn value -> value ++ [name] end}
  #         end

  #       {:use, meta, [mod, Keyword.update(opts, type, default, updater)]}

  #     ast ->
  #       ast
  #   end)
  # end

  # defp get_extensions(group, file, module, spark) do
  #   if group.files[file] && group.files[file].create? do
  #     get_extensions_from_source(group.files[file].contents, module, spark)
  #   else
  #     get_extensions_from_module(module)
  #   end
  # end

  # defp get_extensions_from_source(source, _module, spark) do
  #   {_ast, extensions} =
  #     Macro.prewalk(source, nil, fn
  #       {:use, _, [_mod | rest]} = ast, nil ->
  #         opts = Enum.at(rest, 0) || []

  #         extension_kinds = [:extensions | spark.extension_kinds()]
  #         default_extensions = spark.default_extension_keys()

  #         extensions =
  #           Enum.reduce(extension_kinds, default_extensions, fn kind, extensions ->
  #             if extensions[kind] && not is_list(extensions[kind]) do
  #               Keyword.put(extensions, kind, opts[kind])
  #             else
  #               new_extensions = List.wrap(opts[kind])
  #               Keyword.update(extensions, kind, new_extensions, &(&1 ++ new_extensions))
  #             end
  #           end)
  #           |> Enum.flat_map(fn {_key, values} ->
  #             List.wrap(values)
  #           end)

  #         {ast, extensions}

  #       ast, acc ->
  #         {ast, acc}
  #     end)

  #   List.wrap(extensions)
  # end

  # defp get_extensions_from_module(module) do
  #   Spark.extensions(module)
  # end

  # def dry_run(group) do
  #   {create, updates} =
  #     group.files
  #     |> Map.values()
  #     |> Enum.split_with(& &1.create?)

  #   create
  #   |> Enum.concat(updates)
  #   |> Enum.map_join("\n\n====\n\n", &file_dry_run/1)
  #   |> IO.puts()
  # end

  def dry_run(group) do
    group.files
    |> Map.values()
    |> Enum.each(&file_dry_run/1)
  end

  defp file_dry_run(%PatchFile{contents: contents, patches: patches, path: path, create?: create?}) do
    if create? do
      Patcher.create_and_patch_file(contents, path, patches, %{dry_run: true, yes: true})
    else
      Patcher.patch_file(path, patches, %{dry_run: true, yes: true})
    end
  end

  defp patch_file(group, path, patch) do
    group = ensure_file(group, path)

    %{
      group
      | files:
          Map.update!(group.files, path, fn patch_file ->
            %{patch_file | patches: patch_file.patches ++ [%{patch: patch, instructions: ""}]}
          end)
    }
  end

  defp ensure_file(group, path) do
    if group.files[path] do
      group
    else
      if File.exists?(path) do
        %{group | files: Map.put(group.files, path, %PatchFile{contents: File.read!(path)})}
      else
        %{group | files: Map.put(group.files, path, %PatchFile{contents: "", create?: true})}
      end
    end
  end

  defp create_file_with_module(group, path, module_name, spark, spark_opts) do
    use_code =
      if spark.generator_includes_otp_app?() do
        "\nuse #{inspect(spark)}, #{inspect(otp_app: Mix.Project.config()[:app])}\n"
      else
        "\nuse #{inspect(spark)}\n"
      end

    comment =
      if spark_opts[:explain] do
        {:docs_v1, _, _, _, %{"en" => module_doc}, _metadata, _} = Code.fetch_docs(spark)

        module_doc
        |> String.split("\n")
        |> Enum.at(0)
        |> case do
          "" ->
            ""

          comment ->
            "\n# #{comment}"
        end
      end

    contents =
      IO.iodata_to_binary(
        Code.format_string!("defmodule #{inspect(module_name)} do#{comment}\n#{use_code}end\n")
      )

    %{
      group
      | files:
          Map.put(group.files, path, %PatchFile{contents: contents, path: path, create?: true})
    }
  end

  defp module_base do
    case Application.get_env(:spark, :generator)[:base] do
      nil ->
        Module.concat([Enum.at(Module.split(Mix.Project.get!()), 0)])

      base ->
        base
    end
  end
end
