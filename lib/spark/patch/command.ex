defmodule Spark.Patch.Command do
  defmodule Add do
    defstruct [:path, :args, :file, :module, :spark]
  end

  defmodule Extend do
    defstruct [:type, :name, :file, :module, :spark]
  end

  defmodule Create do
    defstruct [:spark, :name, opts: [], additional_commands: []]
  end

  @type t() :: %Add{} | %Extend{}

  def parse_command_list(_file, _module, _spark, []), do: []

  def parse_command_list(file, module, spark, [%_{} = command | rest]) do
    [
      command
      | parse_command_list(file, module, spark, rest)
    ]
  end

  def parse_command_list(file, module, spark, [command | rest]) do
    {args, rest} = Enum.split_while(rest, &(!String.ends_with?(&1, ",")))

    {concat, rest} =
      case rest do
        [] -> {[], []}
        ["," | rest] -> {[], rest}
        [last | rest] -> {[String.trim_trailing(last, ",")], rest}
      end

    [
      parse_command(command, file, module, spark, args ++ concat)
      | parse_command_list(file, module, spark, rest)
    ]
  end

  defp parse_command("spark.add", file, module, spark, [path | args]) do
    %Add{path: path, args: args, file: file, module: module, spark: spark}
  end

  defp parse_command("spark.extend", file, module, spark, [type, name]) do
    %Extend{type: type, name: name, file: file, module: module, spark: spark}
  end

  defp parse_command(command, _file, _module, _spark, args) do
    raise "Invalid command #{command} #{Enum.join(args, " ")}"
  end
end
