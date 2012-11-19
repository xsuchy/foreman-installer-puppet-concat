#!/bin/bash
set -e 
set -o pipefail
git merge -m "Merge remote-tracking branch 'puppet-concat/master' by rel-eng/build.sh" puppet-concat/master
#just test if we are able to create srpm, and do not proceed if there is big change in code
tito build --test --srpm

HASH=$(git show puppet-concat/master  |grep commit |head -n1 | awk '{print $2}' |cut -c-7)
sed -i "s/%global foreman_hash .*$/%global foreman_hash .$HASH/" foreman-puppet-concat.spec
git add foreman-puppet-concat.spec
git commit -m 'Automatic rebase to latest nightly puppet-concat'
tito tag --accept-auto-changelog
git push && git push --tags
tito release koji
