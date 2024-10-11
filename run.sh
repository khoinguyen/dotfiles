# brew install stow
stow --dotfiles --restow --no-folding dot-config -t ~/.config
stow --dotfiles --restow --no-folding zshrc -t ~
if [[ -L ~/.tmux.conf ]]; then
  rm -rf ~/.tmux.conf
fi
ln -s ~/.config/tmux/.tmux.conf ~/.tmux.conf
