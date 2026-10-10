{ lib, pkgs }:
let
  inherit (lib) mkOption types;
in
{
  freeformType = types.attrsOf types.anything;

  options = {
    # -------------------------------------------------------------
    # COMPOSE SPEC MODELS.MD (Compose v2.38.0+)
    # -------------------------------------------------------------

    model = mkOption {
      type = types.str;
      description = "OCI artifact identifier for model to be pulled and run by model runner (e.g. 'ai/model').";
    };

    context_size = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Context size for the model in tokens.";
    };

    runtime_flags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Raw runtime flags to pass to the inference engine.";
    };

    # -------------------------------------------------------------
    # EXTENSIONS & ESCAPE HATCH (Compose Spec 11-extension.md)
    # -------------------------------------------------------------

    extensions = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Extension fields (x-*) for this model.";
    };

    extraYaml = mkOption {
      type = types.attrs;
      default = { };
      description = "Raw attributes merged directly into this model definition.";
    };
  };
}
