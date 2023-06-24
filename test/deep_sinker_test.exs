defmodule DeepSinkerTest do
  use ExUnit.Case
  doctest DeepSinker

  defp with_tmp_files(callback) do
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
    Tmp.dir(fn root ->
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

      callback.(root)
    end)
  end

  test "iter default" do
    with_tmp_files(fn root ->
      filepaths =
        DeepSinker.new([root])
        |> DeepSinker.stream()
        |> Enum.to_list()

      expected_filepaths =
        [
          "dir_1/dir_1_1/file_1_1_1.txt",
          "dir_1/file_1_1.txt",
          "dir_3/file_3_1.txt",
          "file_1.txt",
          "file_2.txt"
        ]
        |> Enum.map(&Path.join(root, &1))

      assert filepaths == expected_filepaths
    end)
  end

  test "iter with multiple roots" do
    with_tmp_files(fn root ->
      roots = ["dir_1", "dir_2"] |> Enum.map(&Path.join(root, &1))

      filepaths =
        DeepSinker.new(roots)
        |> DeepSinker.stream()
        |> Enum.to_list()

      expected_filepaths =
        [
          "dir_1/dir_1_1/file_1_1_1.txt",
          "dir_1/file_1_1.txt"
          # "dir_3/file_3_1.txt",
          # "file_1.txt",
          # "file_2.txt"
        ]
        |> Enum.map(&Path.join(root, &1))

      assert filepaths == expected_filepaths
    end)
  end

  test "iter desc" do
    with_tmp_files(fn root ->
      filepaths =
        DeepSinker.new([root], order: :desc)
        |> DeepSinker.stream()
        |> Enum.to_list()

      expected_filepaths =
        [
          "dir_1/dir_1_1/file_1_1_1.txt",
          "dir_1/file_1_1.txt",
          "dir_3/file_3_1.txt",
          "file_1.txt",
          "file_2.txt"
        ]
        |> Enum.map(&Path.join(root, &1))
        |> Enum.reverse()

      assert filepaths == expected_filepaths
    end)
  end

  test "iter with handler" do
    with_tmp_files(fn root ->
      filepaths =
        DeepSinker.new([root])
        |> DeepSinker.stream(
          handler: fn item_path ->
            basename = Path.basename(item_path)

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
          "dir_1/file_1_1.txt",
          "dir_3/file_3_1.txt",
          "file_1.txt",
          "file_2.txt"
        ]
        |> Enum.map(&Path.join(root, &1))

      assert filepaths == expected_filepaths
    end)
  end
end
