# brew install stow
stow --dotfiles --restow --no-folding dot-config -t ~/.config
stow --dotfiles --restow --no-folding zshrc -t ~
ln -s ~/.config/tmux/.tmux.conf ~/.tmux.conf
