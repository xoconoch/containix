{ lib, pkgs }:
let
  inherit (lib) mkOption types;
  customTypes = import ./types.nix { inherit lib; };
in
{
  options = {
    # -------------------------------------------------------------
    # 1. CORE CONTAINER METADATA & EXECUTION
    # -------------------------------------------------------------
    image = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Container image name or local reference.";
    };
    container_name = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Custom container name.";
    };
    command = mkOption {
      type = types.nullOr customTypes.stringOrList;
      default = null;
      description = "Override the default container command.";
    };
    entrypoint = mkOption {
      type = types.nullOr customTypes.stringOrList;
      default = null;
      description = "Override the default container entrypoint.";
    };
    working_dir = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Working directory inside the container.";
    };
    user = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "User (and optional group) to run container processes.";
    };
    platform = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "linux/amd64";
      description = "Target platform/architecture.";
    };
    restart = mkOption {
      type = types.nullOr (
        types.enum [
          "no"
          "always"
          "on-failure"
          "unless-stopped"
        ]
      );
      default = null;
      description = "Container restart policy.";
    };
    scale = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Default number of container instances.";
    };
    pull_policy = mkOption {
      type = types.nullOr (
        types.enum [
          "always"
          "never"
          "missing"
          "build"
          "if_not_present"
        ]
      );
      default = null;
      description = "Image pull policy.";
    };
    runtime = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "OCI runtime to use (e.g., nvidia, runc).";
    };
    init = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Run an init inside the container that forwards signals and reaps processes.";
    };
    attach = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "When false, Compose does not attach logs by default.";
    };
    provider = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Infrastructure provider.";
    };

    # -------------------------------------------------------------
    # 2. ENVIRONMENT, SECRETS & CONFIGURATIONS
    # -------------------------------------------------------------
    environment = mkOption {
      type = types.attrsOf (types.nullOr (types.either types.str (types.either types.int types.bool)));
      default = { };
      description = "Environment variables passed into the container.";
    };
    env_file = mkOption {
      type = types.listOf (
        types.either types.str (
          types.submodule {
            options = {
              path = mkOption { type = types.str; };
              format = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              required = mkOption {
                type = types.nullOr types.bool;
                default = null;
              };
            };
          }
        )
      );
      default = [ ];
      description = "Environment files to load into the container.";
    };
    configs = mkOption {
      type = types.listOf (
        types.either types.str (
          types.submodule {
            options = {
              source = mkOption { type = types.str; };
              target = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              uid = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              gid = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              mode = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
            };
          }
        )
      );
      default = [ ];
      description = "Granted configs access.";
    };
    secrets = mkOption {
      type = types.listOf (
        types.either types.str (
          types.submodule {
            options = {
              source = mkOption { type = types.str; };
              target = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              uid = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              gid = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              mode = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
            };
          }
        )
      );
      default = [ ];
      description = "Granted secrets access.";
    };
    labels = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Metadata labels attached to the container.";
    };
    label_file = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Files containing metadata labels.";
    };
    annotations = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "OCI annotations for the container.";
    };

    # -------------------------------------------------------------
    # 3. STORAGE, MOUNTS & FILESYSTEM
    # -------------------------------------------------------------
    volumes = mkOption {
      type = types.listOf customTypes.volumeType;
      default = [ ];
      description = "Mounted host directories, named volumes, or tmpfs mounts.";
    };
    tmpfs = mkOption {
      type = types.either (types.listOf types.str) (types.attrsOf types.attrs);
      default = [ ];
      description = "Mount temporary file systems in the container.";
    };
    volumes_from = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Mount volumes from another container/service.";
    };
    read_only = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Mount the container root filesystem as read-only.";
    };
    shm_size = mkOption {
      type = types.nullOr (types.either types.str types.int);
      default = null;
      description = "Size of /dev/shm partition.";
    };
    storage_opt = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Storage driver options for this container.";
    };

    # -------------------------------------------------------------
    # 4. NETWORKING, PORTS & DNS
    # -------------------------------------------------------------
    ports = mkOption {
      type = types.listOf customTypes.portType;
      default = [ ];
      description = "Exposed and published network ports.";
    };
    expose = mkOption {
      type = types.listOf (types.either types.str types.int);
      default = [ ];
      description = "Expose internal ports to linked services.";
    };
    networks = mkOption {
      type = types.either (types.listOf types.str) (
        types.attrsOf (
          types.submodule {
            options = {
              aliases = mkOption {
                type = types.listOf types.str;
                default = [ ];
              };
              ipv4_address = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              ipv6_address = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              link_local_ips = mkOption {
                type = types.listOf types.str;
                default = [ ];
              };
              priority = mkOption {
                type = types.nullOr types.int;
                default = null;
              };
            };
          }
        )
      );
      default = [ ];
      description = "Networks to join.";
    };
    network_mode = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "host";
      description = "Network mode (bridge, host, none, container:<name>, service:<name>).";
    };
    hostname = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Container hostname.";
    };
    domainname = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Container domain name.";
    };
    dns = mkOption {
      type = types.either (types.listOf types.str) (types.nullOr types.str);
      default = [ ];
      description = "Custom DNS servers.";
    };
    dns_opt = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Custom DNS options.";
    };
    dns_search = mkOption {
      type = types.either (types.listOf types.str) (types.nullOr types.str);
      default = [ ];
      description = "Custom DNS search domains.";
    };
    extra_hosts = mkOption {
      type = types.either (types.listOf types.str) (types.attrsOf types.str);
      default = [ ];
      description = "Add host-to-IP entries to /etc/hosts.";
    };
    mac_address = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Container MAC address.";
    };
    links = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Legacy links to other services.";
    };
    external_links = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Links to containers outside this Compose file.";
    };

    # -------------------------------------------------------------
    # 5. DEPENDENCIES, LIFECYCLE & HOOKS
    # -------------------------------------------------------------
    depends_on = mkOption {
      type = customTypes.dependsOnType;
      default = [ ];
      description = "Express service startup and health dependency order.";
    };
    healthcheck = mkOption {
      type = types.nullOr customTypes.healthcheckType;
      default = null;
      description = "Container health check configuration.";
    };
    stop_signal = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "SIGTERM";
      description = "Signal used to stop the container.";
    };
    stop_grace_period = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "30s";
      description = "Grace period before killing the container.";
    };
    pre_start = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = "Hooks executed before service starts (v2.30+).";
    };
    post_start = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = "Hooks executed after service starts (v2.30+).";
    };
    pre_stop = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = "Hooks executed before service stops (v2.30+).";
    };

    # -------------------------------------------------------------
    # 6. SECURITY & CAPABILITIES
    # -------------------------------------------------------------
    privileged = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Run container in privileged mode.";
    };
    cap_add = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "NET_ADMIN"
        "SYS_TIME"
      ];
      description = "Add Linux capabilities.";
    };
    cap_drop = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "ALL" ];
      description = "Drop Linux capabilities.";
    };
    security_opt = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "no-new-privileges:true"
        "seccomp=unconfined"
      ];
      description = "Override default security / labeling options.";
    };
    credential_spec = mkOption {
      type = types.nullOr (types.attrsOf types.str);
      default = null;
      description = "Credential spec for managed service account (gMSA).";
    };
    isolation = mkOption {
      type = types.nullOr (
        types.enum [
          "default"
          "process"
          "hyperv"
        ]
      );
      default = null;
      description = "Container isolation technology.";
    };
    userns_mode = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "User namespace mode.";
    };
    group_add = mkOption {
      type = types.listOf (types.either types.str types.int);
      default = [ ];
      description = "Additional group IDs inside the container.";
    };

    # -------------------------------------------------------------
    # 7. RESOURCE LIMITS & HARDWARE
    # -------------------------------------------------------------
    cpus = mkOption {
      type = types.nullOr (types.either types.str types.float);
      default = null;
      description = "Number of CPUs limit.";
    };
    cpu_count = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Usable CPU count.";
    };
    cpu_percent = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Usable CPU percentage.";
    };
    cpu_shares = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "CPU shares relative weight.";
    };
    cpu_period = mkOption {
      type = types.nullOr (types.either types.str types.int);
      default = null;
      description = "CFS CPU scheduler period.";
    };
    cpu_quota = mkOption {
      type = types.nullOr (types.either types.str types.int);
      default = null;
      description = "CFS CPU scheduler quota.";
    };
    cpu_rt_runtime = mkOption {
      type = types.nullOr (types.either types.str types.int);
      default = null;
      description = "Real-time CPU scheduler runtime.";
    };
    cpu_rt_period = mkOption {
      type = types.nullOr (types.either types.str types.int);
      default = null;
      description = "Real-time CPU scheduler period.";
    };
    cpuset = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "0,1";
      description = "CPUs in which to allow execution.";
    };
    mem_limit = mkOption {
      type = types.nullOr (types.either types.str types.int);
      default = null;
      example = "512m";
      description = "Memory limit.";
    };
    mem_reservation = mkOption {
      type = types.nullOr (types.either types.str types.int);
      default = null;
      description = "Memory soft limit.";
    };
    memswap_limit = mkOption {
      type = types.nullOr (types.either types.str types.int);
      default = null;
      description = "Memory plus swap limit.";
    };
    mem_swappiness = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Container memory swappiness (0-100).";
    };
    pids_limit = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Tune container PIDs limit.";
    };
    oom_kill_disable = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Disable OOM Killer for this container.";
    };
    oom_score_adj = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Tune host OOM preferences (-1000 to 1000).";
    };
    devices = mkOption {
      type = types.listOf (types.either types.str (types.attrsOf types.str));
      default = [ ];
      example = [ "/dev/ttyUSB0:/dev/ttyUSB0" ];
      description = "Host device mappings.";
    };
    device_cgroup_rules = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "c 1:3 rmw" ];
      description = "Device cgroup rules.";
    };
    gpus = mkOption {
      type = types.nullOr (types.either types.str (types.attrsOf types.unspecified));
      default = null;
      description = "GPU devices reservation.";
    };
    blkio_config = mkOption {
      type = types.nullOr types.attrs;
      default = null;
      description = "Block IO limits (weights, bps, iops).";
    };
    ulimits = mkOption {
      type = types.attrsOf (
        types.either types.int (
          types.submodule {
            options = {
              soft = mkOption { type = types.int; };
              hard = mkOption { type = types.int; };
            };
          }
        )
      );
      default = { };
      description = "Override container ulimits.";
    };

    # -------------------------------------------------------------
    # 8. NAMESPACES, KERNEL & LOGGING
    # -------------------------------------------------------------
    pid = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "host";
      description = "PID namespace mode.";
    };
    ipc = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "host";
      description = "IPC namespace mode.";
    };
    uts = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "host";
      description = "UTS namespace mode.";
    };
    cgroup = mkOption {
      type = types.nullOr (
        types.enum [
          "host"
          "private"
        ]
      );
      default = null;
      description = "Cgroup namespace configuration.";
    };
    cgroup_parent = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Parent cgroup for the container.";
    };
    sysctls = mkOption {
      type = types.attrsOf (types.either types.str types.int);
      default = { };
      description = "Kernel parameters to set in the container.";
    };
    tty = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Allocate a pseudo-TTY.";
    };
    stdin_open = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Keep STDIN open even if not attached.";
    };
    logging = mkOption {
      type = types.nullOr (
        types.submodule {
          options = {
            driver = mkOption {
              type = types.str;
              default = "json-file";
            };
            options = mkOption {
              type = types.attrsOf types.str;
              default = { };
            };
          };
        }
      );
      default = null;
      description = "Container logging configuration.";
    };

    # -------------------------------------------------------------
    # 9. DEPLOYMENT, BUILD, EXTENSIONS & AI
    # -------------------------------------------------------------
    deploy = mkOption {
      type = types.nullOr types.attrs;
      default = null;
      description = "Orchestration constraints, replicas, and resources.";
    };
    build = mkOption {
      type = types.nullOr (types.either types.str (types.attrsOf types.unspecified));
      default = null;
      description = "Image build configuration from Dockerfile.";
    };
    develop = mkOption {
      type = types.nullOr types.attrs;
      default = null;
      description = "Compose watch configuration.";
    };
    profiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Compose profiles this service belongs to.";
    };
    extends = mkOption {
      type = types.nullOr (types.either types.str types.attrs);
      default = null;
      description = "Extend another service.";
    };
    models = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = "AI/ML model bindings.";
    };

    # -------------------------------------------------------------
    # 10. RAW ESCAPE HATCH
    # -------------------------------------------------------------
    extraYaml = mkOption {
      type = types.attrs;
      default = { };
      description = "Raw attributes merged directly into this service definition.";
    };
  };
}
