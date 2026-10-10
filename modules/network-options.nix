{ lib, pkgs }:
let
  inherit (lib) mkOption types;
  customTypes = import ./types.nix { inherit lib; };
in
{
  freeformType = types.attrsOf types.anything;

  options = {
    # -------------------------------------------------------------
    # COMPOSE SPEC 06-NETWORKS.MD
    # -------------------------------------------------------------

    name = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Custom name for the network on the container engine.";
    };

    driver = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Driver to use for this network (e.g. 'bridge', 'overlay', 'macvlan', 'host', 'none').";
    };

    driver_opts = mkOption {
      type = types.attrsOf (
        types.either types.str (types.either types.int (types.either types.float types.bool))
      );
      default = { };
      description = "Driver-specific options as key-value pairs.";
    };

    attachable = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Allow standalone containers to attach to this network in addition to services.";
    };

    enable_ipv4 = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Enable or disable IPv4 address assignment (Compose v2.33.1+).";
    };

    enable_ipv6 = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Enable IPv6 address assignment.";
    };

    internal = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Create an externally isolated network with no outbound connectivity.";
    };

    external = mkOption {
      type = types.nullOr customTypes.externalType;
      default = null;
      description = "Whether the network's lifecycle is managed outside of this Compose stack.";
    };

    ipam = mkOption {
      type = types.nullOr customTypes.ipamType;
      default = null;
      description = "Custom IPAM (IP Address Management) configuration.";
    };

    labels = mkOption {
      type = customTypes.labelsType;
      default = { };
      description = "Metadata labels for the network.";
    };

    # -------------------------------------------------------------
    # EXTENSIONS & ESCAPE HATCH (Compose Spec 11-extension.md)
    # -------------------------------------------------------------

    extensions = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Extension fields (x-*) for this network.";
    };

    extraYaml = mkOption {
      type = types.attrs;
      default = { };
      description = "Raw attributes merged directly into this network definition.";
    };
  };
}
