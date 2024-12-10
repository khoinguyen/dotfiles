{ config, pkgs, lib, ... }:
let 
  dotfiles_dir = ../..;
  homeDir = "/Users/khoinguyen";
in
{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "khoinguyen";
  home.homeDirectory = homeDir;

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
  programs.alacritty = {
    enable = true;
    settings = {
      font.normal = {
        family = "FiraCode Nerd Font";
        style = "Regular";
      };
      font.bold = {
        family = "FiraCode Nerd Font";
        style = "Bold";
      };
      font.italic = {
        family = "FiraCode Nerd Font";
        style = "Italic";
      };
    };
  };
  programs.nushell = {
    enable = true;
    shellAliases = {
      "kc" = "kubectl";
    };
    configFile = {
      text  = ''
      def kg [...args] {
        kubectl get ...$args | from ssv
      }    
      def kd [...args] {
        kubectl get ...$args -o json | from json
      }
      '';

    };
  };
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    envExtra = "source ~/.zalias";
    autocd = true;
    initExtra = ''
      . "${pkgs.asdf-vm}/share/asdf-vm/asdf.sh"

      # >>> mamba initialize >>>
      # !! Contents within this block are managed by 'micromamba shell init' !!
      export MAMBA_EXE='/opt/homebrew/bin/micromamba';
      export MAMBA_ROOT_PREFIX="$HOME/.local/share/mamba";
      __mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
      if [ $? -eq 0 ]; then
        eval "$__mamba_setup"
      else
        alias micromamba="$MAMBA_EXE"  # Fallback on help from micromamba activate
      fi
      unset __mamba_setup
      # <<< mamba initialize <<<
      
      # Integration for .iterm2
      test -e "${homeDir}/.iterm2_shell_integration.zsh" && source "${homeDir}/.iterm2_shell_integration.zsh"
      for file in ${homeDir}/.zshrc.d/*.sh; do
          source "$file"
      done
    '';
  };
  programs.bat.enable = true;
  programs.bat.config = {
    theme = "Coldark-Dark";
  };
  programs.pet.enable = true;
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.fd = {
    enable = true;
  };
  programs.fastfetch.enable = true;
  # TODO: Migrate from antidote brew to fully control by home-manager
  # TODO: Migrate zsh configuration from dotfiles to control by home-manager
  programs.zsh.antidote = {
    enable = true;
    plugins = [
      "rupa/z"
      "zsh-users/zsh-syntax-highlighting"
      "zsh-users/zsh-completions"
      "zsh-users/zsh-history-substring-search"
      "joshskidmore/zsh-fzf-history-search"
      "zsh-users/zsh-autosuggestions"
      "atuinsh/atuin"
    ];
  };
  programs.starship = {
    enable = true;
    # Configuration written to ~/.config/starship.toml
    settings = pkgs.lib.importTOML (dotfiles_dir + /dot-config/starship.toml);
  };
  home.sessionPath = [
    "/opt/homebrew/bin"

  ];
  home.file = {
    ".config/skhd/skhdrc".source = dotfiles_dir + /dot-config/skhd/skhdrc;
    ".zalias".source = dotfiles_dir + /zshrc/dot-zalias;
    ".zshrc.d".source = dotfiles_dir + /zshrc/dot-zshrc.d;
    ".config/nvim".source = dotfiles_dir + /dot-config/nvim;
  };
  home.activation = {
    debugAction = lib.hm.dag.entryAfter ["setupLaunchAgents"] ''
      echo "After setupLaunchAgents"
      run ${pkgs.skhd}/bin/skhd -r
    '';

  };
}
