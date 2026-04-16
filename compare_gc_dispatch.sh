#!/bin/bash
# Compare GC dispatch overhead: built-in vs DSO path
# Runs interleaved rounds to cancel thermal drift.
#
# Usage: ./compare_gc_dispatch.sh /path/to/ruby [ROUNDS]

set -euo pipefail

RUBY="${1:?Usage: $0 /path/to/ruby [ROUNDS]}"
ROUNDS="${2:-5}"
SCRIPT="$(dirname "$0")/gc_dispatch_micro.rb"
CPU=$(( $(nproc) / 2 - 1 ))
PREFIX="setarch $(uname -m) -R taskset -c $CPU"

builtin_results=()
dso_results=()

for ((i=1; i<=ROUNDS; i++)); do
    echo "=== Round $i/$ROUNDS ==="

    # Alternate order each round
    if (( i % 2 == 1 )); then
        first="builtin" second="dso"
    else
        first="dso" second="builtin"
    fi

    for variant in "$first" "$second"; do
        if [[ "$variant" == "builtin" ]]; then
            echo "  [built-in]"
            ms=$($PREFIX "$RUBY" "$SCRIPT" 2>&1 | grep '^RESULT_MS=' | cut -d= -f2)
            builtin_results+=("$ms")
        else
            echo "  [dso]"
            ms=$($PREFIX env RUBY_GC_LIBRARY=default "$RUBY" "$SCRIPT" 2>&1 | grep '^RESULT_MS=' | cut -d= -f2)
            dso_results+=("$ms")
        fi
    done
done

echo
echo "=== Summary ==="
echo "Built-in times (ms): ${builtin_results[*]}"
echo "DSO times (ms):      ${dso_results[*]}"

# Compute means in awk
paste <(printf '%s\n' "${builtin_results[@]}") <(printf '%s\n' "${dso_results[@]}") | \
awk '
{
    b[NR] = $1; d[NR] = $2
    bs += $1; ds += $2; n++
}
END {
    bm = bs/n; dm = ds/n
    for (i=1; i<=n; i++) { bv += (b[i]-bm)^2; dv += (d[i]-dm)^2 }
    bsd = sqrt(bv/(n-1)); dsd = sqrt(dv/(n-1))
    ratio = bm/dm
    # Welch t-test
    t = (bm-dm) / sqrt(bsd^2/n + dsd^2/n)
    printf "\n"
    printf "Built-in:  %.2f ms  (± %.1f%%)\n", bm, (bsd/bm)*100
    printf "DSO:       %.2f ms  (± %.1f%%)\n", dm, (dsd/dm)*100
    printf "Ratio:     %.4f  (built-in / DSO)\n", ratio
    printf "Overhead:  %.2f%%\n", (1-ratio)*100
    printf "t-stat:    %.3f  (n=%d)\n", t, n
}'
