defmodule HendrixHomeostat.AudioAnalysis do
  @max_16bit 32768.0

  def calculate_rms(samples) when is_list(samples) do
    samples
    |> parse_samples()
    |> compute_rms()
  end

  def calculate_rms(samples) when is_binary(samples) do
    samples
    |> binary_to_samples()
    |> compute_rms()
  end

  def calculate_zcr(samples) when is_list(samples) do
    samples
    |> parse_samples()
    |> compute_zcr()
  end

  def calculate_zcr(samples) when is_binary(samples) do
    samples
    |> binary_to_samples()
    |> compute_zcr()
  end

  def calculate_peak(samples) when is_list(samples) do
    samples
    |> parse_samples()
    |> compute_peak()
  end

  def calculate_peak(samples) when is_binary(samples) do
    samples
    |> binary_to_samples()
    |> compute_peak()
  end

  def calculate_metrics(samples) when is_list(samples) do
    parsed = parse_samples(samples)

    %{
      rms: compute_rms(parsed),
      zcr: compute_zcr(parsed),
      peak: compute_peak(parsed)
    }
  end

  def calculate_metrics(samples) when is_binary(samples) do
    parsed = binary_to_samples(samples)

    %{
      rms: compute_rms(parsed),
      zcr: compute_zcr(parsed),
      peak: compute_peak(parsed)
    }
  end

  defp parse_samples(samples) do
    Enum.map(samples, &ensure_float/1)
  end

  defp ensure_float(n) when is_float(n), do: n
  defp ensure_float(n) when is_integer(n), do: n / 1.0

  defp binary_to_samples(binary) do
    for <<sample::signed-little-16 <- binary>> do
      sample / 1.0
    end
  end

  defp compute_rms([]), do: 0.0

  defp compute_rms(samples) do
    sum_of_squares =
      samples
      |> Enum.map(&(&1 * &1))
      |> Enum.sum()

    mean_square = sum_of_squares / length(samples)
    rms = :math.sqrt(mean_square)

    rms / @max_16bit
  end

  defp compute_zcr([]), do: 0.0
  defp compute_zcr([_]), do: 0.0

  defp compute_zcr(samples) do
    crossings =
      samples
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.count(fn [a, b] -> (a >= 0 and b < 0) or (a < 0 and b >= 0) end)

    crossings / length(samples)
  end

  defp compute_peak([]), do: 0.0

  defp compute_peak(samples) do
    peak =
      samples
      |> Enum.map(&abs/1)
      |> Enum.max()

    peak / @max_16bit
  end
end
