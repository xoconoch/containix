{ lib, pkgs }:
let
  inherit (lib) mkOption types;
  customTypes = import ./types.nix { inherit lib; };
in
{
  freeformType = types.attrsOf types.anything;

  options = {
    # -------------------------------------------------------------
    # COMPOSE SPEC 09-SECRETS.MD
    # -------------------------------------------------------------

    name = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The name of the secret object in the container engine to look up.";
    };

    file = mkOption {
      type = types.nullOr (types.either types.path types.str);
      default = null;
      description = "Path to file containing secret data.";
    };

    environment = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Name of the environment variable providing secret data (Compose v2.6.0+).";
    };

    external = mkOption {
      type = types.nullOr customTypes.externalType;
      default = null;
      description = "Whether the secret has already been created outside Compose.";
    };

    template_driver = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Template driver used to render secret data.";
    };

    labels = mkOption {
      type = customTypes.labelsType;
      default = { };
      description = "Metadata labels for the secret.";
    };

    # -------------------------------------------------------------
    # EXTENSIONS & ESCAPE HATCH (Compose Spec 11-extension.md)
    # -------------------------------------------------------------

    extensions = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Extension fields (x-*) for this secret.";
    };

    extraYaml = mkOption {
      type = types.attrs;
      default = { };
      description = "Raw attributes merged directly into this secret definition.";
    };
  };
}
