require_relative '../harness/loader'

# Without any `frozen_string_literal` magic comment (the Ruby 3.4+ default),
# each mutable string literal compiles to the `dupchilledstring` instruction,
# which resurrects the frozen literal into a fresh, chilled String. This is the
# case the overwhelming majority of un-annotated Ruby code hits. ZJIT can
# allocate that String inline via its GC fast path, so this loop stresses that
# allocation path.
#
# The literals are assigned to a local (rather than left as bare statements) so
# the compiler does not discard them as dead, pure expressions. The assignments
# still allocate a fresh String each time.
def dup_chilled_strings
  i = 0
  s = nil
  while i < 1_000_000
    # 10 short (embeddable) literals per iteration to de-emphasize loop overhead.
    s = "the quick brown fox"
    s = "the quick brown fox"
    s = "the quick brown fox"
    s = "the quick brown fox"
    s = "the quick brown fox"
    s = "the quick brown fox"
    s = "the quick brown fox"
    s = "the quick brown fox"
    s = "the quick brown fox"
    s = "the quick brown fox"
    i += 1
  end
  s
end

run_benchmark(100) do
  dup_chilled_strings
end
