#!/bin/sh
# query the GFZ gitlab server via the command line.
# knb 20180108
# $GITLAB_GFZ_FULL in an env var defined in .bashrc
curl "https://git.gfz-potsdam.de/api/v4/users?active=true&private_token=$GITLAB_GFZ_FULL"  >  ~/data/gitlab_gfz_users_full.json

