bindkey -v
eval "$(/opt/homebrew/bin/brew shellenv)"
# Load antidote: https://getantidote.github.io/
# Set the root name of the plugins files (.txt and .zsh) antidote will use.
zsh_plugins=${ZDOTDIR:-~}/.zsh_plugins

# Ensure the .zsh_plugins.txt file exists so you can add plugins.
[[ -f ${zsh_plugins}.txt ]] || touch ${zsh_plugins}.txt

# Lazy-load antidote from its functions directory.
fpath=(source $(brew --prefix)/opt/antidote/share/antidote/functions $fpath)
autoload -Uz antidote

# Generate a new static file whenever .zsh_plugins.txt is updated.
if [[ ! ${zsh_plugins}.zsh -nt ${zsh_plugins}.txt ]]; then
  antidote bundle <${zsh_plugins}.txt >|${zsh_plugins}.zsh
fi

# Source your static plugins file.
source ${zsh_plugins}.zsh

export PATH="$HOME/.tmuxifier/bin:$PATH"
# export PATH="/opt/homebrew/opt/curl/bin:$PATH"
# export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export XDG_CONFIG_HOME=$HOME/.config
# Customize to your needs...

autoload -Uz compinit && compinit
# Check that the function `starship_zle-keymap-select()` is defined.
# xref: https://github.com/starship/starship/issues/3418
type starship_zle-keymap-select >/dev/null || \
  {
    eval "$(starship init zsh)"
  }

alias vim=nvim
export EDITOR=nvim
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

if [ -d "/opt/homebrew/opt/ruby/bin" ]; then
  export PATH=/opt/homebrew/opt/ruby/bin:$PATH
  export PATH=`gem environment gemdir`/bin:$PATH
fi

source ${ZDOTDIR:-$HOME}/.zalias
for file in ${ZDOTDIR:-$HOME}/.zshrc.d/*.sh; do
    source "$file"
done

source $XDG_CONFIG_HOME/op/plugins.sh
source <(kubectl completion zsh)
