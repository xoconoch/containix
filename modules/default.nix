{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption mkEnableOption mkIf types;
  serializer = import ./serializer.nix { inherit lib pkgs; };

  # Service submodule
  serviceSubmodule = types.submoduleWith {
    modules = [ (import ./service-options.nix { inherit lib pkgs; }) ];
  };

  # Project submodule
  projectModule = { name, config, ... }: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable this declarative compose project.";
      };

      backend = mkOption {
        type = types.enum [ "docker" "podman" ];
        default = "docker";
        description = "Container engine backend to manage the compose project.";
      };

      projectName = mkOption {
        type = types.str;
        default = name;
        description = "Docker Compose project name (-p / COMPOSE_PROJECT_NAME).";
      };

      composeVersion = mkOption {
        type = types.str;
        default = "3.8";
        description = "Compose schema version.";
      };

      autoPull = mkOption {
        type = types.bool;
        default = false;
        description = "Pull images prior to starting containers on system boot.";
      };

      removeOrphans = mkOption {
        type = types.bool;
        default = true;
        description = "Remove containers for services not defined in the compose file.";
      };

      services = mkOption {
        type = types.attrsOf serviceSubmodule;
        default = {};
        description = "Service specifications matching Compose Spec 05-services.md.";
      };

      networks = mkOption {
        type = types.attrsOf types.attrs;
        default = {};
        description = "Top-level networks definitions.";
      };

      volumes = mkOption {
        type = types.attrsOf types.attrs;
        default = {};
        description = "Top-level volumes definitions.";
      };

      secrets = mkOption {
        type = types.attrsOf types.attrs;
        default = {};
        description = "Top-level secrets definitions.";
      };

      configs = mkOption {
        type = types.attrsOf types.attrs;
        default = {};
        description = "Top-level configs definitions.";
      };

      extraYaml = mkOption {
        type = types.attrs;
        default = {};
        description = "Raw top-level fields merged into the final Compose output.";
      };

      # Read-only derivation of generated YAML
      out = {
        composeYaml = mkOption {
          type = types.package;
          readOnly = true;
          description = "Derivation containing the evaluated compose.yaml.";
        };
      };
    };

    config = {
      out.composeYaml = serializer.serializeProject config;
    };
  };

  cfg = config.services.containix;

in {
  options.services.containix = mkOption {
    type = types.attrsOf (types.submodule projectModule);
    default = {};
    description = "Declarative Docker/Podman Compose projects managed natively by systemd.";
  };

  config = mkIf (cfg != {}) {
    # 1. Automatically enable Docker / Podman if required by projects
    virtualisation.docker.enable = lib.mkDefault (
      lib.any (p: p.enable && p.backend == "docker") (lib.attrValues cfg)
    );

    virtualisation.podman = lib.mkIf (lib.any (p: p.enable && p.backend == "podman") (lib.attrValues cfg)) {
      enable = lib.mkDefault true;
      dockerSocket.enable = lib.mkDefault true;
    };

    # 2. Generate native systemd services for each enabled project
    systemd.services = lib.mapAttrs' (name: p:
      let
        isDocker = p.backend == "docker";
        composeBin = if isDocker
          then "${pkgs.docker-compose}/bin/docker-compose"
          else "${pkgs.podman-compose}/bin/podman-compose";
        cliBin = if isDocker then "${pkgs.docker}/bin/docker" else "${pkgs.podman}/bin/podman";
      in lib.nameValuePair "containix-${name}" (mkIf p.enable {
        description = "Declarative Compose Stack: ${p.projectName} (${p.backend})";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ]
          ++ (lib.optional isDocker "docker.service")
          ++ (lib.optional (!isDocker) "podman.service");
        wants = [ "network-online.target" ];

        path = [
          (if isDocker then pkgs.docker-compose else pkgs.podman-compose)
          (if isDocker then pkgs.docker else pkgs.podman)
          pkgs.coreutils
        ];

        environment = {
          COMPOSE_PROJECT_NAME = p.projectName;
        };

        serviceConfig = {
          Type = "simple";
          RemainAfterExit = true;
          WorkingDirectory = "/var/lib/containix/${name}";
          StateDirectory = "containix/${name}";

          # Optional pre-pulling of images
          ExecStartPre = mkIf p.autoPull [
            "${composeBin} -f ${p.out.composeYaml} pull --quiet"
          ];

          # Main start command
          ExecStart = ''
            ${composeBin} -f ${p.out.composeYaml} up \
              ${lib.optionalString p.removeOrphans "--remove-orphans"} \
              --no-color
          '';

          # Stop / clean shutdown
          ExecStop = ''
            ${composeBin} -f ${p.out.composeYaml} down \
              ${lib.optionalString p.removeOrphans "--remove-orphans"} \
              --timeout 30
          '';

          # Reload support (re-up with new derivation changes)
          ExecReload = ''
            ${composeBin} -f ${p.out.composeYaml} up -d \
              ${lib.optionalString p.removeOrphans "--remove-orphans"}
          '';

          Restart = "on-failure";
          RestartSec = "15s";
          TimeoutStartSec = "10min";
          TimeoutStopSec = "2min";
        };
      })
    ) cfg;
  };
}
