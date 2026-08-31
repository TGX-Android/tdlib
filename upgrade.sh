#!/bin/bash
set -e

USERNAME=$1
PASSWORD=$2

SECONDS=0
pushd tdlib > /dev/null

ORIGINAL_REMOTE=$(git remote get-url origin)
if [[ "$ORIGINAL_REMOTE" =~ ^ssh://git@.* ]]; then
  REMOTE="${ORIGINAL_REMOTE}"
else
  REMOTE="https://${USERNAME}:${PASSWORD}@${ORIGINAL_REMOTE}"
fi

pushd source > /dev/null || exit 1
./clean.sh
popd > /dev/null

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

COMMIT_MSG="Upgrade TDLib to tdlib/td@${TDLIB_COMMIT} + Rebuild OpenSSL" 
if [ "$SECONDS" -ge 60 ]; then
  git commit -m "$COMMIT_MSG" -m "Built in $(expr $SECONDS / 60)m $(expr $SECONDS % 60)s"
elif [ "$SECONDS" -gt 0 ]; then
  git commit -m "$COMMIT_MSG" -m "Built in ${SECONDS}s"
else
  git commit -m "$COMMIT_MSG"
fi

echo "Pushing..."
git push "$REMOTE" > /dev/null 2>&1

popd > /dev/null
