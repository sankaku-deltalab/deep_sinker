defmodule DeepSinker do
  @moduledoc """
  Customizable file traverser.
  """

  use TypedStruct

  @type path :: String.t()
  @type marker :: any()
  @type item :: {path(), marker()}
  @type order :: :asc | :desc
  @type item_type :: :file | :directory | :ignore
  @type handler :: (item() -> item_type())

  typedstruct do
    @typedoc "State of traversing."

    field :root_items, [item()], enforce: true
    field :order, order, enforce: true
    field :found_but_not_used_yet_items, [item()], enforce: true
  end

  @doc """
  Create initial state.

  ## Examples

      iex> DeepSinker.new([{"/path/to/dir1", :dir1}, {"/path/to/dir2", :dir2}])
      ...> |> is_struct(DeepSinker)
      true

      iex> DeepSinker.new([{"/path/to/dir1", :dir1}, {"/path/to/dir2", :dir2}], order: :desc)
      ...> |> is_struct(DeepSinker)
      true
  """
  @type new_option :: {:order, order()}
  @spec new([item()]) :: DeepSinker.t()
  @spec new([item()], [new_option()]) :: DeepSinker.t()
  def new(root_items, opt \\ []) do
    order = Keyword.get(opt, :order, :asc)
    found_items = Enum.sort(root_items, order)

    %DeepSinker{
      root_items: root_items,
      order: order,
      found_but_not_used_yet_items: found_items
    }
  end

  @doc """
  Pop file and update state.

  ## Examples

      iex> DeepSinker.new([{"./", :marker}])
      ...> |> DeepSinker.next()
      ...> # {state, {:ok, {filepath, :marker}}} | {state, :done}

      iex> DeepSinker.new([{"./", :marker}])
      ...> |> DeepSinker.next(
      ...>   handler: fn {path, _marker} ->
      ...>     cond do
      ...>       String.ends_with?(path, ".git") -> :ignore
      ...>       String.contains?(path, ".") -> :file
      ...>       true -> :directory
      ...>     end
      ...>   end
      ...> )
      ...> # {state, {:ok, {filepath, :marker}}} | {state, :done}
  """
  @type next_option :: {:handler, handler()}
  @type next_result :: {:ok, item()} | :done

  @spec next(DeepSinker.t()) :: {DeepSinker.t(), next_result()}
  @spec next(DeepSinker.t(), [next_option()]) :: {DeepSinker.t(), next_result()}
  def next(state, opt \\ [])

  def next(%DeepSinker{found_but_not_used_yet_items: []} = state, _opt) do
    # There are no files should search
    {state, :done}
  end

  def next(
        %DeepSinker{
          found_but_not_used_yet_items: [{path, marker} | items_not_used_yet],
          order: order
        } = state,
        opt
      ) do
    handler = Keyword.get(opt, :handler, &default_handler/1)

    case handler.({path, marker}) do
      :file ->
        state = %{state | found_but_not_used_yet_items: items_not_used_yet}
        {state, {:ok, {path, marker}}}

      :directory ->
        children = find_children(path, marker, order)
        items_not_used_yet = children ++ items_not_used_yet
        state = %{state | found_but_not_used_yet_items: items_not_used_yet}
        next(state, opt)

      :ignore ->
        state = %{state | found_but_not_used_yet_items: items_not_used_yet}
        next(state, opt)
    end
  end

  @doc """
  Stream filepaths.

  ## Examples

      iex> DeepSinker.new([{"/path_a", :a}, {"/path_b", :b}])
      ...> # |> DeepSinker.stream()
      ...> # |> Enum.to_list()
      ...> # [{"/path_a/1.txt", :a}, {"/path_a/2.txt, :a} {"/path_b/1.txt, :b}]

      iex> DeepSinker.new([{"/path_a", :a}, {"/path_b", :b}])
      ...> |> DeepSinker.stream(
      ...>   handler: fn {path, _marker} ->
      ...>     cond do
      ...>       String.ends_with?(path, ".git") -> :ignore
      ...>       String.contains?(path, ".") -> :file
      ...>       true -> :directory
      ...>     end
      ...>   end
      ...> )
      ...> # [{"/path_a/1.txt", :a}, {"/path_a/2.txt, :a} {"/path_b/1.txt, :b}]
  """
  @spec stream(DeepSinker.t()) :: Enumerable.t(item())
  @spec stream(DeepSinker.t(), [next_option()]) :: Enumerable.t(item())
  def stream(state, opt \\ [])

  def stream(%DeepSinker{} = state, opt) do
    Stream.resource(
      fn -> state end,
      fn state ->
        with {state, {:ok, item}} <- DeepSinker.next(state, opt) do
          {[item], state}
        else
          {state, :done} -> {:halt, state}
        end
      end,
      fn _ -> nil end
    )
  end

  defp find_children(directory_path, marker, order)
       when is_bitstring(directory_path) and order in [:asc, :desc] do
    with {:ok, filenames} <- :file.list_dir(directory_path) do
      filenames
      |> Enum.map(&to_string/1)
      |> Enum.map(fn name -> Path.join(directory_path, name) end)
      |> Enum.map(fn filepath -> {filepath, marker} end)
      |> Enum.sort(order)
    else
      {:error, reason} ->
        :logger.error("Failed to load directory `#{directory_path}` because of #{reason}")
        []
    end
  end

  defp default_handler({path, _marker}) do
    cond do
      File.dir?(path) -> :directory
      true -> :file
    end
  end
end
