{ lib }:
let
  inherit (lib) types mkOption;
in
rec {
  # Value that can be passed as a single string or a list of strings (e.g. entrypoint, command, dns, dns_search)
  stringOrList = types.either types.str (types.listOf types.str);

  # Labels: either array of "KEY=VAL" / "KEY" or attribute set of key-value pairs (Compose Spec 05, 06, 07, 08, 09)
  labelsType = types.either (types.listOf types.str) (
    types.attrsOf (types.nullOr (types.either types.str (types.either types.int types.bool)))
  );

  # External resource: boolean or object { name = "..."; } (Compose Spec 06, 07, 08, 09)
  externalType = types.either types.bool (
    types.submodule {
      options = {
        name = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The name of the external resource to look up.";
        };
      };
    }
  );

  # Port specification: can be integer, string "8080:80", or long-form object
  portType = types.either types.str (
    types.either types.int (
      types.submodule {
        options = {
          target = mkOption {
            type = types.int;
            description = "Port inside container";
          };
          published = mkOption {
            type = types.nullOr (types.either types.int types.str);
            default = null;
            description = "Host port";
          };
          protocol = mkOption {
            type = types.enum [
              "tcp"
              "udp"
            ];
            default = "tcp";
          };
          mode = mkOption {
            type = types.enum [
              "host"
              "ingress"
            ];
            default = "ingress";
          };
          host_ip = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
        };
      }
    )
  );

  # Volume mount specification: short syntax (string) or long syntax (object)
  volumeType = types.either types.str (
    types.submodule {
      options = {
        type = mkOption {
          type = types.enum [
            "volume"
            "bind"
            "tmpfs"
            "npipe"
            "cluster"
          ];
        };
        source = mkOption { type = types.str; };
        target = mkOption { type = types.str; };
        read_only = mkOption {
          type = types.nullOr types.bool;
          default = null;
        };
        bind = mkOption {
          type = types.nullOr types.attrs;
          default = null;
        };
        volume = mkOption {
          type = types.nullOr types.attrs;
          default = null;
        };
        tmpfs = mkOption {
          type = types.nullOr types.attrs;
          default = null;
        };
      };
    }
  );

  # Healthcheck definition
  healthcheckType = types.submodule {
    options = {
      test = mkOption {
        type = types.nullOr stringOrList;
        default = null;
        description = "Healthcheck test command";
      };
      interval = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "30s";
      };
      timeout = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "10s";
      };
      retries = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = 3;
      };
      start_period = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "5s";
      };
      start_interval = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "1s";
      };
      disable = mkOption {
        type = types.bool;
        default = false;
      };
    };
  };

  # Depends_on definition: list of strings or map of dependency conditions
  dependsOnType = types.either (types.listOf types.str) (
    types.attrsOf (
      types.submodule {
        options = {
          condition = mkOption {
            type = types.enum [
              "service_started"
              "service_healthy"
              "service_completed_successfully"
            ];
            default = "service_started";
          };
          restart = mkOption {
            type = types.nullOr types.bool;
            default = null;
          };
          required = mkOption {
            type = types.bool;
            default = true;
          };
        };
      }
    )
  );

  # IPAM network configuration elements (Compose Spec 06-networks.md)
  ipamConfigType = types.submodule {
    options = {
      subnet = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Subnet in CIDR format (e.g. 172.28.0.0/16).";
      };
      ip_range = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Range of IPs from which to allocate container IPs.";
      };
      gateway = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "IPv4 or IPv6 gateway for the master subnet.";
      };
      aux_addresses = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Auxiliary IPv4 or IPv6 addresses mapping hostname to IP.";
      };
    };
  };

  # IPAM network configuration block (Compose Spec 06-networks.md)
  ipamType = types.submodule {
    options = {
      driver = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Custom IPAM driver.";
      };
      config = mkOption {
        type = types.listOf ipamConfigType;
        default = [ ];
        description = "List of IPAM configuration blocks.";
      };
      options = mkOption {
        type = types.attrsOf (types.either types.str (types.either types.int types.bool));
        default = { };
        description = "Driver-specific IPAM options.";
      };
    };
  };

  # Include specification (Compose Spec 14-include.md)
  includeType = types.either types.str (
    types.submodule {
      options = {
        path = mkOption {
          type = stringOrList;
          description = "Path to the Compose file(s) to include.";
        };
        project_directory = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Directory used to resolve relative paths in the included Compose file.";
        };
        env_file = mkOption {
          type = types.nullOr (types.either types.str (types.listOf types.str));
          default = null;
          description = "Environment file(s) defining default values for variable interpolation.";
        };
      };
    }
  );
}
