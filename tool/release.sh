#!/usr/bin/env bash
# Publica una versión nueva en GitHub Releases para el actualizador in-app.
#
# Uso: tool/release.sh X.Y.Z "Notas de la versión" [--prueba]
#   --prueba  hace todo hasta el APK firmado y el .sha256, sin commit, push ni release
#             (deja pubspec.yaml como estaba).
#
# Requiere: master limpio y al día, android/key.properties, gh con sesión iniciada.
set -euo pipefail

die() { echo "✗ $*" >&2; exit 1; }
step() { echo; echo "▸ $*"; }

[[ $# -ge 2 ]] || die 'Uso: tool/release.sh X.Y.Z "Notas de la versión" [--prueba]'
version=$1
notes=$2
dry_run=false
[[ ${3:-} == --prueba ]] && dry_run=true

[[ $version =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || die "Versión inválida: $version (formato X.Y.Z)"
[[ -n ${notes// } ]] || die 'Las notas no pueden estar vacías.'

cd "$(git rev-parse --show-toplevel)"
repo=Usiless/Wallet
tag="v$version"
package=py.finanzaslocales.finanzas_locales
build_tools=$(ls -d "${ANDROID_HOME:-$HOME/Android/Sdk}"/build-tools/*/ | sort -V | tail -1)

step 'Comprobaciones previas'
[[ -f android/key.properties ]] || die 'Falta android/key.properties.'
# pubspec.yaml se restaura con git checkout al terminar: no puede tener cambios propios.
[[ -z $(git status --porcelain -- pubspec.yaml) ]] || die 'pubspec.yaml tiene cambios sin commit.'
if ! $dry_run; then
  [[ $(git branch --show-current) == master ]] || die 'Hay que estar en master.'
  [[ -z $(git status --porcelain) ]] || die 'Hay cambios sin commit.'
  git fetch --quiet origin
  [[ $(git rev-parse HEAD) == $(git rev-parse origin/master) ]] \
    || die 'master no está igual a origin/master (pull o push pendiente).'
  gh auth status --hostname github.com >/dev/null 2>&1 || die 'gh sin sesión: gh auth login'
  git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1 \
    && die "El tag $tag ya existe en GitHub."
fi

current=$(sed -n 's/^version: *//p' pubspec.yaml)
current_name=${current%%+*}
current_build=${current##*+}
[[ $current_build =~ ^[0-9]+$ ]] || die "No se pudo leer el build de pubspec.yaml: $current"
newest=$(printf '%s\n%s\n' "$current_name" "$version" | sort -V | tail -1)
[[ $version != "$current_name" && $newest == "$version" ]] \
  || die "$version tiene que ser mayor que la actual ($current_name)."
build=$((current_build + 1))
echo "  $current → $version+$build"

step 'flutter analyze'
flutter analyze --no-fatal-infos

step 'flutter test'
flutter test

restore_pubspec() { git checkout --quiet -- pubspec.yaml; }
trap restore_pubspec EXIT
sed -i "s/^version: .*/version: $version+$build/" pubspec.yaml

step 'flutter build apk --release'
flutter build apk --release

step 'Verificación del APK'
built=build/app/outputs/flutter-apk/app-release.apk
badging=$("$build_tools/aapt2" dump badging "$built" | sed -n 1p)
[[ $badging == *"name='$package'"* && $badging == *"versionCode='$build'"* \
  && $badging == *"versionName='$version'"* ]] || die "El APK no tiene la versión esperada: $badging"
certs=$("$build_tools/apksigner" verify --print-certs "$built" 2>/dev/null) || die 'Firma inválida.'
[[ $certs != *'Android Debug'* ]] || die 'El APK está firmado con la clave de debug.'
echo "$certs" | grep -E 'DN|SHA-256'

dist=build/releases
mkdir -p "$dist"
apk="cabal-$version.apk"
cp "$built" "$dist/$apk"
(cd "$dist" && sha256sum "$apk" > "$apk.sha256" && cat "$apk.sha256")

if $dry_run; then
  echo; echo "✓ Prueba completa: $dist/$apk (pubspec.yaml sin cambios)."
  exit 0
fi

step 'Commit y push'
trap - EXIT
git commit --quiet -m "Versión $version+$build" -- pubspec.yaml
git push --quiet origin master

step "Release $tag"
gh release create "$tag" "$dist/$apk" "$dist/$apk.sha256" \
  --repo "$repo" --target "$(git rev-parse HEAD)" --title "$tag" --notes "$notes"

echo; echo "✓ Publicada $tag: https://github.com/$repo/releases/tag/$tag"
