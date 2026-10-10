{ lib, pkgs }:
let
  inherit (lib) mkOption types;
  customTypes = import ./types.nix { inherit lib; };
in
{
  freeformType = types.attrsOf types.anything;

  options = {
    # -------------------------------------------------------------
    # COMPOSE SPEC 08-CONFIGS.MD
    # -------------------------------------------------------------

    name = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The name of the config object in the container engine to look up.";
    };

    file = mkOption {
      type = types.nullOr (types.either types.path types.str);
      default = null;
      description = "Path to file containing configuration data.";
    };

    environment = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Name of the environment variable providing configuration data.";
    };

    content = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Inlined configuration content (Compose v2.23.1+).";
    };

    external = mkOption {
      type = types.nullOr customTypes.externalType;
      default = null;
      description = "Whether the config has already been created outside Compose.";
    };

    template_driver = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Template driver used to render configuration data.";
    };

    labels = mkOption {
      type = customTypes.labelsType;
      default = { };
      description = "Metadata labels for the config.";
    };

    # -------------------------------------------------------------
    # EXTENSIONS & ESCAPE HATCH (Compose Spec 11-extension.md)
    # -------------------------------------------------------------

    extensions = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Extension fields (x-*) for this config.";
    };

    extraYaml = mkOption {
      type = types.attrs;
      default = { };
      description = "Raw attributes merged directly into this config definition.";
    };
  };
}
