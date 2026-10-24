#!/usr/bin/env bash
# Creates the tester release key outside the repository and writes the
# gitignored app/production/android/key.properties that points to it.
# Every tester build must use this same key so new APKs install as upgrades.
# Back up the keystore and passwords; losing them forces testers to reinstall.
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
store="${NEXUS_TESTER_KEYSTORE:-$HOME/.nexus-pc/tester-release.jks}"
alias="nexus-tester"
properties="$task_root/app/production/android/key.properties"
if [[ -e "$store" || -e "$properties" ]]; then
  echo "Refusing to overwrite existing $store or $properties." >&2
  exit 1
fi
command -v keytool >/dev/null || { echo "keytool (JDK 17) is required." >&2; exit 1; }
read -r -s -p "New keystore password (at least 6 characters): " password; echo
read -r -s -p "Repeat password: " repeat; echo
[[ "$password" == "$repeat" && ${#password} -ge 6 ]] || { echo "Passwords differ or are too short." >&2; exit 1; }
mkdir -p "$(dirname "$store")"
umask 077
NEXUS_PASSWORD="$password" keytool -genkeypair -keystore "$store" -storetype PKCS12 \
  -alias "$alias" -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=Nexus-PC Tester Build" \
  -storepass:env NEXUS_PASSWORD -keypass:env NEXUS_PASSWORD
cat > "$properties" <<PROPERTIES
storeFile=$store
storePassword=$password
keyAlias=$alias
keyPassword=$password
PROPERTIES
echo "Created $store and $properties (gitignored). Back up the keystore and password."
