#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 before.txt after.txt [--allowed-inaccuracy=5] [--alert-threshold=20]"
  exit 1
fi

BEFORE_FILE="$1"
AFTER_FILE="$2"
ALLOWED_INACCURACY=5     # фильтр по изменению
ALERT_THRESHOLD=20       # "сильное изменение"

for arg in "$@"; do
  case "$arg" in
    --allowed-inaccuracy=*)
      ALLOWED_INACCURACY="${arg#*=}"
      ;;
    --alert-threshold=*)
      ALERT_THRESHOLD="${arg#*=}"
      ;;
  esac
done

TMP_BEFORE=$(mktemp)
TMP_AFTER=$(mktemp)

average_metrics() {
  awk '
  {
    name=$1
    val=$2
    sum[name]+=val
    count[name]++
  }
  END {
    for (n in sum) {
      avg = sum[n] / count[n]
      printf "%s %.0f\n", n, avg
    }
  }' "$1" | sort
}

average_metrics "$BEFORE_FILE" > "$TMP_BEFORE"
average_metrics "$AFTER_FILE"  > "$TMP_AFTER"

fmt_num() {
  local num=$1
  if (( num >= 1000000 )); then
    awk -v n="$num" 'BEGIN {printf "%.2fM", n/1000000}'
  elif (( num >= 1000 )); then
    awk -v n="$num" 'BEGIN {printf "%.2fK", n/1000}'
  else
    echo "$num"
  fi
}

REPORT=""

while read -r metric before after; do
  [[ -z "$before" || -z "$after" ]] && continue

  # check the percentage of changes
  change=$(awk -v b="$before" -v a="$after" 'BEGIN {
    if (b == 0) { print 0; exit }
    printf "%.2f", ((a - b) / b) * 100
  }')

  abs_change=$(awk -v c="$change" 'BEGIN { if (c<0) c*=-1; print c }')

  # filter by allowed-inaccuracy
  pass_filter=$(awk -v c="$abs_change" -v th="$ALLOWED_INACCURACY" \
    'BEGIN {print (c > th ? 1 : 0)}')

  if [[ "$pass_filter" -eq 1 ]]; then
    sign=$(awk -v c="$change" 'BEGIN {if (c>0) print "+"; else print ""}')
    before_fmt=$(fmt_num "$before")
    after_fmt=$(fmt_num "$after")

    # checking for a significant change
    alert_col=""
    over_alert=$(awk -v c="$abs_change" -v th="$ALERT_THRESHOLD" \
      'BEGIN {print (c > th ? 1 : 0)}')
    [[ "$over_alert" -eq 1 ]] && alert_col="⚠️"

    REPORT+="| $metric | $before_fmt | $after_fmt | ${sign}${change}% | $alert_col |\n"
  fi
done < <(join "$TMP_BEFORE" "$TMP_AFTER")

echo
if [[ -n "$REPORT" ]]; then
  echo "| Metric | Before | After | Δ% | Significant changes |"
  echo "|--------|--------|-------|----|---------------------|"
  echo -e "$REPORT"
else
  echo "There are no significant changes — all the differences are less ${ALLOWED_INACCURACY}%"
fi

