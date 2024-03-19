
eval "$(/opt/homebrew/bin/brew shellenv)"

export PATH="$HOME/.tmuxifier/bin:$PATH"
# export PATH="/opt/homebrew/opt/curl/bin:$PATH"
# export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

export XDG_CONFIG_HOME=$HOME/.config
# Customize to your needs...

autoload -Uz compinit && compinit

export STARSHIP_CONFIG=~/.starship.toml
eval "$(starship init zsh)"

alias vim=nvim
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

export EDITOR=nvim
if [ -d "/opt/homebrew/opt/ruby/bin" ]; then
  export PATH=/opt/homebrew/opt/ruby/bin:$PATH
  export PATH=`gem environment gemdir`/bin:$PATH
fi

source ~/.zshrc.d/.zalias
for file in ~/.zshrc.d/*.sh; do
    source "$file"
done

