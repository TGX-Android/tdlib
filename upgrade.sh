#!/bin/bash
set -e

USERNAME=$1
PASSWORD=$2
shift 2

# Options of /upgrade_tdlib: --td=<full commit, branch or tag> builds that td instead of master
TD_REF=master
for ARG in "$@"; do
  case $ARG in
    --td=?*) TD_REF=${ARG#--td=} ;;
    *) echo "Unknown option: $ARG" >&2; exit 1 ;;
  esac
done

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
git fetch --depth=1 origin "$TD_REF"
git checkout -q FETCH_HEAD
cd ..
echo "Building..."
./rebuild.sh > rebuild.log 2>&1
git add --all
echo "Build finished."
cd ..
TDLIB_COMMIT=$(cat version.txt | cut -c 1-7)

COMMIT_MSG="Upgrade TDLib to tdlib/td@${TDLIB_COMMIT}"
if ! git diff --cached --quiet -- openssl; then
  COMMIT_MSG="$COMMIT_MSG + Rebuild OpenSSL"
fi
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
