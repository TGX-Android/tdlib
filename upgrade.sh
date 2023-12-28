#!/bin/bash
set -e

USERNAME=$1
PASSWORD=$2

SECONDS=0
pushd tdlib > /dev/null

REMOTE="https://${USERNAME}:${PASSWORD}@$(git remote get-url origin | cut -c 9-)"

git checkout main > /dev/null
git pull origin main > /dev/null
cd source/td
git checkout master > /dev/null
git pull origin master
cd ..
echo "Building..."
./rebuild.sh > /dev/null 2>&1
git add --all
echo "Build finished."
cd ..
TDLIB_COMMIT=$(cat version.txt | cut -c 1-7)

COMMIT_MSG="Upgraded TDLib to tdlib/td@${TDLIB_COMMIT} + Rebuilt OpenSSL" 
if [ "$SECONDS" -ge 60 ]; then
  git commit -m "$COMMIT_MSG" -m "Built in $(expr $SECONDS / 60)m $(expr $SECONDS % 60)s"
elif [ "$SECONDS" -gt 0 ]; then
  git commit -m "$COMMIT_MSG" -m "Built in ${SECONDS}s"
else
  git commit -m "$COMMIT_MSG"
fi
git push "$REMOTE" > /dev/null 2>&1

popd > /dev/null
