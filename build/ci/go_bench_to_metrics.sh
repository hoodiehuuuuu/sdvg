#!/usr/bin/env bash

INPUT_FILE="$1"
OUTPUT_FILE="$2"

> "$OUTPUT_FILE"

while IFS= read -r line; do
  if [[ "$line" == *"/CI/"* ]]; then
    # BenchmarkInteger/CI/bits-32-cpu-4   3435127  351.8 ns/op  90.95 MB/s  2842124 rows/s  22736989 values/s
    tokens=(${line})
    test_name="$(echo ${tokens[0]} | sed 's/Benchmark//; s/\/CI//; s/[-\/]*cpu-[0-9]*//')"
    mb_s="$(awk -v value="${tokens[4]}" 'BEGIN {printf "%.0f\n", value}')"
    m_values_s="$(awk -v value="${tokens[8]}" 'BEGIN {printf "%.0f\n", value}')"
    echo "${test_name}/MB/s ${mb_s}" >> "$OUTPUT_FILE"
    echo "${test_name}/Values/s ${m_values_s}" >> "$OUTPUT_FILE"
  fi
done < "$INPUT_FILE"
