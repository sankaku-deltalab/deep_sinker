# DeepSinker

Customizable directory traverser.

## Usage

```elixir
# Default usage
state = DeepSinker.new(["/path/to/dir1", "/path/to/dir2"])
DeepSinker.next(state)  # {new_state, {:ok, filepath} | :done}

# Custom usage
state = DeepSinker.new(["/path/to/dir1", "/path/to/dir2"],
  order: :desc,  # :asc or :desc
  handler: fn item_path ->
    # This is default behavior but File.dir?/1 consume large time in some env.
    # cond do
    #   File.dir?(item_path) -> :directory
    #   true -> :file
    # end

    # When you want to avoid File.dir?/1, use this.
    basename = Path.basename(item_path)
    cond do
      basename == ".git" -> :ignore
      String.contains?(basename, ".") -> :file
      true -> :directory
    end
  end
)
DeepSinker.next(state)  # {new_state, {:ok, filepath} | :done}

# Stream usage
state = DeepSinker.new(["/path/to/dir1", "/path/to/dir2"])
DeepSinker.stream(state)
|> Enum.to_list()  # [filepath]
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `deep_sinker` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:deep_sinker, "~> 0.2.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/deep_sinker>.

