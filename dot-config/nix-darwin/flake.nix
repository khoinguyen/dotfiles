{
  description = "Karti Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

#    homebrew-core = {
#      url = "github:homebrew/homebrew-core";
#      flake = false;
#    };
#    homebrew-cask = {
#      url = "github:homebrew/homebrew-cask";
#      flake = false;
#    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, home-manager }:
  let
    configuration = { pkgs, config, ... }: {
      # List packages installed in system profile. To search by name, run:
      
      # $ nix-env -qaP | grep wget
      nixpkgs.config.allowUnfree = true;
      environment.systemPackages =
        [ 
          # fonts
          pkgs.fira-code-nerdfont
          pkgs.sketchybar-app-font          
          
          # basic packages
          pkgs.thefuck
          pkgs.atuin
          pkgs.starship
          pkgs.mkalias
          pkgs.neovim
          pkgs.zoxide
          pkgs.tree
          pkgs.fd
          pkgs.fzf
          pkgs.skhd
          pkgs.sketchybar
          pkgs.yazi
          # development
          pkgs.asdf-vm
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
          
          # GUI Apps
          #pkgs.alacritty
          
        ];
      homebrew = {
        enable = true;
        taps = [
          "nikitabobko/tap"
          "fluxcd/tap"
        ];
        brews = [ 
          "mas"
          "zoxide"
          "fluxcd/tap/flux@2.2"
          "logcli"
          "micromamba"
        #  "wireguard-go"
          "antidote"
          "golang"
        ];
        casks = [
          "hammerspoon"
          "aerospace"
          "1password"
#          "amethyst"
          "1password-cli"
          "slack"
          "postman"
          "mongodb-compass"
          "keepingyouawake"
          "zoom"
          "notion"
          "visual-studio-code"
          "orbstack"
        ];

        masApps = {
          "Pine Player" = 1112075769;
        };
        onActivation.cleanup = "zap";
        onActivation.autoUpdate = true;
        onActivation.upgrade = true;
      };

      fonts.packages = [
        (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
        pkgs.fira-code-nerdfont
      ];
      # Auto upgrade nix package and the daemon service.
      services.nix-daemon.enable = true;
      # nix.package = pkgs.nix;
      system.activationScripts.applications.text = let
        env = pkgs.buildEnv {
          name = "system-applications";
          paths = config.environment.systemPackages;
          pathsToLink = "/Applications";
        };
      in
        pkgs.lib.mkForce ''
          # Set up applications.
          echo "Setting up /Applications..." >&2
          rm -rf /Applications/Nix\ Apps
          mkdir -p /Applications/Nix\ Apps
          find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
          while read src; do
            app_name=$(basename "$src")
            echo "copying $src" >&2
            ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
          done
        '';
      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Create /etc/zshrc that loads the nix-darwin environment.
      programs.zsh.enable = true;  # default shell on catalina
      # programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # press and hold to repeat instead of shows alternative chars
      # this help to boost navigation in vim
      system.defaults.NSGlobalDomain.ApplePressAndHoldEnabled = false;
      # click the scroller to mvoe to the position
      system.defaults.NSGlobalDomain.AppleScrollerPagingBehavior = true;

      # $ darwin-rebuild changelog
      system.stateVersion = 5;

      security.pam.enableSudoTouchIdAuth = true;
      users.users.khoinguyen.home = "/Users/khoinguyen";
      nix.configureBuildUsers = true;
      nix.useDaemon = true;


    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#Khois-MacBook-Pro
    darwinConfigurations."Khois-MacBook-Pro" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [ 
        configuration 
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            # Install Homebrew under the default prefix
            enable = true;

            # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
            enableRosetta = true;

            # User owning the Homebrew prefix
            user = "khoinguyen";

            # Automatically migrate existing Homebrew installations
            autoMigrate = true;
          };
        }
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "nixbk";
          home-manager.users.khoinguyen = import ./home.nix;
          # Optionally, use home-manager.extraSpecialArgs to pass
          # arguments to home.nix
        }
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."Khois-MacBook-Pro".pkgs;
  };
}
