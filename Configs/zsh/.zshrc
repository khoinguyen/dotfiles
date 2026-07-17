bindkey -v
eval "$(/opt/homebrew/bin/brew shellenv)"
# unsetopt correctall

# --- BEGIN antidote
# .zshrc
# Lazy-load antidote and generate the static load file only when needed
zsh_plugins=${ZDOTDIR:-$HOME}/.zsh_plugins
if [[ ! ${zsh_plugins}.zsh -nt ${zsh_plugins}.txt ]]; then
  (
    source /opt/homebrew/opt/antidote/share/antidote/antidote.zsh
    antidote bundle <${zsh_plugins}.txt >${zsh_plugins}.zsh
  )
fi
source ${zsh_plugins}.zsh
# --- END antidote
export PATH="$HOME/.local/bin:$PATH"
# export PATH="/opt/homebrew/opt/curl/bin:$PATH"
# export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export XDG_CONFIG_HOME=$HOME/.config
# Customize to your needs...

autoload -Uz compinit && compinit -C
# Check that the function `starship_zle-keymap-select()` is defined.
# xref: https://github.com/starship/starship/issues/3418
type starship_zle-keymap-select >/dev/null || \
  {
    eval "$(starship init zsh)"
  }

alias vim=nvim
alias v=vim
export EDITOR=nvim
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"


if [ -d "/opt/homebrew/opt/ruby/bin" ]; then
  export PATH=/opt/homebrew/opt/ruby/bin:$PATH
  export PATH=`gem environment gemdir`/bin:$PATH
fi

source ${ZDOTDIR:-$HOME}/.zalias
for file in ${ZDOTDIR:-$HOME}/.zshrc.d/*.sh(N); do
    source "$file"
done

source <(kubectl completion zsh)
eval "$(mise activate zsh)"
