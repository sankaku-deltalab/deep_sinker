defmodule DeepSinker do
  @moduledoc """
  Documentation for `DeepSinker`.
  """

  use TypedStruct

  @type filepath :: String.t()
  @type item_path :: String.t()
  @type order :: :asc | :desc
  @type item_type :: :file | :directory | :ignore
  @type handler :: (item_path -> item_type)

  @type opt :: [order: :asc | :desc, handler: handler]
  @type result :: {:ok, filepath} | :done

  typedstruct do
    @typedoc "State of traversing."

    field :root_items, [item_path], enforce: true
    field :handler, handler | nil, enforce: true
    field :order, order, enforce: true
    field :found_items, [item_path], enforce: true
  end

  @doc """
  Create initial state.

  ## Examples

      iex> DeepSinker.new(["/path/to/dir1", "/path/to/dir2"])
      ...> |> is_struct(DeepSinker)
      true

      iex> DeepSinker.new(["/path/to/dir1", "/path/to/dir2"],
      ...>   order: :desc,
      ...>   handler: fn item_path ->
      ...>     cond do
      ...>       item_path == ".git" -> :ignore
      ...>       String.contains?(item_path, ".") -> :file
      ...>       true -> :directory
      ...>     end
      ...>   end
      ...> )
      ...> |> is_struct(DeepSinker)
      true
  """
  @spec new([item_path]) :: DeepSinker.t()
  @spec new([item_path], opt) :: DeepSinker.t()
  def new(root_items, opt \\ []) do
    order = Keyword.get(opt, :order, :asc)
    handler = Keyword.get(opt, :handler, &default_handler/1)
    root_items = Enum.sort(root_items, order)

    %DeepSinker{
      root_items: root_items,
      handler: handler,
      order: order,
      found_items: root_items
    }
  end

  @doc """
  Pop file and update state.
  """
  @spec next(DeepSinker.t()) :: {DeepSinker.t(), result}
  def next(%DeepSinker{found_items: []} = _state) do
    # There are no files should search
    :done
  end

  def next(
        %DeepSinker{found_items: [item_path | found_items], order: order, handler: handler} =
          state
      ) do
    case handler.(item_path) do
      :file ->
        state = %{state | found_items: found_items}
        {state, {:ok, item_path}}

      :directory ->
        children = find_children(item_path, order)
        found_items = children ++ found_items
        state = %{state | found_items: found_items}
        next(state)

      :ignore ->
        state = %{state | found_items: found_items}
        next(state)
    end
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
