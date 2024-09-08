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

git rev-parse HEAD | tr -d '\n'
