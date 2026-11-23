#!/bin/sh
set -e

# Model effort · dir · ctx N% used/size · in N out N · 5h N% left · 7d N% left   (subscription)
# Model effort · dir · ctx N% used/size · in N out N · $X.XX                      (API pricing)
cat | jq -r --slurpfile s "$HOME/.claude/settings.json" '
  def c(n): "\u001b[" + n + "m";
  def paint(n): c(n) + . + c("0");
  def pct: floor | tostring;
  def tok: if . >= 1000000 then (. / 100000 | round / 10 | tostring) + "M"
    elif . >= 1000 then (. / 1000 | round | tostring) + "k" else tostring end;
  def usage_color: if . >= 80 then "31" elif . >= 50 then "33" else "32" end;
  def left_color: if . <= 20 then "31" elif . <= 50 then "33" else "32" end;
  (.workspace.current_dir // .cwd // "") as $dir
  | (.effort.level? // .effort? // $s[0].effortLevel // empty) as $effort
  | [
    ((.model.display_name // "Claude") | paint("1;35"))
      + (if ($effort | type) == "string" then " " + ($effort | paint("2")) else "" end),
    (if $dir != "" then ($dir | sub("^" + env.HOME; "~") | paint("1;36")) else empty end),
    (if .context_window.used_percentage != null then
      .context_window.used_percentage as $u
      | (.context_window.current_usage // {}) as $cu
      | .context_window.context_window_size as $size
      | (($cu.input_tokens // 0) + ($cu.cache_creation_input_tokens // 0)
          + ($cu.cache_read_input_tokens // 0)) as $used
      | ("ctx " + ($u | pct) + "% " + ($used | tok)
          + (if $size then "/" + ($size | tok) else "" end))
        | paint($u | usage_color)
     else empty end),
    (.context_window.total_input_tokens as $in
     | .context_window.total_output_tokens as $out
     | if $in != null or $out != null then
      ("in " + (($in // 0) | tok) + " out " + (($out // 0) | tok)) | paint("34")
     else empty end),
    (if .rate_limits then
      (if .rate_limits.five_hour.used_percentage != null then
        (100 - .rate_limits.five_hour.used_percentage) as $l
        | ("5h " + ($l | pct) + "% left") | paint($l | left_color)
       else empty end),
      (if .rate_limits.seven_day.used_percentage != null then
        (100 - .rate_limits.seven_day.used_percentage) as $l
        | ("7d " + ($l | pct) + "% left") | paint($l | left_color)
       else empty end)
     elif .cost.total_cost_usd != null then
      ("$" + (.cost.total_cost_usd * 100 | round / 100 | tostring)) | paint("33")
     else empty end)
  ] | join(" " + ("·" | paint("2")) + " ")
'
