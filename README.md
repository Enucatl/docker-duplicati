# docker-backrest

Backrest/restic backup service for the selected Docker and host data paths.

## Service

This Compose project runs Backrest with a fresh restic repository at:

```text
b2:enucatl-backups:restic
```

The image is pinned by digest in `docker-compose.yml`. To upgrade Backrest, resolve the current digest for the desired tag and update the image reference explicitly:

```sh
docker buildx imagetools inspect ghcr.io/garethgeorge/backrest:latest
```

Backrest is exposed through Traefik and Authelia at:

```text
backrest.${DOCKER_DOMAIN}
```

No host port is published directly.

## Backup Scope

The configured Backrest plan is `docker`. It backs up only these mounted source paths:

```text
/source/var/lib/docker/100000.100000/volumes/paperless-ai_export/_data
/source/var/lib/docker/100000.100000/volumes/infra_certificates/_data/keys.json
/source/scratch/backup/vault
/source/export/Documents
```

The plan runs weekly on Monday using local time, keeps the last snapshot, and skips backups when the selected sources have not changed.

## Secrets

Compose secrets are loaded from the untracked `secrets/` directory:

```text
secrets/backrest_b2_account_id
secrets/backrest_b2_account_key
secrets/backrest_repo_password
```

`backrest_repo_password` is the restic repository password. Restic uses it to unlock the repository encryption keys, and it is required to verify or restore backups. Store it somewhere durable outside this repository.

## Bootstrap Config

Backrest state is stored in named volumes:

```text
data
configuration
cache
tmp
```

On container start, `backrest/render-config.sh` renders `/config/config.json` from `backrest/config.template.json` and the Compose secrets. The generated config lives in the `configuration` volume and is not tracked.

The renderer records a checksum next to the generated config and only rewrites `/config/config.json` when the rendered template or secrets change. Normal restarts do not rewrite Backrest's mutable config, but template and secret changes are applied on the next container start.

Treat `backrest/config.template.json` as the source of truth for repository and plan settings. Backrest UI edits can be overwritten when the template or secrets change.

## Security Boundary

The service keeps the shared `docker-compose-security-baseline` limits, `no-new-privileges`, resource limits, PID limits, and read-only source mounts.

`userns_mode: host` is intentional because Backrest must read userns-remapped Docker volume data under `/var/lib/docker/100000.100000`.

The Backrest service runs as the dedicated FreeIPA UID/GID `175200010`, which has read access to `/export/Documents` over Kerberized NFS. A one-shot `backrest-init` service owns the named state volumes for that UID before Backrest starts.

The service does not use privileged mode, does not mount the Docker socket, and does not mount host root.

## Operations

Validate the Compose model:

```sh
docker compose config
```

Start Backrest:

```sh
docker compose up -d
```

After first start:

1. Confirm `backrest.${DOCKER_DOMAIN}` loads through Authelia.
2. Let Backrest initialize `b2:enucatl-backups:restic`.
3. Run the `docker` plan manually once.
4. Verify a snapshot exists.
5. Restore at least one small file to a temporary path before relying on the migration.

Keep the old Duplicati configuration volume and remote backup data until one manual and one scheduled Backrest run have both been restore-tested.
