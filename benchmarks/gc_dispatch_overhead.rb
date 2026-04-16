# Microbenchmark for GC module dispatch overhead
#
# Calls GC.start in a tight loop to isolate the per-call cost of the
# modular GC function pointer dispatch vs direct built-in calls.
# The actual mark/sweep work per call is minimized by keeping the heap
# small and clean — we're measuring call overhead, not GC work.

require_relative '../harness/loader'

# Pre-allocate a small heap so each GC.start does minimal actual work
GC.start(full_mark: true, immediate_sweep: true)

run_benchmark(10) do
  50_000.times do
    GC.start(full_mark: false, immediate_sweep: false)
  end
end
