defmodule HendrixHomeostat.AudioAnalysis do
  @max_16bit 32768.0
  @max_32bit 2_147_483_648.0

  def calculate_rms(samples, opts \\ [])

  def calculate_rms(samples, opts) when is_list(samples) do
    samples
    |> parse_samples()
    |> compute_rms(Keyword.get(opts, :format, :s16))
  end

  def calculate_rms(samples, opts) when is_binary(samples) do
    format = Keyword.get(opts, :format, :s16)

    samples
    |> binary_to_samples(format)
    |> compute_rms(format)
  end

  def calculate_zcr(samples, opts \\ [])

  def calculate_zcr(samples, _opts) when is_list(samples) do
    samples
    |> parse_samples()
    |> compute_zcr()
  end

  def calculate_zcr(samples, opts) when is_binary(samples) do
    format = Keyword.get(opts, :format, :s16)

    samples
    |> binary_to_samples(format)
    |> compute_zcr()
  end

  def calculate_peak(samples, opts \\ [])

  def calculate_peak(samples, opts) when is_list(samples) do
    samples
    |> parse_samples()
    |> compute_peak(Keyword.get(opts, :format, :s16))
  end

  def calculate_peak(samples, opts) when is_binary(samples) do
    format = Keyword.get(opts, :format, :s16)

    samples
    |> binary_to_samples(format)
    |> compute_peak(format)
  end

  def calculate_metrics(samples, opts \\ [])

  def calculate_metrics(samples, opts) when is_list(samples) do
    format = Keyword.get(opts, :format, :s16)
    parsed = parse_samples(samples)

    %{
      rms: compute_rms(parsed, format),
      zcr: compute_zcr(parsed),
      peak: compute_peak(parsed, format)
    }
  end

  def calculate_metrics(samples, opts) when is_binary(samples) do
    format = Keyword.get(opts, :format, :s16)
    parsed = binary_to_samples(samples, format)

    %{
      rms: compute_rms(parsed, format),
      zcr: compute_zcr(parsed),
      peak: compute_peak(parsed, format)
    }
  end

  defp parse_samples(samples) do
    Enum.map(samples, &ensure_float/1)
  end

  defp ensure_float(n) when is_float(n), do: n
  defp ensure_float(n) when is_integer(n), do: n / 1.0

  defp binary_to_samples(binary, :s16) do
    for <<sample::signed-little-16 <- binary>> do
      sample / 1.0
    end
  end

  defp binary_to_samples(binary, :s32) do
    for <<sample::signed-little-32 <- binary>> do
      sample / 1.0
    end
  end

  defp compute_rms([], _format), do: 0.0

  defp compute_rms(samples, format) do
    sum_of_squares =
      samples
      |> Enum.map(&(&1 * &1))
      |> Enum.sum()

    mean_square = sum_of_squares / length(samples)
    rms = :math.sqrt(mean_square)

    max_value =
      case format do
        :s16 -> @max_16bit
        :s32 -> @max_32bit
      end

    rms / max_value
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

  defp compute_peak([], _format), do: 0.0

  defp compute_peak(samples, format) do
    peak =
      samples
      |> Enum.map(&abs/1)
      |> Enum.max()

    max_value =
      case format do
        :s16 -> @max_16bit
        :s32 -> @max_32bit
      end

    peak / max_value
  end
end
