echo "Install Homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo "Update and upgrade Homebrew"
brew update && brew upgrade
echo "Install essential tools"
brew install jq yq stow tmux tmuxifier starship \
    kubectl k9s awscli \
    neovim asdf ripgrep fzf \
    lazygit git gh
brew install --cask iterm2 1password 1password-cli

echo "Login to 1password"
op signin 
echo "Configure `gh` to use 1password CLI plugin"
op plugin init gh
echo "Clone dotfiles repo"
cd $HOME
gh clone khoinguyen/dotfiles
echo "Setup dotfiles"
cd dotfiles
./run.sh


echo "DONE!"
