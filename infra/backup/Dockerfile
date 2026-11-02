# The nightly backup image (R19): `pg_dump`, `restic`, `rclone` and `curl` in one arm64 layer.
#
# The two host timers run it as a one-shot container:
#   docker compose -f compose/vps2.yml run --rm -T backup-db      (VPS-2, 03:00 Africa/Cairo)
#   docker compose -f compose/vps1.yml run --rm -T backup-media   (VPS-1, 03:30)
# and, on Sundays, `run --rm -T backup-media-weekly`.
#
# The postgres image already pins a client at the server's major version (16); the Debian packages
# add restic and rclone, the two tools the scripts call, and curl for the Kuma heartbeat. No secret
# is baked in: the repository password and the B2/OCI keys arrive from /srv/madar/.env at run time.
FROM postgres:16.15-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl restic rclone \
    && rm -rf /var/lib/apt/lists/* \
    && restic version \
    && rclone version | head -n 1

# The scripts are mounted read-only from infra/backup at run time, so a change to one is a deploy, not
# an image rebuild. BACKUP_STAGING is the one bind mount the database backup needs; the media backup
# writes nothing locally.
ENV BACKUP_STAGING=/srv/backup
WORKDIR /opt/backup
ENTRYPOINT []
CMD ["/opt/backup/backup-db.sh"]
