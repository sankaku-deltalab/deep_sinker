defmodule DeepSinkerTest do
  use ExUnit.Case
  doctest DeepSinker

  defp join_root_to_items(items, root) when is_bitstring(root) do
    items
    |> Enum.map(fn {path, marker} -> {Path.join(root, path), marker} end)
  end

  defp tmp_files_fixture(root) do
    # - root
    #   - dir_1
    #     - dir_1_1
    #       - file_1_1_1.txt
    #     - dir_1_2
    #     - file_1_1.txt
    #   - dir_2
    #     - dir_2_1
    #   - dir_3
    #     - file_3_1.txt
    #   - file_1.txt
    #   - file_2.txt
    rel_dirs = ["dir_1/dir_1_1", "dir_1/dir_1_2", "dir_2/dir_2_1", "dir_3"]

    for rel_dir <- rel_dirs do
      File.mkdir_p!(Path.join(root, rel_dir))
    end

    rel_files = [
      "dir_1/dir_1_1/file_1_1_1.txt",
      "dir_1/file_1_1.txt",
      "dir_3/file_3_1.txt",
      "file_1.txt",
      "file_2.txt"
    ]

    for rel_file <- rel_files do
      File.write(Path.join(root, rel_file), "")
    end
  end

  @tag :tmp_dir
  test "iter default", %{tmp_dir: root} do
    tmp_files_fixture(root)

    found_items =
      DeepSinker.new([{root, :a}])
      |> DeepSinker.stream()
      |> Enum.to_list()

    expected_items =
      [
        {"dir_1/dir_1_1/file_1_1_1.txt", :a},
        {"dir_1/file_1_1.txt", :a},
        {"dir_3/file_3_1.txt", :a},
        {"file_1.txt", :a},
        {"file_2.txt", :a}
      ]
      |> join_root_to_items(root)

    assert found_items == expected_items
  end

  @tag :tmp_dir
  test "iter with multiple roots", %{tmp_dir: root} do
    tmp_files_fixture(root)

    roots =
      [{"dir_1", :a}, {"dir_3", :b}]
      |> join_root_to_items(root)

    filepaths =
      DeepSinker.new(roots)
      |> DeepSinker.stream()
      |> Enum.to_list()

    expected_filepaths =
      [
        {"dir_1/dir_1_1/file_1_1_1.txt", :a},
        {"dir_1/file_1_1.txt", :a},
        {"dir_3/file_3_1.txt", :b}
        # "file_1.txt",
        # "file_2.txt"
      ]
      |> join_root_to_items(root)

    assert filepaths == expected_filepaths
  end

  @tag :tmp_dir
  test "iter desc", %{tmp_dir: root} do
    tmp_files_fixture(root)

    filepaths =
      DeepSinker.new([{root, :a}], order: :desc)
      |> DeepSinker.stream()
      |> Enum.to_list()

    expected_filepaths =
      [
        {"dir_1/dir_1_1/file_1_1_1.txt", :a},
        {"dir_1/file_1_1.txt", :a},
        {"dir_3/file_3_1.txt", :a},
        {"file_1.txt", :a},
        {"file_2.txt", :a}
      ]
      |> join_root_to_items(root)
      |> Enum.reverse()

    assert filepaths == expected_filepaths
  end

  @tag :tmp_dir
  test "iter with handler", %{tmp_dir: root} do
    tmp_files_fixture(root)

    filepaths =
      DeepSinker.new([{root, :a}])
      |> DeepSinker.stream(
        handler: fn {path, :a} ->
          basename = Path.basename(path)

          # Check is_dir without Path lib.
          cond do
            basename == "file_1_1_1.txt" -> :ignore
            String.ends_with?(basename, ".txt") -> :file
            true -> :directory
          end
        end
      )
      |> Enum.to_list()

    expected_filepaths =
      [
        # "dir_1/dir_1_1/file_1_1_1.txt",
        {"dir_1/file_1_1.txt", :a},
        {"dir_3/file_3_1.txt", :a},
        {"file_1.txt", :a},
        {"file_2.txt", :a}
      ]
      |> join_root_to_items(root)

    assert filepaths == expected_filepaths
  end
end
