set -o errexit
date +%s > $(results.start.path)

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

git log -1 --pretty="%h" | tr -d '\n' | tee $(results.sha.path)
