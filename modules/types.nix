{ lib }:
let
  inherit (lib) types mkOption;
in rec {
  # Value that can be passed as a single string or a list of strings (e.g. entrypoint, command)
  stringOrList = types.either types.str (types.listOf types.str);

  # Port specification: can be integer, string "8080:80", or long-form object
  portType = types.either types.str (types.either types.int (types.submodule {
    options = {
      target = mkOption { type = types.int; description = "Port inside container"; };
      published = mkOption { type = types.nullOr (types.either types.int types.str); default = null; description = "Host port"; };
      protocol = mkOption { type = types.enum [ "tcp" "udp" ]; default = "tcp"; };
      mode = mkOption { type = types.enum [ "host" "ingress" ]; default = "ingress"; };
      host_ip = mkOption { type = types.nullOr types.str; default = null; };
    };
  }));

  # Volume mount specification: short syntax (string) or long syntax (object)
  volumeType = types.either types.str (types.submodule {
    options = {
      type = mkOption { type = types.enum [ "volume" "bind" "tmpfs" "npipe" "cluster" ]; };
      source = mkOption { type = types.str; };
      target = mkOption { type = types.str; };
      read_only = mkOption { type = types.nullOr types.bool; default = null; };
      bind = mkOption { type = types.nullOr types.attrs; default = null; };
      volume = mkOption { type = types.nullOr types.attrs; default = null; };
      tmpfs = mkOption { type = types.nullOr types.attrs; default = null; };
    };
  });

  # Healthcheck definition
  healthcheckType = types.submodule {
    options = {
      test = mkOption { type = stringOrList; description = "Healthcheck test command"; };
      interval = mkOption { type = types.nullOr types.str; default = null; example = "30s"; };
      timeout = mkOption { type = types.nullOr types.str; default = null; example = "10s"; };
      retries = mkOption { type = types.nullOr types.int; default = null; example = 3; };
      start_period = mkOption { type = types.nullOr types.str; default = null; example = "5s"; };
      start_interval = mkOption { type = types.nullOr types.str; default = null; example = "1s"; };
      disable = mkOption { type = types.bool; default = false; };
    };
  };

  # Depends_on definition: list of strings or map of dependency conditions
  dependsOnType = types.either (types.listOf types.str) (types.attrsOf (types.submodule {
    options = {
      condition = mkOption {
        type = types.enum [ "service_started" "service_healthy" "service_completed_successfully" ];
        default = "service_started";
      };
      restart = mkOption { type = types.nullOr types.bool; default = null; };
      required = mkOption { type = types.bool; default = true; };
    };
  }));
}
