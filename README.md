# containix

Declarative Docker and Podman Compose projects managed natively by systemd on NixOS.

`containix` lets you define Compose stacks directly in your NixOS configuration with complete, strongly typed options covering the entire **[Compose Specification](https://github.com/compose-spec/compose-spec)**, serializes them to immutable JSON/YAML derivations, and manages their lifecycle via systemd units.

---

## Features

- **Full Compose Spec Coverage**: Natively covers the complete specification:
  - **[04-version-and-name.md](https://github.com/compose-spec/compose-spec/blob/main/04-version-and-name.md)**: Top-level `name` and optional `version`.
  - **[05-services.md](https://github.com/compose-spec/compose-spec/blob/main/05-services.md)**: Container configuration, plus `build.md`, `deploy.md`, `develop.md`, and `models.md`.
  - **[06-networks.md](https://github.com/compose-spec/compose-spec/blob/main/06-networks.md)**: Custom drivers, `driver_opts`, `attachable`, `enable_ipv4`, `enable_ipv6`, `internal`, `external`, and `ipam` subnets/gateways/ranges.
  - **[07-volumes.md](https://github.com/compose-spec/compose-spec/blob/main/07-volumes.md)**: Custom drivers, `driver_opts`, `external`, and `labels`.
  - **[08-configs.md](https://github.com/compose-spec/compose-spec/blob/main/08-configs.md)**: File-based, inlined `content`, environment-based, and `external` configurations.
  - **[09-secrets.md](https://github.com/compose-spec/compose-spec/blob/main/09-secrets.md)**: File-based, environment-based, and `external` secrets.
  - **[10-fragments.md](https://github.com/compose-spec/compose-spec/blob/main/10-fragments.md)**: Seamlessly share and compose configurations using Nix language expressions and attribute sets.
  - **[11-extension.md](https://github.com/compose-spec/compose-spec/blob/main/11-extension.md)**: Full support for extension fields (`x-*`) at the top level and within any resource.
  - **[12-interpolation.md](https://github.com/compose-spec/compose-spec/blob/main/12-interpolation.md)**: Standard `${VAR}`, `${VAR:-default}`, and `$${VAR}` escaping passed through cleanly to the Compose engine.
  - **[13-merge.md](https://github.com/compose-spec/compose-spec/blob/main/13-merge.md)**: Multi-file compose merging via `composeFiles = [ ... ]` using sequential `-f` flags.
  - **[14-include.md](https://github.com/compose-spec/compose-spec/blob/main/14-include.md)**: Import external Compose files using top-level `include` (both short path syntax and long syntax with `project_directory` / `env_file`).
  - **[15-profiles.md](https://github.com/compose-spec/compose-spec/blob/main/15-profiles.md)**: Assign services to profiles and activate target profiles per-project (`profiles = [ "frontend" "metrics" ]`), propagating both via `--profile` CLI flags and `COMPOSE_PROFILES`.
  - **[models.md](https://github.com/compose-spec/compose-spec/blob/main/models.md)**: Declare top-level AI models (`model`, `context_size`, `runtime_flags`) and bind them to services.
- **Native systemd Integration**: Every stack runs as a dedicated systemd service (`containix-<project-name>.service`) with automatic startup, dependency ordering, restart policies, and clean shutdown handling.
- **Docker & Podman Backends**: Switch between `docker` and `podman` per project via a single option (`backend = "docker"` or `"podman"`). Automatically configures daemon and socket requirements.
- **Nix Derivation Generation**: Evaluates Compose definitions into immutable derivations stored in the Nix store (`p.out.composeYaml`).
- **Flexible Escape Hatch**: Inject raw top-level or resource-level YAML/JSON using `extraYaml` or freeform attributes.

---

## Installation

Add `containix` to your flake inputs and include the NixOS module:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    containix.url = "github:xoconoch/containix";
  };

  outputs = { self, nixpkgs, containix, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        containix.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

---

## Comprehensive Example

```nix
{ config, pkgs, ... }:

{
  virtualisation.containix.webstack = {
    enable = true;
    backend = "docker"; # "docker" or "podman"
    name = "webstack-prod"; # Compose Spec 04: top-level project name
    version = "3.8"; # Compose Spec 04: optional format version
    autoPull = false;
    removeOrphans = true;

    # Compose Spec 15: activate specific profiles for this stack
    profiles = [ "core" "ai" ];

    # Compose Spec 13: merge external Compose override files...
    # ...although idk why you'd want to do this, use nix!
    composeFiles = [ "/etc/compose/custom-overrides.yaml" ];

    # Compose Spec 14: include sub-applications...
    # ...did you not read the previous comment?
    include = [
      "../shared/base-compose.yaml"
      {
        path = "../monitoring/compose.yaml";
        project_directory = "../monitoring";
        env_file = "../monitoring/.env";
      }
    ];

    # Compose Spec 11: top-level extension fields (automatically prefixed with x-)
    extensions = {
      project-meta = {
        environment = "production";
        maintainer = "ops@example.com";
      };
    };

    # Compose Spec 05: Services
    services = {
      app = {
        image = "node:20-alpine";
        restart = "unless-stopped";
        working_dir = "/app";
        command = [ "npm" "start" ];
        ports = [ "3000:3000" ];
        profiles = [ "core" ];

        # Environment variables (array or map syntax)
        environment = {
          NODE_ENV = "production";
          DATABASE_URL = "postgres://postgres:secret@db:5432/mydb";
        };

        # Compose Spec 08 & 09: Mount configs and secrets
        configs = [
          {
            source = "app_config";
            target = "/app/config.json";
            mode = "0440";
          }
        ];
        secrets = [ "db_password" ];

        # AI model bindings (models.md)
        models = [ "chat_assistant" ];

        depends_on = {
          db = {
            condition = "service_healthy";
          };
        };
        networks = [ "internal" ];
      };

      db = {
        image = "postgres:16-alpine";
        restart = "unless-stopped";
        profiles = [ "core" ];
        environment = {
          POSTGRES_PASSWORD_FILE = "/run/secrets/db_password";
          POSTGRES_DB = "mydb";
        };
        secrets = [ "db_password" ];
        volumes = [
          "db_data:/var/lib/postgresql/data"
        ];
        healthcheck = {
          test = [ "CMD-SHELL" "pg_isready -U postgres" ];
          interval = "10s";
          timeout = "5s";
          retries = 5;
        };
        networks = [ "internal" ];
      };
    };

    # Compose Spec 06: Networks
    networks = {
      internal = {
        driver = "bridge";
        driver_opts = {
          "com.docker.network.bridge.enable_icc" = "true";
        };
        enable_ipv6 = false;
        ipam = {
          driver = "default";
          config = [
            {
              subnet = "172.28.0.0/16";
              gateway = "172.28.0.1";
            }
          ];
        };
      };
      public = {
        external = true;
      };
    };

    # Compose Spec 07: Volumes
    volumes = {
      db_data = {
        driver = "local";
        labels = {
          "com.example.department" = "Database";
        };
      };
    };

    # Compose Spec 08: Configs
    configs = {
      app_config = {
        content = ''
          {
            "logging": "info",
            "cluster": true
          }
        '';
      };
    };

    # Compose Spec 09: Secrets
    secrets = {
      db_password = {
        file = "/run/secrets/postgres_password";
      };
    };

    # Compose Spec models.md: Top-level AI models
    models = {
      chat_assistant = {
        model = "ollama/llama3";
        context_size = 4096;
        runtime_flags = [ "--gpu" ];
      };
    };
  };
}
```

---

## Configuration Reference

### Project Options (`virtualisation.containix.<name>`)

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | `bool` | `true` | Enable this declarative compose project. |
| `backend` | `enum [ "docker" "podman" ]` | `"docker"` | Container runtime and compose CLI backend. |
| `name` | `nullOr str` | `<projectName>` | Compose top-level project name (`04-version-and-name.md`). |
| `projectName` | `str` | `<name>` | Docker Compose project name (`COMPOSE_PROJECT_NAME`). |
| `version` | `nullOr str` | `null` | Optional Compose specification version (`04-version-and-name.md`). |
| `autoPull` | `bool` | `false` | Pull container images in `ExecStartPre` before startup. |
| `removeOrphans` | `bool` | `true` | Pass `--remove-orphans` on compose up/down/reload. |
| `services` | `attrsOf submodule` | `{}` | Service definitions (`05-services.md`). |
| `networks` | `attrsOf submodule` | `{}` | Top-level networks definitions (`06-networks.md`). |
| `volumes` | `attrsOf submodule` | `{}` | Top-level volumes definitions (`07-volumes.md`). |
| `configs` | `attrsOf submodule` | `{}` | Top-level configs definitions (`08-configs.md`). |
| `secrets` | `attrsOf submodule` | `{}` | Top-level secrets definitions (`09-secrets.md`). |
| `models` | `attrsOf submodule` | `{}` | Top-level AI models definitions (`models.md`). |
| `include` | `listOf (either str submodule)` | `[]` | Include external Compose applications (`14-include.md`). |
| `profiles` | `listOf str` | `[]` | Active Compose profiles for this stack (`15-profiles.md`). |
| `composeFiles` | `listOf (either str path package)` | `[]` | Additional Compose files merged sequentially via `-f` (`13-merge.md`). |
| `extensions` | `attrs` | `{}` | Top-level `x-*` extension fields (`11-extension.md`). |
| `extraYaml` | `attrs` | `{}` | Arbitrary attributes merged into the top-level Compose structure. |
| `out.composeYaml` | `package` (read-only) | - | Generated derivation containing the composed YAML/JSON file. |

### Top-Level Networks Options (`networks.<network>`)

| Option | Type | Default | Description |
|---|---|---|---|
| `name` | `nullOr str` | `null` | Custom network name on the container runtime. |
| `driver` | `nullOr str` | `null` | Network driver (`bridge`, `overlay`, `macvlan`, etc.). |
| `driver_opts` | `attrsOf (str \| int \| float \| bool)` | `{}` | Driver-specific options. |
| `attachable` | `nullOr bool` | `null` | Allow standalone containers to attach. |
| `enable_ipv4` | `nullOr bool` | `null` | Enable or disable IPv4 address assignment. |
| `enable_ipv6` | `nullOr bool` | `null` | Enable IPv6 address assignment. |
| `internal` | `nullOr bool` | `null` | Create an externally isolated network. |
| `external` | `nullOr (either bool submodule)` | `null` | Reference an externally managed network. |
| `ipam` | `nullOr submodule` | `null` | Custom IPAM driver, `config` (`subnet`, `ip_range`, `gateway`, `aux_addresses`), and `options`. |
| `labels` | `listOf str \| attrsOf str` | `{}` | Metadata labels. |
| `extensions` | `attrs` | `{}` | Extension fields (`x-*`). |
| `extraYaml` | `attrs` | `{}` | Raw attributes merged directly into this network. |

### Top-Level Volumes Options (`volumes.<volume>`)

| Option | Type | Default | Description |
|---|---|---|---|
| `name` | `nullOr str` | `null` | Custom volume name on the container runtime. |
| `driver` | `nullOr str` | `null` | Volume driver (e.g. `local`, `flocker`). |
| `driver_opts` | `attrsOf (str \| int \| float \| bool)` | `{}` | Driver-specific options. |
| `external` | `nullOr (either bool submodule)` | `null` | Reference an externally managed volume. |
| `labels` | `listOf str \| attrsOf str` | `{}` | Metadata labels. |
| `extensions` | `attrs` | `{}` | Extension fields (`x-*`). |
| `extraYaml` | `attrs` | `{}` | Raw attributes merged directly into this volume. |

### Top-Level Configs Options (`configs.<config>`)

| Option | Type | Default | Description |
|---|---|---|---|
| `name` | `nullOr str` | `null` | Custom config name in the engine. |
| `file` | `nullOr (path \| str)` | `null` | Source file path. |
| `environment` | `nullOr str` | `null` | Source environment variable. |
| `content` | `nullOr str` | `null` | Inlined configuration content. |
| `external` | `nullOr (either bool submodule)` | `null` | Reference an external config. |
| `template_driver` | `nullOr str` | `null` | Template driver. |
| `labels` | `listOf str \| attrsOf str` | `{}` | Metadata labels. |
| `extensions` | `attrs` | `{}` | Extension fields (`x-*`). |
| `extraYaml` | `attrs` | `{}` | Raw attributes merged directly into this config. |

### Top-Level Secrets Options (`secrets.<secret>`)

| Option | Type | Default | Description |
|---|---|---|---|
| `name` | `nullOr str` | `null` | Custom secret name in the engine. |
| `file` | `nullOr (path \| str)` | `null` | Source file path. |
| `environment` | `nullOr str` | `null` | Source environment variable. |
| `external` | `nullOr (either bool submodule)` | `null` | Reference an external secret. |
| `template_driver` | `nullOr str` | `null` | Template driver. |
| `labels` | `listOf str \| attrsOf str` | `{}` | Metadata labels. |
| `extensions` | `attrs` | `{}` | Extension fields (`x-*`). |
| `extraYaml` | `attrs` | `{}` | Raw attributes merged directly into this secret. |

### Top-Level Models Options (`models.<model>`)

| Option | Type | Default | Description |
|---|---|---|---|
| `model` | `str` | - | OCI artifact identifier for the AI model (required). |
| `context_size` | `nullOr int` | `null` | Context size in tokens. |
| `runtime_flags` | `listOf str` | `[]` | Flags passed to the inference engine. |
| `extensions` | `attrs` | `{}` | Extension fields (`x-*`). |
| `extraYaml` | `attrs` | `{}` | Raw attributes merged directly into this model. |

### Service Options (`services.<service>`)

Common service properties supported include:

- **Metadata & Lifecycle**: `image`, `container_name`, `command`, `entrypoint`, `working_dir`, `user`, `platform`, `restart`, `pull_policy`, `scale`, `profiles`
- **Networking**: `ports`, `expose`, `networks`, `network_mode`, `hostname`, `domainname`, `dns`, `dns_opt`, `dns_search`, `extra_hosts`, `mac_address`, `links`, `external_links`
- **Storage**: `volumes`, `tmpfs`, `volumes_from`, `read_only`, `shm_size`, `storage_opt`
- **Environment & Secrets**: `environment` (array or map), `env_file`, `secrets`, `configs`, `labels` (array or map), `label_file`, `annotations`
- **Health & Ordering**: `healthcheck`, `depends_on`, `stop_signal`, `stop_grace_period`, `pre_start`, `post_start`, `pre_stop`
- **Resources & Security**: `cpus`, `cpu_count`, `cpu_percent`, `cpu_shares`, `cpu_period`, `cpu_quota`, `cpu_rt_runtime`, `cpu_rt_period`, `cpuset`, `mem_limit`, `mem_reservation`, `memswap_limit`, `mem_swappiness`, `pids_limit`, `privileged`, `cap_add`, `cap_drop`, `security_opt`, `credential_spec`, `isolation`, `userns_mode`, `group_add`, `gpus`, `devices`, `device_cgroup_rules`, `blkio_config`, `ulimits`, `sysctls`
- **Deployment & Build**: `deploy` (`deploy.md`), `build` (`build.md`), `develop` (`develop.md`), `extends`
- **AI Models**: `models` (`models.md` list of model names or endpoint mapping)
- **Extensions & Escape Hatch**: `extensions` (`x-*`), `extraYaml`

---

## Systemd Service Details

Each configured stack creates a systemd service named `containix-<name>.service`:

- **Working Directory**: `/var/lib/containix/<name>` (managed via `StateDirectory`)
- **Lifecycle Commands**:
  - `ExecStartPre`: (Optional) pre-pull images if `autoPull = true`.
  - `ExecStart`: Runs `${composeBin} -f <derivation> [-f <composeFiles>] [--profile <profiles>] up [--remove-orphans] --no-color`.
  - `ExecStop`: Runs `${composeBin} -f <derivation> [-f <composeFiles>] [--profile <profiles>] down [--remove-orphans] --timeout 30`.
  - `ExecReload`: Runs `${composeBin} -f <derivation> [-f <composeFiles>] [--profile <profiles>] up -d [--remove-orphans]`.
- **Systemd Commands**:
  - View status: `systemctl status containix-<name>`
  - View logs: `journalctl -u containix-<name> -f`
  - Restart stack: `systemctl restart containix-<name>`
  - Reload changes: `systemctl reload containix-<name>`
