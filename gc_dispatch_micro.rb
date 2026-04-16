#!/usr/bin/env ruby
# frozen_string_literal: true

# Standalone microbenchmark for GC modular dispatch overhead.
# Measures the per-call cost of GC.start on a near-empty heap.
#
# Usage:
#   ruby gc_dispatch_micro.rb            # built-in GC path
#   env RUBY_GC_LIBRARY=default ruby gc_dispatch_micro.rb  # DSO path
#
# Runs N_TRIALS independent measurements, each doing CALLS_PER_TRIAL
# GC.start invocations, then reports statistics.

N_TRIALS = 30
CALLS_PER_TRIAL = 50_000

# Stabilize the heap before we start measuring
GC.start(full_mark: true, immediate_sweep: true)
3.times { GC.start }

# Warmup — get everything hot
5.times do
  CALLS_PER_TRIAL.times { GC.start(full_mark: false, immediate_sweep: false) }
end

times = Array.new(N_TRIALS)

N_TRIALS.times do |i|
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  CALLS_PER_TRIAL.times { GC.start(full_mark: false, immediate_sweep: false) }
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  times[i] = t1 - t0
end

times_ms = times.map { |t| t * 1000.0 }
mean = times_ms.sum / times_ms.size
variance = times_ms.map { |t| (t - mean) ** 2 }.sum / (times_ms.size - 1)
stddev = Math.sqrt(variance)
sorted = times_ms.sort
median = sorted[sorted.size / 2]
per_call_us = (mean / CALLS_PER_TRIAL) * 1000.0

puts RUBY_DESCRIPTION
puts
puts "#{N_TRIALS} trials × #{CALLS_PER_TRIAL} calls"
puts "  mean:       %8.2f ms  (± %.1f%%)" % [mean, (stddev / mean) * 100]
puts "  median:     %8.2f ms" % median
puts "  stddev:     %8.2f ms" % stddev
puts "  min:        %8.2f ms" % sorted.first
puts "  max:        %8.2f ms" % sorted.last
puts "  per call:   %8.4f µs" % per_call_us
puts
# Machine-readable line for scripted comparison
puts "RESULT_MS=%.4f" % mean
