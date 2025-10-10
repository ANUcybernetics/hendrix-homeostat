defmodule HendrixHomeostat.AudioAnalysisTest do
  use ExUnit.Case, async: true

  alias HendrixHomeostat.AudioAnalysis

  @max_16bit 32768.0

  describe "calculate_rms/1" do
    test "returns 0.0 for silence" do
      silence = List.duplicate(0, 1000)
      assert AudioAnalysis.calculate_rms(silence) == 0.0
    end

    test "returns 0.0 for silence as binary" do
      silence = <<0::signed-little-16, 0::signed-little-16, 0::signed-little-16>>
      assert AudioAnalysis.calculate_rms(silence) == 0.0
    end

    test "returns 1.0 for maximum amplitude" do
      max_amp = round(@max_16bit - 1)
      full_scale = List.duplicate(max_amp, 100)
      assert_in_delta AudioAnalysis.calculate_rms(full_scale), 1.0, 0.01
    end

    test "calculates correct RMS for constant amplitude" do
      amplitude = 16384.0
      samples = List.duplicate(amplitude, 100)
      expected_rms = amplitude / @max_16bit
      assert_in_delta AudioAnalysis.calculate_rms(samples), expected_rms, 0.0001
    end

    test "calculates RMS for sine wave pattern" do
      amplitude = 10000.0
      samples = for i <- 0..99, do: amplitude * :math.sin(2 * :math.pi() * i / 100)

      rms_raw = :math.sqrt(Enum.sum(Enum.map(samples, &(&1 * &1))) / length(samples))
      expected_rms = rms_raw / @max_16bit

      assert_in_delta AudioAnalysis.calculate_rms(samples), expected_rms, 0.0001
    end

    test "handles binary input with 16-bit signed little-endian format" do
      samples = [1000, 2000, 3000, -1000, -2000]
      binary = for sample <- samples, into: <<>>, do: <<sample::signed-little-16>>

      rms_from_list = AudioAnalysis.calculate_rms(samples)
      rms_from_binary = AudioAnalysis.calculate_rms(binary)

      assert_in_delta rms_from_list, rms_from_binary, 0.0001
    end

    test "handles integer and float inputs" do
      int_samples = [100, 200, 300]
      float_samples = [100.0, 200.0, 300.0]

      assert AudioAnalysis.calculate_rms(int_samples) == AudioAnalysis.calculate_rms(float_samples)
    end

    test "handles empty list" do
      assert AudioAnalysis.calculate_rms([]) == 0.0
    end

    test "handles single sample" do
      sample_value = 16384.0
      expected = sample_value / @max_16bit
      assert_in_delta AudioAnalysis.calculate_rms([sample_value]), expected, 0.0001
    end

    test "normalizes to 0.0-1.0 range" do
      various_amplitudes = [100, 1000, 10000, 20000, -100, -1000, -10000]
      result = AudioAnalysis.calculate_rms(various_amplitudes)
      assert result >= 0.0 and result <= 1.0
    end
  end

  describe "calculate_zcr/1" do
    test "returns 0.0 for DC signal with no crossings" do
      dc_signal = List.duplicate(100, 1000)
      assert AudioAnalysis.calculate_zcr(dc_signal) == 0.0
    end

    test "returns 0.0 for all positive values" do
      positive_samples = [10, 20, 30, 40, 50]
      assert AudioAnalysis.calculate_zcr(positive_samples) == 0.0
    end

    test "returns 0.0 for all negative values" do
      negative_samples = [-10, -20, -30, -40, -50]
      assert AudioAnalysis.calculate_zcr(negative_samples) == 0.0
    end

    test "returns high ZCR for alternating positive and negative values" do
      alternating = for i <- 1..100, do: if(rem(i, 2) == 0, do: 100, else: -100)
      zcr = AudioAnalysis.calculate_zcr(alternating)
      assert zcr > 0.9
    end

    test "calculates correct ZCR for sine wave" do
      frequency = 5
      samples = for i <- 0..99, do: :math.sin(2 * :math.pi() * frequency * i / 100)

      zcr = AudioAnalysis.calculate_zcr(samples)
      assert zcr > 0.0
    end

    test "handles binary input" do
      samples = [100, -100, 100, -100, 100]
      binary = for sample <- samples, into: <<>>, do: <<sample::signed-little-16>>

      zcr_from_list = AudioAnalysis.calculate_zcr(samples)
      zcr_from_binary = AudioAnalysis.calculate_zcr(binary)

      assert zcr_from_list == zcr_from_binary
    end

    test "counts zero crossings correctly" do
      samples = [1, -1, 1, -1]
      zcr = AudioAnalysis.calculate_zcr(samples)
      assert zcr == 3 / 4
    end

    test "handles transition through zero" do
      samples = [10, 5, -5, -10, -5, 5, 10]
      zcr = AudioAnalysis.calculate_zcr(samples)
      assert zcr == 2 / 7
    end

    test "handles empty list" do
      assert AudioAnalysis.calculate_zcr([]) == 0.0
    end

    test "handles single sample" do
      assert AudioAnalysis.calculate_zcr([100]) == 0.0
    end

    test "normalizes to 0.0-1.0 range" do
      alternating = for i <- 1..100, do: if(rem(i, 2) == 0, do: 100, else: -100)
      result = AudioAnalysis.calculate_zcr(alternating)
      assert result >= 0.0 and result <= 1.0
    end
  end

  describe "calculate_peak/1" do
    test "returns 0.0 for silence" do
      silence = List.duplicate(0, 100)
      assert AudioAnalysis.calculate_peak(silence) == 0.0
    end

    test "returns 1.0 for maximum amplitude" do
      max_amp = round(@max_16bit - 1)
      samples = [0, 0, max_amp, 0, 0]
      assert_in_delta AudioAnalysis.calculate_peak(samples), 1.0, 0.01
    end

    test "finds peak in positive values" do
      samples = [100, 200, 10000, 300, 400]
      expected = 10000.0 / @max_16bit
      assert_in_delta AudioAnalysis.calculate_peak(samples), expected, 0.0001
    end

    test "finds peak in negative values using absolute value" do
      samples = [100, 200, -10000, 300, 400]
      expected = 10000.0 / @max_16bit
      assert_in_delta AudioAnalysis.calculate_peak(samples), expected, 0.0001
    end

    test "handles mix of positive and negative peaks" do
      samples = [5000, -10000, 8000, -3000]
      expected = 10000.0 / @max_16bit
      assert_in_delta AudioAnalysis.calculate_peak(samples), expected, 0.0001
    end

    test "handles binary input" do
      samples = [1000, -5000, 3000, -2000]
      binary = for sample <- samples, into: <<>>, do: <<sample::signed-little-16>>

      peak_from_list = AudioAnalysis.calculate_peak(samples)
      peak_from_binary = AudioAnalysis.calculate_peak(binary)

      assert_in_delta peak_from_list, peak_from_binary, 0.0001
    end

    test "handles empty list" do
      assert AudioAnalysis.calculate_peak([]) == 0.0
    end

    test "handles single sample" do
      sample_value = 16384.0
      expected = sample_value / @max_16bit
      assert_in_delta AudioAnalysis.calculate_peak([sample_value]), expected, 0.0001
    end

    test "normalizes to 0.0-1.0 range" do
      samples = [100, 1000, 10000, -15000, 20000]
      result = AudioAnalysis.calculate_peak(samples)
      assert result >= 0.0 and result <= 1.0
    end
  end

  describe "calculate_metrics/1" do
    test "returns map with all three metrics" do
      samples = [100, 200, -100, 300, -200]
      metrics = AudioAnalysis.calculate_metrics(samples)

      assert Map.has_key?(metrics, :rms)
      assert Map.has_key?(metrics, :zcr)
      assert Map.has_key?(metrics, :peak)
    end

    test "metrics have correct types" do
      samples = [100, 200, -100, 300, -200]
      metrics = AudioAnalysis.calculate_metrics(samples)

      assert is_float(metrics.rms)
      assert is_float(metrics.zcr)
      assert is_float(metrics.peak)
    end

    test "calculates correct metrics for silence" do
      silence = List.duplicate(0, 100)
      metrics = AudioAnalysis.calculate_metrics(silence)

      assert metrics.rms == 0.0
      assert metrics.zcr == 0.0
      assert metrics.peak == 0.0
    end

    test "calculates correct metrics for alternating signal" do
      alternating = for i <- 1..100, do: if(rem(i, 2) == 0, do: 10000, else: -10000)
      metrics = AudioAnalysis.calculate_metrics(alternating)

      assert metrics.rms > 0.0
      assert metrics.zcr > 0.9
      assert metrics.peak > 0.0
    end

    test "calculates correct metrics for sine wave" do
      amplitude = 10000.0
      samples = for i <- 0..99, do: amplitude * :math.sin(2 * :math.pi() * i / 100)
      metrics = AudioAnalysis.calculate_metrics(samples)

      assert metrics.rms > 0.0
      assert metrics.zcr > 0.0
      assert metrics.peak > 0.0
    end

    test "handles binary input" do
      samples = [1000, -2000, 3000, -1500, 2500]
      binary = for sample <- samples, into: <<>>, do: <<sample::signed-little-16>>

      metrics_from_list = AudioAnalysis.calculate_metrics(samples)
      metrics_from_binary = AudioAnalysis.calculate_metrics(binary)

      assert_in_delta metrics_from_list.rms, metrics_from_binary.rms, 0.0001
      assert metrics_from_list.zcr == metrics_from_binary.zcr
      assert_in_delta metrics_from_list.peak, metrics_from_binary.peak, 0.0001
    end

    test "all metrics are normalized to 0.0-1.0 range" do
      samples = for _i <- 0..999, do: :rand.uniform(20000) - 10000
      metrics = AudioAnalysis.calculate_metrics(samples)

      assert metrics.rms >= 0.0 and metrics.rms <= 1.0
      assert metrics.zcr >= 0.0 and metrics.zcr <= 1.0
      assert metrics.peak >= 0.0 and metrics.peak <= 1.0
    end

    test "handles long sample lists efficiently" do
      long_samples = for i <- 1..10000, do: rem(i, 2000) - 1000
      metrics = AudioAnalysis.calculate_metrics(long_samples)

      assert is_float(metrics.rms)
      assert is_float(metrics.zcr)
      assert is_float(metrics.peak)
    end

    test "handles empty list" do
      metrics = AudioAnalysis.calculate_metrics([])

      assert metrics.rms == 0.0
      assert metrics.zcr == 0.0
      assert metrics.peak == 0.0
    end
  end
end
