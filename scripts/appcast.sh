#!/bin/zsh
# Flux de mise à jour Sparkle, un par architecture, pour la version de project.yml :
# dist/appcast-arm64.xml et dist/appcast-x86_64.xml, à joindre à la release GitHub avec les
# zip. Borne lit celui de la dernière release (releases/latest/download/appcast-<arch>.xml).
# La signature EdDSA vient de la clé « borne » du trousseau (generate_keys --account borne).
#   scripts/appcast.sh notes.html     # notes de version en HTML (court)
set -euo pipefail
cd "${0:A:h}/.."
NOTES=${1:?notes HTML}
SPARKLE=${SPARKLE_BIN:-../Engines/downloads/sparkle-2.10.0/bin}
VERSION=$(awk -F'"' '/MARKETING_VERSION/{print $2}' project.yml)
BUILD=$(awk -F'"' '/CURRENT_PROJECT_VERSION/{print $2}' project.yml)
for pair in arm64:AppleSilicon x86_64:Intel; do
    ARCH=${pair%%:*}; NAME=${pair#*:}
    ZIP=dist/Borne-$NAME.zip
    SIG=$($SPARKLE/sign_update --account borne $ZIP)
    cat > dist/appcast-$ARCH.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
<channel>
<title>Borne</title>
<item>
<title>Borne $VERSION</title>
<pubDate>$(LC_ALL=C date -R)</pubDate>
<sparkle:version>$BUILD</sparkle:version>
<sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
<sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
<description><![CDATA[$(cat $NOTES)]]></description>
<enclosure url="https://github.com/gpasa/borne/releases/download/v$VERSION/Borne-$NAME.zip" type="application/octet-stream" $SIG/>
</item>
</channel>
</rss>
XML
    echo "dist/appcast-$ARCH.xml : Borne $VERSION ($BUILD)"
done
