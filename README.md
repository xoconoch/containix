# containix

Declarative Docker and Podman Compose projects managed natively by systemd on NixOS.

`containix` lets you define Compose stacks directly in your NixOS configuration with strongly typed options matching the Compose specification, then serializes them to JSON/YAML derivations and wraps them in robust systemd units.

---

## Features

- **Native systemd Integration**: Every stack runs as a dedicated systemd service (`containix-<project-name>.service`) with automatic startup, dependency ordering, restart policies, and clean shutdown handling.
- **Docker & Podman Backends**: Switch between `docker` and `podman` per project via a single option (`backend = "docker"` or `"podman"`). Automatically configures daemon and socket requirements.
- **Compose Spec Compatibility**: Supports standard Compose fields including services, volumes, networks, secrets, configs, health checks, resource limits, capabilities, GPU access, and dependencies (`depends_on`).
- **Nix Derivation Generation**: Evaluates Compose definitions into immutable JSON/YAML derivations stored in the Nix store (`p.out.composeYaml`).
- **Flexible Escape Hatch**: Inject raw top-level or service-level YAML using `extraYaml`.

---

## Installation

Add `containix` to your flake inputs and include the NixOS module:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    containix.url = "github:<owner>/containix"; # or path:./path-to-containix
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

## Usage Example

```nix
{ config, pkgs, ... }:

{
  virtualisation.containix.webstack = {
    enable = true;
    backend = "docker"; # "docker" or "podman"
    autoPull = false;
    removeOrphans = true;

    services = {
      app = {
        image = "node:20-alpine";
        restart = "unless-stopped";
        working_dir = "/app";
        command = [ "npm" "start" ];
        ports = [ "3000:3000" ];
        environment = {
          NODE_ENV = "production";
          DATABASE_URL = "postgres://postgres:secret@db:5432/mydb";
        };
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
        environment = {
          POSTGRES_PASSWORD = "secret";
          POSTGRES_DB = "mydb";
        };
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

    networks.internal = {};

    volumes.db_data = {};
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
| `projectName` | `str` | `<name>` | Docker Compose project name (`COMPOSE_PROJECT_NAME`). |
| `composeVersion` | `str` | `"3.8"` | Schema version specified in generated compose file. |
| `autoPull` | `bool` | `false` | Pull container images in `ExecStartPre` before startup. |
| `removeOrphans` | `bool` | `true` | Pass `--remove-orphans` on compose up/down/reload. |
| `services` | `attrsOf submodule` | `{}` | Service definitions. |
| `networks` | `attrsOf attrs` | `{}` | Top-level networks. |
| `volumes` | `attrsOf attrs` | `{}` | Top-level volumes. |
| `secrets` | `attrsOf attrs` | `{}` | Top-level secrets. |
| `configs` | `attrsOf attrs` | `{}` | Top-level configs. |
| `extraYaml` | `attrs` | `{}` | Arbitrary attributes merged into the top-level Compose structure. |
| `out.composeYaml` | `package` (read-only) | - | Generated derivation containing the composed YAML/JSON file. |

### Service Options (`virtualisation.containix.<name>.services.<service>`)

Common service properties supported include:

- **Metadata & Lifecycle**: `image`, `container_name`, `command`, `entrypoint`, `working_dir`, `user`, `platform`, `restart`, `pull_policy`, `scale`
- **Networking**: `ports`, `expose`, `networks`, `network_mode`, `hostname`, `domainname`, `dns`, `extra_hosts`
- **Storage**: `volumes`, `tmpfs`, `volumes_from`, `read_only`, `shm_size`
- **Environment & Secrets**: `environment`, `env_file`, `secrets`, `configs`, `labels`
- **Health & Ordering**: `healthcheck`, `depends_on`, `stop_signal`, `stop_grace_period`
- **Resources & Security**: `cpus`, `mem_limit`, `privileged`, `cap_add`, `cap_drop`, `security_opt`, `gpus`, `devices`, `sysctls`
- **Custom / Raw Options**: `extraYaml` (merged directly into the service definition)

---

## Systemd Service Details

Each configured stack creates a systemd service named `containix-<name>.service`:

- **Working Directory**: `/var/lib/containix/<name>` (managed via `StateDirectory`)
- **Lifecycle Commands**:
  - `ExecStartPre`: (Optional) pre-pull images if `autoPull = true`.
  - `ExecStart`: Runs `${composeBin} -f <derivation> up [--remove-orphans] --no-color`.
  - `ExecStop`: Runs `${composeBin} -f <derivation> down [--remove-orphans] --timeout 30`.
  - `ExecReload`: Runs `${composeBin} -f <derivation> up -d [--remove-orphans]`.
- **Systemd Commands**:
  - View status: `systemctl status containix-<name>`
  - View logs: `journalctl -u containix-<name> -f`
  - Restart stack: `systemctl restart containix-<name>`
  - Reload changes: `systemctl reload containix-<name>`
