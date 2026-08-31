#!/bin/sh

now=${TMMX_NOW:-$(date +%s)}
columns=${TMMX_PICKER_COLUMNS:-${COLUMNS:-0}}
case "$columns" in *[!0-9]*|'') columns=0 ;; esac

awk -F '\t' -v now="$now" -v columns="$columns" '
  function clean(value, plain) { plain=value; gsub(/\033\[[0-9;]*m/, "", plain); return plain }
  function truncate(value, limit, plain) {
    plain=clean(value)
    if (length(plain) <= limit) return value
    if (limit < 1) return ""
    if (limit == 1) return "…"
    return substr(plain, 1, limit-1) "…"
  }
  function channel(start, finish, amount) { return int(start + (finish - start) * amount + 0.5) }
  function colour(age, amount, red, green, blue) {
    if (age <= 86400) {
      amount=age/86400; red=channel(163,94,amount); green=channel(190,145,amount); blue=channel(140,86,amount)
    } else if (age <= 259200) {
      amount=(age-86400)/172800; red=channel(235,214,amount); green=channel(203,168,amount); blue=channel(139,79,amount)
    } else {
      amount=(age-259200)/345600; if (amount > 1) amount=1; red=channel(224,191,amount); green=channel(108,97,amount); blue=channel(117,106,amount)
    }
    return sprintf("\033[38;2;%d;%d;%dm", red, green, blue)
  }
  {
    labels[NR]=$1; epochs[NR]=$2; timestamps[NR]=$3; targets[NR]=$4; widths[NR]=length(clean($1)); if (widths[NR] > max_width) max_width=widths[NR]
    if ($2 > 0) { age=now-$2; if (age < 0) age=0; ages[NR]=age }
  }
  END {
    for (i=1; i<=NR; i++) {
      if (epochs[i] > 0) { timestamp=colour(ages[i]) timestamps[i] "\033[0m" }
      else timestamp="\033[38;2;76;86;106mnever\033[0m"
      label=labels[i]; label_width=widths[i]
      if (columns > 2) {
        available=columns-8-length(timestamps[i])
        if (available < 1) { label=""; label_width=0; gap=0 }
        else {
          label_limit=available-1
          if (label_width > label_limit) { label=truncate(label, label_limit); label_width=length(clean(label)) }
          gap=available-label_width
        }
      } else gap=max_width+2-label_width
      printf "%s%*s\t%s\t%s\n", label, gap, "", timestamp, targets[i]
    }
  }
'
