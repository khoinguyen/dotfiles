# Fuzzy-pick a configured SSH host and connect to it.
#
#   sshf
#
# Lists every Host alias from ~/.ssh/config and ~/.ssh/config.d/*.conf
# (wildcard patterns like `Host *` excluded), pipes them through fzf, and
# ssh's into the selection. An optional argument pre-fills the fzf query.
sshf() {
  emulate -L zsh
  local -a files=(~/.ssh/config ~/.ssh/config.d/*.conf(N))
  local host
  host=$(awk 'tolower($1)=="host"{for(i=2;i<=NF;i++) if($i !~ /[*?]/) print $i}' $files 2>/dev/null \
    | sort -u \
    | fzf --height=40% --reverse --prompt='ssh ❯ ' --query="${1:-}") || return
  [[ -n "$host" ]] && ssh "$host"
}
