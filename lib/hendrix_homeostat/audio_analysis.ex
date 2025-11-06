defmodule HendrixHomeostat.AudioAnalysis do
  @max_16bit 32768.0
  @max_32bit 2_147_483_648.0

  def calculate_rms(samples, opts \\ []) do
    calculate_metrics(samples, opts).rms
  end

  def calculate_zcr(samples, opts \\ []) do
    calculate_metrics(samples, opts).zcr
  end

  def calculate_peak(samples, opts \\ []) do
    calculate_metrics(samples, opts).peak
  end

  def calculate_metrics(samples, opts \\ [])

  def calculate_metrics(samples, opts) when is_list(samples) do
    format = opts |> Keyword.get(:format, :s16) |> normalize_format()
    analyze_samples(samples, format)
  end

  def calculate_metrics(samples, opts) when is_binary(samples) do
    format = opts |> Keyword.get(:format, :s16) |> normalize_format()

    samples
    |> binary_to_samples(format)
    |> analyze_samples(format)
  end

  defp analyze_samples(samples, format) do
    {count, sum_sq, peak, crossings, _last} =
      Enum.reduce(samples, {0, 0.0, 0.0, 0, nil}, fn sample,
                                                     {count, sum_sq, peak, crossings, prev} ->
        value = ensure_float(sample)
        new_peak = max(peak, abs(value))
        crossing = crossings + zero_cross_increment(prev, value)

        {count + 1, sum_sq + value * value, new_peak, crossing, value}
      end)

    if count == 0 do
      %{rms: 0.0, zcr: 0.0, peak: 0.0}
    else
      max_value = max_value_for(format)
      mean_square = sum_sq / count
      rms = :math.sqrt(mean_square) / max_value
      zcr = if count < 2, do: 0.0, else: crossings / count

      %{
        rms: rms,
        zcr: zcr,
        peak: peak / max_value
      }
    end
  end

  defp zero_cross_increment(nil, _current), do: 0

  defp zero_cross_increment(previous, current) do
    if (previous >= 0 and current < 0) or (previous < 0 and current >= 0) do
      1
    else
      0
    end
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

  defp normalize_format(:s16), do: :s16
  defp normalize_format(:s32), do: :s32
  defp normalize_format("S16_LE"), do: :s16
  defp normalize_format("S32_LE"), do: :s32

  defp normalize_format(other) do
    raise ArgumentError, "Unsupported audio format: #{inspect(other)}"
  end

  defp max_value_for(:s16), do: @max_16bit
  defp max_value_for(:s32), do: @max_32bit
end
