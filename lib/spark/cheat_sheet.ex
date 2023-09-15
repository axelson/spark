defmodule Spark.CheatSheet do
  @moduledoc "Tools to generate cheat sheets for spark DSLs"

  @doc """
  Generate a cheat sheet for a given DSL
  """
  def cheat_sheet(extension) do
    patches =
      Enum.map_join(
        extension.dsl_patches(),
        "\n\n",
        fn %Spark.Dsl.Patch.AddEntity{
             section_path: section_path,
             entity: entity
           } ->
          entity_cheat_sheet(entity, section_path)
        end
      )

    body =
      extension.sections()
      |> Enum.map_join("\n\n", &section_cheat_sheet(&1))
      |> Kernel.<>("\n")
      |> Kernel.<>(patches)

    """
    # DSL: #{inspect(extension)}

    #{module_docs(extension)}

    #{body}
    """
  end

  def section_cheat_sheet(section, path \\ []) do
    examples =
      case section.examples do
        [] ->
          ""

        examples ->
          """
          ### Examples
          #{doc_examples(examples)}
          """
      end

    if section.schema && section.schema != [] do
      """
      ## #{Enum.join(path ++ [section.name], ".")}
      #{describe(section.describe)}

      #{doc_index(section.sections ++ section.entities, 0, Enum.join(path ++ [section.name], "-"))}

      #{examples}

      #{options_table(section.schema)}

      #{Enum.map_join(section.sections, &section_cheat_sheet(&1, path ++ [section.name]))}
      #{Enum.map_join(section.entities, &entity_cheat_sheet(&1, path ++ [section.name]))}
      """
    else
      """
      ## #{Enum.join(path ++ [section.name], ".")}
      #{describe(section.describe)}

      #{doc_index(section.sections ++ section.entities, 0, Enum.join(path ++ [section.name], "-"))}

      #{examples}

      #{Enum.map_join(section.sections, &section_cheat_sheet(&1, path ++ [section.name]))}
      #{Enum.map_join(section.entities, &entity_cheat_sheet(&1, path ++ [section.name]))}
      """
    end
  end

  defp entity_cheat_sheet(entity, path) do
    nested_entities =
      entity.entities
      |> List.wrap()
      |> Enum.flat_map(&elem(&1, 1))

    nested_entity_docs =
      Enum.map_join(nested_entities, &entity_cheat_sheet(&1, path ++ [entity.name]))

    options = Keyword.drop(entity.schema, List.wrap(entity.hide))
    arg_keys = arg_keys(entity)

    reference =
      if Enum.empty?(nested_entities) && Enum.empty?(options) do
        ""
      else
        """
        #{options_table(options, arg_keys)}

        #{nested_entity_docs}
        """
      end

    args_example =
      if Enum.empty?(entity.args) do
        ""
      else
        """
        ```elixir
        #{entity.name}#{entity_args(entity)}
        ```
        """
      end

    examples =
      case entity.examples do
        [] ->
          ""

        examples ->
          """
          ### Examples
          #{doc_examples(examples)}
          """
      end

    """
    ## #{Enum.join(path ++ [entity.name], ".")}
    #{args_example}

    #{describe(entity.describe)}

    #{doc_index(nested_entities, 0, Enum.join(path ++ [entity.name], "-"))}

    #{examples}

    #{reference}

    #{entity_properties(entity)}
    """
  end

  defp describe(entity) do
    entity
    |> String.split("\n")
    |> Enum.map(&String.trim_leading/1)
    |> Enum.map_join("\n", fn
      "####" <> rest ->
        "######" <> rest

      "###" <> rest ->
        "#####" <> rest

      "##" <> rest ->
        "####" <> rest

      "#" <> rest ->
        "###" <> rest

      other ->
        other
    end)
  end

  defp entity_args(%{args: []}), do: ""

  defp entity_args(entity) do
    " " <>
      Enum.map_join(entity.args, ", ", fn
        key when is_atom(key) ->
          to_string(key)

        {:optional, key} ->
          "#{key} \\ nil"

        {:optional, key, default} ->
          "#{key} \\ #{inspect(default)}"
      end)
  end

  defp arg_keys(entity) do
    entity.args
    |> Enum.map(fn
      key when is_atom(key) ->
        key

      {:optional, key} ->
        key

      {:optional, key, _} ->
        key
    end)
  end

  defp entity_properties(entity) do
    """
    ### Introspection

    Target: `#{inspect(entity.target)}`
    """
  end

  defp options_table(options, positional_args \\ [])
  defp options_table([], _), do: nil

  defp options_table(options, positional_args) do
    {required, optional} =
      Enum.split_with(options, fn {key, _config} ->
        key in positional_args
      end)

    required =
      Enum.sort_by(required, fn {key, _} ->
        Enum.find_index(positional_args, &(&1 == key))
      end)

    args = do_options_table(required, "Arguments")

    opts = do_options_table(optional, "Options")

    table =
      String.trim(args) <> "\n" <> String.trim(opts)

    """
    #{table}
    """
  end

  defp do_options_table([], _header), do: ""

  defp do_options_table(options, header) do
    rows =
      Enum.map_join(options, "\n", fn {key, value} ->
        required_star =
          if value[:required] && is_nil(value[:default]) do
            "*"
          else
            ""
          end

        "| `#{key}`#{required_star} | `#{escape_pipes(Spark.Types.doc_type(value[:type]))}` | #{escape_pipes(inspect_if(value[:default]))} | #{escape_pipes(value[:doc] || "")} |"
      end)

    table =
      """
      ### #{header}
      | Name | Type | Default | Docs |
      | ---  | ---  | ---     | ---  |
      #{rows}
      """

    """
    #{table}
    """
  end

  defp inspect_if(nil), do: ""
  defp inspect_if(value), do: inspect(value)

  defp escape_pipes(string) do
    string
    |> String.trim()
    |> String.replace("|", "\\|")
    |> tap(fn thing ->
      if String.contains?(thing, "\n") do
        IO.warn("""
        Multi-line DSL option doc detected. Please move contextual information into the
        doc of a section, entity or module.

        #{thing}
        """)
      end
    end)
    |> String.replace("\n\n", "\n")
    |> String.replace("\n", " ")
  end

  @doc """
  Generate a markdown bullet list documentation for a list of sections
  """
  def doc(sections, depth \\ 1) do
    Enum.map_join(sections, "\n\n", fn section ->
      String.duplicate("#", depth + 1) <>
        " " <>
        to_string(section.name) <> "\n\n" <> doc_section(section, depth)
    end)
  end

  @doc false
  def doc_section(section, depth \\ 1) do
    sections_and_entities = List.wrap(section.entities) ++ List.wrap(section.sections)

    table_of_contents =
      case sections_and_entities do
        [] ->
          ""

        sections_and_entities ->
          doc_index(sections_and_entities, 0)
      end

    options = Spark.OptionsHelpers.docs(section.schema)

    examples =
      case section.examples do
        [] ->
          ""

        examples ->
          "Examples:\n" <> Enum.map_join(examples, &doc_example/1)
      end

    entities =
      Enum.map_join(section.entities, "\n\n", fn entity ->
        String.duplicate("#", depth + 2) <>
          " " <>
          to_string(entity.name) <>
          "\n\n" <>
          doc_entity(entity, depth + 2)
      end)

    sections =
      Enum.map_join(section.sections, "\n\n", fn section ->
        String.duplicate("#", depth + 2) <>
          " " <>
          to_string(section.name) <>
          "\n\n" <>
          doc_section(section, depth + 1)
      end)

    imports =
      case section.imports do
        [] ->
          ""

        mods ->
          "Imports:\n\n" <>
            Enum.map_join(mods, "\n", fn mod ->
              "* `#{inspect(mod)}`"
            end)
      end

    """
    #{section.describe}

    #{table_of_contents}

    #{examples}

    #{imports}

    ---

    #{options}

    #{entities}

    #{sections}
    """
  end

  @doc false
  def doc_entity(entity, depth \\ 1) do
    options = Spark.OptionsHelpers.docs(Keyword.drop(entity.schema, entity.hide))

    examples =
      case entity.examples do
        [] ->
          ""

        examples ->
          "Examples:\n" <> Enum.map_join(examples, &doc_example/1)
      end

    entities =
      Enum.flat_map(entity.entities, fn
        {_, entities} ->
          entities

        other ->
          [other]
      end)

    entities_doc =
      Enum.map_join(entities, "\n\n", fn entity ->
        String.duplicate("#", depth + 2) <>
          " " <>
          to_string(entity.name) <>
          "\n\n" <>
          doc_entity(entity, depth + 1)
      end)

    table_of_contents =
      case entities do
        [] ->
          ""

        entities ->
          doc_index(entities, depth)
      end

    """
    #{entity.describe}

    #{table_of_contents}

    #{examples}

    #{options}

    #{entities_doc}
    """
  end

  defp module_docs(module) do
    {:docs_v1, _, :elixir, _, %{"en" => docs}, _, _} = Code.fetch_docs(module)

    if docs != "" do
      docs
    else
      ""
    end
  rescue
    _ -> ""
  end

  @doc """
  Generate a table of contents for a list of sections
  """
  def doc_index(sections, depth \\ 0, prefix \\ "module") do
    sections
    |> Enum.flat_map(fn
      {_, entities} ->
        entities

      other ->
        [other]
    end)
    |> Enum.map_join("\n", fn
      section ->
        docs =
          if depth == 0 do
            String.duplicate(" ", depth + 1) <>
              "* [#{section.name}](##{prefix}-#{section.name})"
          else
            String.duplicate(" ", depth + 1) <> "* #{section.name}"
          end

        case List.wrap(section.entities) ++ List.wrap(Map.get(section, :sections)) do
          [] ->
            docs

          sections_and_entities ->
            new_prefix =
              if prefix == "module" do
                prefix
              else
                prefix <> "-#{section.name}"
              end

            docs <>
              "\n" <> doc_index(sections_and_entities, depth + 2, new_prefix)
        end
    end)
  end

  defp doc_examples(examples) do
    examples
    |> List.wrap()
    |> Enum.map_join("\n", &doc_example/1)
  end

  defp doc_example({description, example}) when is_binary(description) and is_binary(example) do
    """
    #{description}
    ```
    #{example}
    ```
    """
  end

  defp doc_example(example) when is_binary(example) do
    """
    ```
    #{example}
    ```
    """
  end
end
