#!/bin/sh

cat <<'MOTD'
     _         _   _  ___ _____                    _   _     _
  __| | ___   | \ | |/ _ \_   _|  _   _ ___  ___  | |_| |__ (_)___
/  _` |/ _ \  |  \| | | | || |   | | | / __|/ _ \ | __| '_ \| / __|
| (_| | (_) | | |\  | |_| || |   | |_| \__ \  __/ | |_| | | | \__ \
 \__,_|\___/  |_| \_|\___/ |_|    \__,_|___/\___|  \__|_| |_|_|___/

                              _
 ___  ___ _ ____   _____ _ __| |
/ __|/ _ \ '__\ \ / / _ \ '__| |
\__ \  __/ |   \ V /  __/ |  |_|
|___/\___|_|    \_/ \___|_|  (_)


While it is perfectly working, stat1005 users are being moved to stat1007
as part of https://phabricator.wikimedia.org/T205846

Your home directory has been copied to stat1007, please ping the Analytics
team in T205846 or on #wikimedia-analytics if anything is missing.

On Nov 14th SSH access to this server will be revoked.

MOTD
