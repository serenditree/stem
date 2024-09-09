set -o errexit

mkdir -pv $(params.subdirectory)
cd $(params.subdirectory)

if [[ -d .git ]] && [[ -n "$(params.clone)" ]]; then
  echo "Cleaning repository..."
  rm -rf .
fi

if [[ ! -d .git ]]; then
  git clone $(params.url) .
fi

git checkout $(params.revision)
git pull --ff-only

git log -1 --pretty="%h by %cn: %s" | tee $(results.log.path)
git log -1 --pretty="%h" | tee $(results.sha.path)
