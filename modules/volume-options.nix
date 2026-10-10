{ lib, pkgs }:
let
  inherit (lib) mkOption types;
  customTypes = import ./types.nix { inherit lib; };
in
{
  freeformType = types.attrsOf types.anything;

  options = {
    # -------------------------------------------------------------
    # COMPOSE SPEC 07-VOLUMES.MD
    # -------------------------------------------------------------

    name = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Custom name for the volume on the container engine.";
    };

    driver = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Volume driver to use (e.g. 'local', 'flocker').";
    };

    driver_opts = mkOption {
      type = types.attrsOf (
        types.either types.str (types.either types.int (types.either types.float types.bool))
      );
      default = { };
      description = "Driver-specific options as key-value pairs.";
    };

    external = mkOption {
      type = types.nullOr customTypes.externalType;
      default = null;
      description = "Whether the volume's lifecycle is managed outside of this Compose stack.";
    };

    labels = mkOption {
      type = customTypes.labelsType;
      default = { };
      description = "Metadata labels for the volume.";
    };

    # -------------------------------------------------------------
    # EXTENSIONS & ESCAPE HATCH (Compose Spec 11-extension.md)
    # -------------------------------------------------------------

    extensions = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Extension fields (x-*) for this volume.";
    };

    extraYaml = mkOption {
      type = types.attrs;
      default = { };
      description = "Raw attributes merged directly into this volume definition.";
    };
  };
}
