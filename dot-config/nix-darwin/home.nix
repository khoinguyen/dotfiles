{ config, pkgs, ... }:
let 
  dotfiles_dir = ../..;
in
{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "khoinguyen";
  home.homeDirectory = "/Users/khoinguyen";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  home.file = {
    ".config/alacritty".source = dotfiles_dir + /dot-config/alacritty;
    ".config/starship.toml".source = dotfiles_dir + /dot-config/starship.toml;
    ".zshrc".source = dotfiles_dir + /zshrc/.zshrc;
    ".zalias".source = dotfiles_dir + /zshrc/.zalias;
    ".zsh_plugins.txt".source = dotfiles_dir + /zshrc/.zsh_plugins.txt;
    ".zshrc.d".source = dotfiles_dir + /zshrc/.zshrc.d;
  };
}
