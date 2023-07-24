# DeepSinker

Customizable directory traverser.

## Usage

```elixir
# Default usage
state = DeepSinker.new([{"/path/to/dir1", :dir1}, {"/path/to/dir2", :dir2}])
DeepSinker.next(state)  # {new_state, {:ok, {path, :dir1 | :dir2}} | :done}

# Custom usage
state = DeepSinker.new([{"/path/to/dir1", :dir1}, {"/path/to/dir2", :dir2}], order: :desc)  # :asc or :desc
DeepSinker.next(state,
  handler: fn {path, marker} ->
    # Below code is default handler but File.dir?/1 consume large time in some env.
    # cond do
    #   File.dir?(path) -> :directory
    #   true -> :file
    # end

    # If you want to avoid File.dir?/1, use this.
    basename = Path.basename(path)
    cond do
      basename == ".git" -> :ignore
      String.contains?(basename, ".") -> :file
      true -> :directory
    end
  end
)  # {new_state, {:ok, {path, :dir1 | :dir2}} | :done}

# Stream usage
state = DeepSinker.new([{"/path/to/dir1", :dir1}, {"/path/to/dir2", :dir2}])
DeepSinker.stream(state)
|> Enum.to_list()  # [{path, :dir1 | :dir2}]
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `deep_sinker` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:deep_sinker, "~> 2.0.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/deep_sinker>.

