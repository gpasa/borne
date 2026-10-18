#!/bin/bash
# Prints the SHA-1 of the Developer ID Application identity to sign with: issued by the G2 authority, the one
# that expires last. Several identities can carry the same name — the certificates of the previous authority
# stop on 1 February 2027 — and codesign, given the name alone, refuses an ambiguous choice or takes any.
#
#   IDENTITY=$(scripts/devid_identity.sh)
set -euo pipefail
best=""; bestEnd=0
valid=$(security find-identity -v -p codesigning | awk '/Developer ID Application/ {print $2}')
for sha in $valid; do
  pem=$(security find-certificate -a -Z -p -c "Developer ID Application" 2>/dev/null |
        awk -v sha="$sha" '/^SHA-1 hash:/ {keep = ($3 == sha)} keep && /BEGIN CERT/,/END CERT/ {print}')
  [ -n "$pem" ] || continue
  issuer=$(printf '%s\n' "$pem" | openssl x509 -noout -issuer 2>/dev/null)
  case "$issuer" in *"OU=G2"*|*"OU = G2"*) ;; *) continue ;; esac
  end=$(printf '%s\n' "$pem" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  ts=$(date -j -f "%b %e %T %Y %Z" "$end" +%s 2>/dev/null || echo 0)
  if [ "$ts" -gt "$bestEnd" ]; then best=$sha; bestEnd=$ts; fi
done
[ -n "$best" ] || { echo "aucune identité Developer ID Application de l'autorité G2 dans le trousseau" >&2; exit 1; }
echo "$best"
