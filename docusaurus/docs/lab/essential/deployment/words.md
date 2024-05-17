---
sidebar_position: 5
title: Passwords
---

:::danger Incomplete

All of the documents in GODS documentation are currently being rewritten.

:::

## Overview

## The Steps

Now that you should have a DNS service, and a CA & HTTPS service, you have everything you need to start up a password manager. Create the docker compose yaml for the `vaultwarden_svc` service (`/opt/services/lab_services/services/vaultwarden_svc.yml`):

```
services:
  vaultwarden_svc:
    image: vaultwarden/server:latest
    depends_on: [dnsmasq_svc, caddy_svc]
    container_name: vaultwarden_svc
    restart: unless-stopped
    environment:
      DOMAIN: "https://words.lab"
    ports: [127.0.0.1:1080:80, 127.0.0.1:3012:3012]
    volumes:
      - /opt/state/vaultwarden_svc/data:/data
```

Vaultwarden is the first of our services that will require a reverse proxy (Caddy) for access. It is also the first of our services that are not running in `network_mode: host` (i.e. it has its own network namespace). Even so, we explicitly map the vaultwarden container listeners to localhost and use `caddy_svc` as its TLS terminator and reverse proxy. In our docker compose yaml above, we define the host name that we want vaultwarden to identify as and the ports that we want to expose.

To run vaultwarden:

```sh
cd /opt/services/lab_services/services/
docker compose -f vaultwarden_svc.yml up -d
```

## Initial Account and Login

Note: If you are accessing the host via SSH on a LAN, you can access your vaultwarden service from an end-user OS like Linux Desktop or Mac OS by modifying the `/etc/hosts` file. For windows, the `/etc/hosts` file is at `C:\\windows\\system32\\drivers\\etc\\hosts`. You need to run your text editor as Administrator to update and you'll have to reset Chrome and other browsers for the changes to take effect.

Open [https://words.lab](https://words.lab) in browser and "Create Account"

After you've filled in the email (`user@lab`), name (`user`), and password (`gofishpassword`), create account then login with new account.

You can now store all of your sensitive credentials in this password manager. Vaultwarden also supports secure note storage and attachments. This can be useful for private keys or other tokens that aren't strictly a password (e.g. Storage Bucket credentials).

## What Not To Keep Soley In Vaultwarden

Its fantastic to have Vaultwarden as a centralized location for credential and password management, but there are some credentials you should have an alternate means of storing:

- The Vaultwarden master password should be kept in a secondary safe location for when you go senile or need to provide access to your credentials to someone else (i.e. when you die).

- The credentials used to access your vaultwarden backups. If you only keep these in your password manager and the password manager data is lost, you'll have no way to restore those precious backups (especially if your cloud backup service encrypts the data so not even their SAs can unlock the content).

## Backup

Due to the importance of credentials, especially credentials that you don't use every day, we want to take extra care that they are backed up for disaster recovery purposes. My typical approach to this is to take daily backups for each day of the week and then a copy of one of the daily backups monthly and yearly for posterity.

The following is a *partial* script to assist with performing the backup. To complete the script, determine to best way to copy your files offsite. (I personally prefer using an S3 Client to a storage service in the cloud.)

`daily-backup.sh`:

```
#!/bin/sh
TARGET_PATH=/vault
DAILY_FNAME=daily-$(date +%w)
DAILY_PATH=/backups/${DAILY_FNAME}

# Wipe the old backup.
rm -rf ${DAILY_PATH}

# Create an rsync copy of data folder. (i.e. 80% solution)
mkdir -p ${DAILY_PATH}
rsync -a ${TARGET_PATH}/ ${DAILY_PATH}/

# Copied the crudely copied database.
mv ${DAILY_PATH}/db.sqlite3 ${DAILY_PATH}/db.sqlite3.crude

# Create a graceful database backup.
sqlite3 ${TARGET_PATH}/db.sqlite3 ".backup '${DAILY_PATH}/db.sqlite3'"

# Log some integrity digests
find ${DAILY_PATH} -type f -exec sha1sum {} \; > ${DAILY_PATH}.sha1sums
mv ${DAILY_PATH}.sha1sums ${DAILY_PATH}/

# Tarball the backup
tar -zcf ${DAILY_PATH}.tar.gz ${DAILY_PATH}

# Backup to offsite
# !!!!!! TODO: Copy ${DAILY_PATH}.tar.gz to an offsite location here. !!!!!!!
```

`monthly-backup.sh`:

```
#!/bin/sh
SRC_FPATH=/backups/daily-$(( ((7 + $(date +%w)) - 1) % 7 )).tar.gz
DST_FNAME=yearly-$(date +%m).tar.gz
# !!!! TODO: Copy ${SRC_FPATH} as ${DST_FNAME} to an offsite location. !!!!
```

`yearly-backup.sh`:

```
#!/bin/sh
SRC_FPATH=/backups/daily-$(( ((7 + $(date +%w)) - 1) % 7 )).tar.gz
DST_FNAME=yearly-$(date +%Y).tar.gz
# !!!! TODO: Copy ${SRC_FPATH} as ${DST_FNAME} to an offsite location. !!!!
```

Once you have the backup scripts up and running, you can automate them with cron or anacron.

<details>
<summary>Installing Anacron</summary>

- Install anacron (or cronie) with package manager.

- Setup some anacron environment pre-reqs:

   ```sh
   mkdir /var/spool/anacron
   mkdir -p /etc/periodic/{15min,hourly,daily,weekly,monthly}
   ln -s /usr/sbin/anacron /etc/periodic/hourly/anacron
   ```

- Create `/etc/crontab` file.

   ```
   # do daily/weekly/monthly maintenance
   # min   hour    day     month   weekday command
   */15    *       *       *       *       run-parts /etc/periodic/15min
   0       *       *       *       *       run-parts /etc/periodic/hourly
   # daily, weekly, and monthly jobs run from anacron (/etc/anacrontab)
   ```

- Create `/etc/anacrontab` file:

   ```anacrontab
   1 0 cron.daily run-parts /etc/periodic/daily
   7 0 cron.weekly run-parts /etc/periodic/weekly
   30 0 cron.monthly run-parts /etc/periodic/monthly
   ```

</details>

<details>
<summary>Configure Our Backup Script With Anacron</summary>

```
ln -s /backups/daily-backup.sh /etc/periodic/daily/daily-backup.sh
ln -s /backups/monthly-backup.sh /etc/periodic/monthly/monthly-backup.sh
ln -s /backups/yearly-backup.sh /etc/periodic/monthly/yearly-backup.sh
```

</details>

<details>
<summary>Crontab (No anacron required)</summary>

```crontab
# At 04:05
# Daily performed twice incase we're updating or something.
5 4,20 * * * /backups/daily-backup.sh
# At 05:05 on day-of-month 7
# Monthly performed twice incase we're updating or something.
5 5 7,22 * * /backups/monthly-backup.sh
# At 05:05 on day-of-month 7 in Jan, May, Sep
# Yearly performed three times incase we're updating or something.
5 5 7 1,5,9 *4 /backups/yearly-backup.sh
```

</details>


