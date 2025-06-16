{ config, pkgs, lib, ... }:
let 
  dotfiles_dir = ../..;
  homeDir = "/Users/khoinguyen";
  nvimDir = dotfiles_dir + ./nvim;
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
  home.stateVersion = "24.11";

  # Let Home Manager install and manage itself.

  programs.home-manager.enable = true;
  # Wezterm from nixpkgs not render text correctly
  # programs.wezterm = {
  #   enable = true;
  #   extraConfig = ''
  #     local wezterm = require 'wezterm'

  #     return {
  #       font = wezterm.font("MesloLGL Nerd Font Mono"),
  #     }

  #   '';
  # };
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
  programs.fish = {
    enable = true;
    shellAliases = {
      "vim" = "nvim";
      "nv"  = "vim ${homeDir}/dotfiles/dot-config/nix-darwin";
      "nr"  = "sudo darwin-rebuild switch --flake ~/dotfiles/dot-config/nix-darwin#$(uname -o)-$(uname -m)";
    };
    interactiveShellInit = ''
      set -g fish_key_bindings fish_vi_key_bindings
    '';
    shellInitLast = ''
      zoxide init fish | source
    '';
    plugins = [
      { name = "done"; src = pkgs.fishPlugins.done; }
      { name = "git-abbr"; 
        src = pkgs.fetchFromGitHub {
          owner = "lewisacidic";
          repo = "fish-git-abbr";
          rev = "9967009cf7b14459f5062d9d55e2840801746bb6";
          sha256 = "sha256-wye76M1fkKEmEGJI9zXBIgLr7T8dBIgJudwTXWOIFjg=";
        };
      }
      { name = "grc"; src = pkgs.fishPlugins.grc; }
      { name = "async-prompt"; src = pkgs.fishPlugins.async-prompt; }
    ];
    shellAbbrs = {
      "kg" = "kubectl get";
      "kgoy" = {
        setCursor = true;
        expansion = "kubectl get % -o yaml";
      };
    };
  };
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    envExtra = "source ~/.zalias";
    shellAliases = {
      "v" = "nvim";
      "nr"  = "sudo darwin-rebuild switch --flake ~/dotfiles/dot-config/nix-darwin#$(uname -o)-$(uname -m)";

    };
    autocd = true;
    initContent = ''
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
      "jeffreytse/zsh-vi-mode"
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
  home.packages = [

    pkgs.nerd-fonts.fira-code

    # basic packages
    pkgs.atuin
    pkgs.starship
    pkgs.mkalias
    pkgs.neovim
    pkgs.zoxide
    pkgs.tree
    pkgs.fd
    pkgs.fzf

    # development
    pkgs.asdf-vm
    pkgs.sops
    pkgs.rbenv
    pkgs.jq
    pkgs.yq
    pkgs.gnupg
    pkgs.lazygit
    pkgs.gh
    pkgs.dive
    pkgs.git
    pkgs.wireguard-tools
    pkgs.go
    # python

    # cloud 
    pkgs.k9s
    pkgs.cloudlens
    pkgs.awscli2
    pkgs.istioctl
    pkgs.kubectl
    pkgs.kubernetes-helm
    pkgs.kubeseal
    pkgs.eksctl
    pkgs.kustomize
    pkgs.steampipe
    pkgs.steampipePackages.steampipe-plugin-aws

    pkgs.devbox
    # GUI Apps
    #pkgs.alacritty
  ];
  xdg.configFile.nvim = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/nvim";
  };
  home.file = {
    ".config/skhd/skhdrc".source = dotfiles_dir + /dot-config/skhd/skhdrc;
    ".zalias".source = dotfiles_dir + /zshrc/dot-zalias;
    ".zshrc.d".source = dotfiles_dir + /zshrc/dot-zshrc.d;
  };
  home.activation = {
    debugAction = lib.hm.dag.entryAfter ["setupLaunchAgents"] ''
      echo "After setupLaunchAgents"
    '';

  };
}
