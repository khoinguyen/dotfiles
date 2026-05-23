# Refresh the IP allowlist on my dedicated Gemini ("Khoi Local Dev") API key
# to my current public IP(s). The key is locked to a set of source IPs that go
# stale whenever my network changes; this clears the old list and sets it to my
# current IPv4 and/or IPv6 (whichever is reachable -- some networks are v6-only).
#
#   gemini-allow
#
# The key's API-target restriction (generativelanguage only) MUST be re-sent on
# every update: gcloud treats --clear-restrictions and the --allowed-*/--api-target
# flags as one mutually-exclusive group, so passing --allowed-ips alone would drop
# the API target and broaden the key. Existing API targets are read back and
# re-applied automatically.
gemini-allow() {
  emulate -L zsh
  local key="${GEMINI_KEY_ID:-288dbbeb-5327-4e76-a9ac-5cfc02b5bff4}"
  local project="${GEMINI_KEY_PROJECT:-ampup-network}"

  local ip4 ip6
  ip4=$(curl -fsS4 --max-time 5 https://api.ipify.org 2>/dev/null)
  ip6=$(curl -fsS6 --max-time 5 https://api6.ipify.org 2>/dev/null)

  local -a ips
  [[ -n "$ip4" ]] && ips+=("$ip4")
  [[ -n "$ip6" ]] && ips+=("$ip6")
  if (( ${#ips} == 0 )); then
    print -u2 "gemini-allow: could not detect any public IP"
    return 1
  fi

  # Read existing API targets so the update doesn't drop them (would broaden the key).
  local targets_csv
  targets_csv=$(gcloud services api-keys describe "$key" --project="$project" \
    --format='value[separator=","](restrictions.apiTargets[].service)' 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    print -u2 "gemini-allow: could not describe key $key in $project"
    return 1
  fi

  local svc
  local -a target_flags
  for svc in ${(s:,:)targets_csv}; do
    [[ -n "$svc" ]] && target_flags+=("--api-target=service=$svc")
  done

  local ip_list="${(j:,:)ips}"
  if gcloud services api-keys update "$key" --project="$project" \
      "${target_flags[@]}" --allowed-ips="$ip_list" --quiet >/dev/null 2>&1; then
    print "gemini-allow: $key allowed-ips -> $ip_list"
  else
    print -u2 "gemini-allow: failed to update key $key"
    return 1
  fi
}
