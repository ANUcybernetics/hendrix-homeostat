defmodule HendrixHomeostat.AudioBackend.FileTest do
  use ExUnit.Case

  alias HendrixHomeostat.AudioBackend.File

  @test_data_dir Path.join([__DIR__, "..", "..", "fixtures"])

  setup do
    test_file = Path.join(@test_data_dir, "test_audio.bin")
    File.mkdir_p!(@test_data_dir)

    test_data = :crypto.strong_rand_bytes(8192)
    File.write!(test_file, test_data)

    on_exit(fn ->
      File.rm(test_file)
    end)

    %{test_file: test_file, test_data: test_data}
  end

  describe "start_link/1" do
    test "starts successfully with valid file path", %{test_file: test_file} do
      assert {:ok, pid} = File.start_link(%{file_path: test_file})
      assert Process.alive?(pid)
    end

    test "returns error for non-existent file" do
      assert {:error, {:file_error, :enoent}} =
               File.start_link(%{file_path: "/non/existent/file.bin"})
    end
  end

  describe "read_buffer/1" do
    test "reads data from file in chunks", %{test_file: test_file} do
      {:ok, pid} = File.start_link(%{file_path: test_file, buffer_size: 1024})

      assert {:ok, chunk1} = File.read_buffer(pid)
      assert byte_size(chunk1) == 1024

      assert {:ok, chunk2} = File.read_buffer(pid)
      assert byte_size(chunk2) == 1024

      assert chunk1 != chunk2
    end

    test "loops back to start when reaching end of file", %{test_file: test_file} do
      small_data = "hello world"
      File.write!(test_file, small_data)

      {:ok, pid} = File.start_link(%{file_path: test_file, buffer_size: 1024})

      assert {:ok, first_read} = File.read_buffer(pid)
      assert first_read == small_data

      assert {:ok, second_read} = File.read_buffer(pid)
      assert second_read == small_data
    end

    test "uses default buffer size when not specified", %{test_file: test_file} do
      {:ok, pid} = File.start_link(%{file_path: test_file})

      assert {:ok, chunk} = File.read_buffer(pid)
      assert byte_size(chunk) == 4096
    end
  end
end
