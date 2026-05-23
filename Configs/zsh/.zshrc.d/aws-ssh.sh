# Update the EC2 SSH ingress rule marked `khoi-auto-ssh` to my current public
# IP, for the instance behind a given ssh-config host alias.
#
#   ssh-allow <ssh-host-alias>      # e.g. ssh-allow ampup-ftp
#
# Flow: alias -> HostName (public IP, via `ssh -G`) -> EC2 instance ->
# security groups -> ingress tcp/22 rules whose Description is exactly the
# marker -> rewrite each to my current public IP, preserving the rule's
# address family (v4 -> /32, v6 -> /128).
#
# Only rules carrying the marker are touched. Hosts where I'm not explicitly
# marked (e.g. the shared bastion, whose broad access is intentional) are left
# untouched. To onboard a new host, set one of its tcp/22 ingress rule
# descriptions to `khoi-auto-ssh` in the AWS console, then run this.
ssh-allow() {
  emulate -L zsh
  local marker="khoi-auto-ssh"
  local region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-2}}"
  local host_alias="$1"

  if [[ -z "$host_alias" ]]; then
    print -u2 "usage: ssh-allow <ssh-host-alias>"
    return 1
  fi

  local host
  host=$(ssh -G "$host_alias" 2>/dev/null | awk '/^hostname /{print $2; exit}')
  if [[ -z "$host" ]]; then
    print -u2 "ssh-allow: could not resolve a HostName for '$host_alias'"
    return 1
  fi

  local sgids
  sgids=$(aws ec2 describe-instances --region "$region" \
    --filters "Name=ip-address,Values=$host" \
    --query 'Reservations[].Instances[].SecurityGroups[].GroupId' \
    --output text 2>/dev/null)
  if [[ -z "$sgids" ]]; then
    print -u2 "ssh-allow: no EC2 instance found in $region with public IP $host (alias '$host_alias')"
    return 1
  fi

  local ip4 ip6
  ip4=$(curl -fsS4 --max-time 5 https://api.ipify.org 2>/dev/null)
  ip6=$(curl -fsS6 --max-time 5 https://api6.ipify.org 2>/dev/null)

  local updated=0 sg rid v4 v6
  for sg in ${=sgids}; do
    while IFS=$'\t' read -r rid v4 v6; do
      [[ -z "$rid" ]] && continue
      local key newcidr oldcidr
      if [[ -n "$v4" && "$v4" != "None" ]]; then
        if [[ -z "$ip4" ]]; then
          print -u2 "ssh-allow: rule $rid is IPv4 but no current IPv4 detected"
          continue
        fi
        key="CidrIpv4"; newcidr="$ip4/32"; oldcidr="$v4"
      elif [[ -n "$v6" && "$v6" != "None" ]]; then
        if [[ -z "$ip6" ]]; then
          print -u2 "ssh-allow: rule $rid is IPv6 but no current IPv6 detected"
          continue
        fi
        key="CidrIpv6"; newcidr="$ip6/128"; oldcidr="$v6"
      else
        continue
      fi

      if [[ "$oldcidr" == "$newcidr" ]]; then
        print "ssh-allow: $host_alias ($sg/$rid) already at $newcidr"
        updated=1
        continue
      fi

      if aws ec2 modify-security-group-rules --region "$region" --group-id "$sg" \
        --security-group-rules "[{\"SecurityGroupRuleId\":\"$rid\",\"SecurityGroupRule\":{\"IpProtocol\":\"tcp\",\"FromPort\":22,\"ToPort\":22,\"$key\":\"$newcidr\",\"Description\":\"$marker\"}}]" \
        >/dev/null 2>&1; then
        print "ssh-allow: $host_alias ($sg/$rid) $oldcidr -> $newcidr"
        updated=1
      else
        print -u2 "ssh-allow: failed to update $sg/$rid"
      fi
    done < <(aws ec2 describe-security-group-rules --region "$region" \
      --filters "Name=group-id,Values=$sg" \
      --query "SecurityGroupRules[?IsEgress==\`false\` && FromPort==\`22\` && ToPort==\`22\` && Description=='$marker'].[SecurityGroupRuleId,CidrIpv4,CidrIpv6]" \
      --output text 2>/dev/null)
  done

  if [[ "$updated" -eq 0 ]]; then
    print -u2 "ssh-allow: no tcp/22 rule marked '$marker' found for '$host_alias' — nothing changed"
    return 1
  fi
}
