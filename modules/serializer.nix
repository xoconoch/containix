{ lib, pkgs }:
let
  # Recursively filter null values and empty attributes/lists
  cleanAttrs = val:
    if lib.isDerivation val then
      val
    else if builtins.isAttrs val then
      let
        filtered = lib.filterAttrs (_: v: v != null) val;
        cleaned = lib.mapAttrs (_: cleanAttrs) filtered;
      in
        lib.filterAttrs (_: v: !(lib.isList v && v == []) && !(lib.isAttrs v && v == {})) cleaned
    else if builtins.isList val then
      builtins.map cleanAttrs val
    else
      val;

  # Extracts all fields defined in service-options and merges extraYaml
  serializeService = s:
    let
      raw = {
        inherit (s)
          image container_name command entrypoint working_dir user platform
          restart scale pull_policy runtime init attach provider
          environment env_file configs secrets labels label_file annotations
          volumes tmpfs volumes_from read_only shm_size storage_opt
          ports expose networks network_mode hostname domainname dns
          dns_opt dns_search extra_hosts mac_address links external_links
          depends_on healthcheck stop_signal stop_grace_period pre_start
          post_start pre_stop privileged cap_add cap_drop security_opt
          credential_spec isolation userns_mode group_add cpus cpu_count
          cpu_percent cpu_shares cpu_period cpu_quota cpu_rt_runtime
          cpu_rt_period cpuset mem_limit mem_reservation memswap_limit
          mem_swappiness pids_limit oom_kill_disable oom_score_adj devices
          device_cgroup_rules gpus blkio_config ulimits pid ipc uts
          cgroup cgroup_parent sysctls tty stdin_open logging deploy
          build develop profiles extends models;
      } // s.extraYaml;
    in cleanAttrs raw;

  # Builds the complete top-level compose.yaml file derivation
  serializeProject = projectConfig:
    let
      cleanServices = lib.filterAttrs (_: v: v != null && v != {}) (lib.mapAttrs (_: serializeService) projectConfig.services);
      topLevel = {
        version = projectConfig.composeVersion;
        services = cleanServices;
      }
      // lib.optionalAttrs (projectConfig.networks != {}) { networks = projectConfig.networks; }
      // lib.optionalAttrs (projectConfig.volumes != {}) { volumes = projectConfig.volumes; }
      // lib.optionalAttrs (projectConfig.secrets != {}) { secrets = projectConfig.secrets; }
      // lib.optionalAttrs (projectConfig.configs != {}) { configs = projectConfig.configs; }
      // projectConfig.extraYaml;
    in
      pkgs.writeText "compose-${projectConfig.projectName}.yaml" (builtins.toJSON topLevel);
in
{
  inherit cleanAttrs serializeService serializeProject;
}
