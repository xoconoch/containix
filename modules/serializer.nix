{ lib, pkgs }:
let
  # Recursively filter null values and empty attributes/lists
  cleanAttrs =
    val:
    if lib.isDerivation val then
      val
    else if builtins.isAttrs val then
      let
        filtered = lib.filterAttrs (_: v: v != null) val;
        cleaned = lib.mapAttrs (_: cleanAttrs) filtered;
      in
      lib.filterAttrs (_: v: !(lib.isList v && v == [ ]) && !(lib.isAttrs v && v == { })) cleaned
    else if builtins.isList val then
      builtins.map cleanAttrs val
    else
      val;

  # Helper to normalize extension keys to start with "x-" (Compose Spec 11-extension.md)
  normalizeExtensions =
    ext:
    lib.mapAttrs' (
      k: v:
      let
        prefixed = if lib.hasPrefix "x-" k then k else "x-${k}";
      in
      lib.nameValuePair prefixed (cleanAttrs v)
    ) ext;

  # Extracts all fields defined in service-options and merges extraYaml & extensions
  serializeService =
    s:
    let
      base = builtins.removeAttrs s [
        "_module"
        "extraYaml"
        "extensions"
      ];
      exts = normalizeExtensions (s.extensions or { });
      raw = base // exts // (s.extraYaml or { });
    in
    cleanAttrs raw;

  # Extracts all fields defined in network-options and merges extraYaml & extensions
  serializeNetwork =
    n:
    let
      base = builtins.removeAttrs n [
        "_module"
        "extraYaml"
        "extensions"
      ];
      exts = normalizeExtensions (n.extensions or { });
      raw = base // exts // (n.extraYaml or { });
    in
    cleanAttrs raw;

  # Extracts all fields defined in volume-options and merges extraYaml & extensions
  serializeVolume =
    v:
    let
      base = builtins.removeAttrs v [
        "_module"
        "extraYaml"
        "extensions"
      ];
      exts = normalizeExtensions (v.extensions or { });
      raw = base // exts // (v.extraYaml or { });
    in
    cleanAttrs raw;

  # Extracts all fields defined in config-options and merges extraYaml & extensions
  serializeConfig =
    c:
    let
      fileVal = if c.file != null then toString c.file else null;
      base =
        (builtins.removeAttrs c [
          "_module"
          "extraYaml"
          "extensions"
          "file"
        ])
        // lib.optionalAttrs (fileVal != null) { file = fileVal; };
      exts = normalizeExtensions (c.extensions or { });
      raw = base // exts // (c.extraYaml or { });
    in
    cleanAttrs raw;

  # Extracts all fields defined in secret-options and merges extraYaml & extensions
  serializeSecret =
    s:
    let
      fileVal = if s.file != null then toString s.file else null;
      base =
        (builtins.removeAttrs s [
          "_module"
          "extraYaml"
          "extensions"
          "file"
        ])
        // lib.optionalAttrs (fileVal != null) { file = fileVal; };
      exts = normalizeExtensions (s.extensions or { });
      raw = base // exts // (s.extraYaml or { });
    in
    cleanAttrs raw;

  # Extracts all fields defined in model-options and merges extraYaml & extensions
  serializeModel =
    m:
    let
      base = builtins.removeAttrs m [
        "_module"
        "extraYaml"
        "extensions"
      ];
      exts = normalizeExtensions (m.extensions or { });
      raw = base // exts // (m.extraYaml or { });
    in
    cleanAttrs raw;

  # Extracts include element (string path or submodule object)
  serializeInclude =
    inc: if builtins.isAttrs inc then cleanAttrs (builtins.removeAttrs inc [ "_module" ]) else inc;

  # Builds the complete top-level compose.yaml file derivation
  serializeProject =
    projectConfig:
    let
      cleanServices = lib.filterAttrs (_: v: v != null && v != { }) (
        lib.mapAttrs (_: serializeService) projectConfig.services
      );
      cleanNetworks = lib.mapAttrs (_: serializeNetwork) projectConfig.networks;
      cleanVolumes = lib.mapAttrs (_: serializeVolume) projectConfig.volumes;
      cleanConfigs = lib.mapAttrs (_: serializeConfig) projectConfig.configs;
      cleanSecrets = lib.mapAttrs (_: serializeSecret) projectConfig.secrets;
      cleanModels = lib.mapAttrs (_: serializeModel) projectConfig.models;
      cleanIncludes = builtins.map serializeInclude projectConfig.include;
      topExtensions = normalizeExtensions projectConfig.extensions;
      effectiveName =
        if projectConfig.name != null then projectConfig.name else projectConfig.projectName;

      topLevel = {
        name = effectiveName;
      }
      // lib.optionalAttrs (projectConfig.version != null) { version = projectConfig.version; }
      // lib.optionalAttrs (cleanServices != { }) { services = cleanServices; }
      // lib.optionalAttrs (cleanNetworks != { }) { networks = cleanNetworks; }
      // lib.optionalAttrs (cleanVolumes != { }) { volumes = cleanVolumes; }
      // lib.optionalAttrs (cleanConfigs != { }) { configs = cleanConfigs; }
      // lib.optionalAttrs (cleanSecrets != { }) { secrets = cleanSecrets; }
      // lib.optionalAttrs (cleanModels != { }) { models = cleanModels; }
      // lib.optionalAttrs (cleanIncludes != [ ]) { include = cleanIncludes; }
      // topExtensions
      // projectConfig.extraYaml;
    in
    pkgs.writeText "compose-${projectConfig.projectName}.yaml" (builtins.toJSON topLevel);
in
{
  inherit
    cleanAttrs
    normalizeExtensions
    serializeService
    serializeNetwork
    serializeVolume
    serializeConfig
    serializeSecret
    serializeModel
    serializeInclude
    serializeProject
    ;
}
