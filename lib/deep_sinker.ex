defmodule DeepSinker do
  @moduledoc """
  Customizable file traverser.
  """

  use TypedStruct

  @type filepath :: String.t()
  @type item_path :: String.t()
  @type order :: :asc | :desc
  @type item_type :: :file | :directory | :ignore
  @type handler :: (item_path() -> item_type())

  typedstruct do
    @typedoc "State of traversing."

    field :root_items, [item_path()], enforce: true
    field :order, order, enforce: true
    field :found_but_not_used_yet_items, [item_path()], enforce: true
  end

  @doc """
  Create initial state.

  ## Examples

      iex> DeepSinker.new(["/path/to/dir1", "/path/to/dir2"])
      ...> |> is_struct(DeepSinker)
      true

      iex> DeepSinker.new(["/path/to/dir1", "/path/to/dir2"], order: :desc)
      ...> |> is_struct(DeepSinker)
      true
  """
  @type new_option :: {:order, order()}
  @spec new([item_path()]) :: DeepSinker.t()
  @spec new([item_path()], [new_option()]) :: DeepSinker.t()
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

      iex> DeepSinker.new(["./"])
      ...> |> DeepSinker.next()
      ...> # {state, {:ok, filepath}} | {state, :done}

      iex> DeepSinker.new(["./"])
      ...> |> DeepSinker.next(
      ...>   handler: fn item_path ->
      ...>     cond do
      ...>       String.ends_with?(item_path, ".git") -> :ignore
      ...>       String.contains?(item_path, ".") -> :file
      ...>       true -> :directory
      ...>     end
      ...>   end
      ...> )
      ...> # {state, {:ok, filepath}} | {state, :done}
  """
  @type next_option :: {:handler, handler()}
  @type next_result :: {:ok, filepath()} | :done
  @spec next(DeepSinker.t()) :: {DeepSinker.t(), next_result()}
  @spec next(DeepSinker.t(), [next_option()]) :: {DeepSinker.t(), next_result()}
  def next(state, opt \\ [])

  def next(%DeepSinker{found_but_not_used_yet_items: []} = state, _opt) do
    # There are no files should search
    {state, :done}
  end

  def next(
        %DeepSinker{
          found_but_not_used_yet_items: [item_path | items_not_used_yet],
          order: order
        } = state,
        opt
      ) do
    handler = Keyword.get(opt, :handler, &default_handler/1)

    case handler.(item_path) do
      :file ->
        state = %{state | found_but_not_used_yet_items: items_not_used_yet}
        {state, {:ok, item_path}}

      :directory ->
        children = find_children(item_path, order)
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

      iex> DeepSinker.new(["./"])
      ...> # |> DeepSinker.stream()
      ...> # |> Enum.to_list()
      ...> # ["list", "of" "filepaths"]

      iex> DeepSinker.new(["./"])
      ...> |> DeepSinker.stream(
      ...>   handler: fn item_path ->
      ...>     cond do
      ...>       String.ends_with?(item_path, ".git") -> :ignore
      ...>       String.contains?(item_path, ".") -> :file
      ...>       true -> :directory
      ...>     end
      ...>   end
      ...> )
      ...> # ["list", "of" "filepaths"]
  """
  @spec stream(DeepSinker.t()) :: Enumerable.t(filepath())
  @spec stream(DeepSinker.t(), [next_option()]) :: Enumerable.t(filepath())
  def stream(state, opt \\ [])

  def stream(%DeepSinker{} = state, opt) do
    Stream.resource(
      fn -> state end,
      fn state ->
        with {state, {:ok, filepath}} <- DeepSinker.next(state, opt) do
          {[filepath], state}
        else
          {state, :done} -> {:halt, state}
        end
      end,
      fn _ -> nil end
    )
  end

  defp find_children(directory_path, order)
       when is_bitstring(directory_path) and order in [:asc, :desc] do
    with {:ok, filenames} <- :file.list_dir(directory_path) do
      filenames
      |> Enum.map(&to_string/1)
      |> Enum.map(fn name -> Path.join(directory_path, name) end)
      |> Enum.sort(order)
    else
      {:error, reason} ->
        :logger.error("Failed to load directory `#{directory_path}` because of #{reason}")
        []
    end
  end

  defp default_handler(item_path) do
    cond do
      File.dir?(item_path) -> :directory
      true -> :file
    end
  end
end
