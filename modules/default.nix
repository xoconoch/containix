{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    ;
  serializer = import ./serializer.nix { inherit lib pkgs; };
  customTypes = import ./types.nix { inherit lib; };

  # Submodules matching Compose Spec
  serviceSubmodule = types.submoduleWith {
    modules = [ (import ./service-options.nix { inherit lib pkgs; }) ];
  };

  networkSubmodule = types.submoduleWith {
    modules = [ (import ./network-options.nix { inherit lib pkgs; }) ];
  };

  volumeSubmodule = types.submoduleWith {
    modules = [ (import ./volume-options.nix { inherit lib pkgs; }) ];
  };

  configSubmodule = types.submoduleWith {
    modules = [ (import ./config-options.nix { inherit lib pkgs; }) ];
  };

  secretSubmodule = types.submoduleWith {
    modules = [ (import ./secret-options.nix { inherit lib pkgs; }) ];
  };

  modelSubmodule = types.submoduleWith {
    modules = [ (import ./model-options.nix { inherit lib pkgs; }) ];
  };

  # Project submodule covering Compose Spec 00 to 15
  projectModule =
    { name, config, ... }@submod:
    {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable this declarative compose project.";
        };

        backend = mkOption {
          type = types.enum [
            "docker"
            "podman"
          ];
          default = "docker";
          description = "Container engine backend to manage the compose project.";
        };

        name = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Compose top-level project name (Compose Spec 04-version-and-name.md).";
        };

        projectName = mkOption {
          type = types.str;
          default = if config.name != null then config.name else submod.name;
          description = "Docker Compose project name (-p / COMPOSE_PROJECT_NAME).";
        };

        version = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Top-level Compose file version (Compose Spec 04-version-and-name.md, obsolete/informative).";
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
          default = { };
          description = "Service specifications matching Compose Spec 05-services.md.";
        };

        networks = mkOption {
          type = types.attrsOf networkSubmodule;
          default = { };
          description = "Top-level networks definitions matching Compose Spec 06-networks.md.";
        };

        volumes = mkOption {
          type = types.attrsOf volumeSubmodule;
          default = { };
          description = "Top-level volumes definitions matching Compose Spec 07-volumes.md.";
        };

        configs = mkOption {
          type = types.attrsOf configSubmodule;
          default = { };
          description = "Top-level configs definitions matching Compose Spec 08-configs.md.";
        };

        secrets = mkOption {
          type = types.attrsOf secretSubmodule;
          default = { };
          description = "Top-level secrets definitions matching Compose Spec 09-secrets.md.";
        };

        models = mkOption {
          type = types.attrsOf modelSubmodule;
          default = { };
          description = "Top-level AI models definitions matching Compose Spec models.md.";
        };

        include = mkOption {
          type = types.listOf customTypes.includeType;
          default = [ ];
          description = "Top-level include element to import other Compose applications (Compose Spec 14-include.md).";
        };

        profiles = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Active Compose profiles to enable for this stack (Compose Spec 15-profiles.md).";
        };

        composeFiles = mkOption {
          type = types.listOf (types.either types.str (types.either types.path types.package));
          default = [ ];
          description = "Additional Compose files to merge in order via -f flags (Compose Spec 13-merge.md).";
        };

        extensions = mkOption {
          type = types.attrsOf types.anything;
          default = { };
          description = "Top-level extension fields (x-*) for Compose Spec 11-extension.md.";
        };

        extraYaml = mkOption {
          type = types.attrs;
          default = { };
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

  cfg = config.virtualisation.containix;

in
{
  options.virtualisation.containix = mkOption {
    type = types.attrsOf (types.submodule projectModule);
    default = { };
    description = "Declarative Docker/Podman Compose projects managed natively by systemd.";
  };

  config = mkIf (cfg != { }) {
    # 1. Automatically enable Docker / Podman if required by projects
    virtualisation.docker.enable = lib.mkDefault (
      lib.any (p: p.enable && p.backend == "docker") (lib.attrValues cfg)
    );

    virtualisation.podman =
      lib.mkIf (lib.any (p: p.enable && p.backend == "podman") (lib.attrValues cfg))
        {
          enable = lib.mkDefault true;
          dockerSocket.enable = lib.mkDefault true;
        };

    # 2. Generate native systemd services for each enabled project
    systemd.services = lib.mapAttrs' (
      name: p:
      let
        isDocker = p.backend == "docker";
        composeBin =
          if isDocker then
            "${pkgs.docker-compose}/bin/docker-compose"
          else
            "${pkgs.podman-compose}/bin/podman-compose";
        cliBin = if isDocker then "${pkgs.docker}/bin/docker" else "${pkgs.podman}/bin/podman";

        profileFlags = lib.concatMapStringsSep " " (prof: "--profile ${prof}") p.profiles;
        fileFlags = lib.concatStringsSep " " (
          [ "-f ${p.out.composeYaml}" ] ++ (map (f: "-f ${toString f}") p.composeFiles)
        );
        composeCmd = "${composeBin} ${fileFlags}${
          lib.optionalString (p.profiles != [ ]) " ${profileFlags}"
        }";
      in
      lib.nameValuePair "containix-${name}" (
        mkIf p.enable {
          description = "Declarative Compose Stack: ${p.projectName} (${p.backend})";
          wantedBy = [ "multi-user.target" ];
          after = [
            "network-online.target"
          ]
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
          }
          // lib.optionalAttrs (p.profiles != [ ]) {
            COMPOSE_PROFILES = lib.concatStringsSep "," p.profiles;
          };

          serviceConfig = {
            Type = "simple";
            RemainAfterExit = true;
            WorkingDirectory = "/var/lib/containix/${name}";
            StateDirectory = "containix/${name}";

            # Optional pre-pulling of images
            ExecStartPre = mkIf p.autoPull [
              "${composeCmd} pull --quiet"
            ];

            # Main start command
            ExecStart = ''
              ${composeCmd} up \
                ${lib.optionalString p.removeOrphans "--remove-orphans"} \
                --no-color
            '';

            # Stop / clean shutdown
            ExecStop = ''
              ${composeCmd} down \
                ${lib.optionalString p.removeOrphans "--remove-orphans"} \
                --timeout 30
            '';

            # Reload support (re-up with new derivation changes)
            ExecReload = ''
              ${composeCmd} up -d \
                ${lib.optionalString p.removeOrphans "--remove-orphans"}
            '';

            Restart = "on-failure";
            RestartSec = "15s";
            TimeoutStartSec = "10min";
            TimeoutStopSec = "2min";
          };
        }
      )
    ) cfg;
  };
}
