#!/bin/bash
# check if wikitech and wikitech-static are in sync
# T89323 - dzahn 20150511

# CONFIG
WIKITECH="https://wikitech.wikimedia.org/w/api.php"
WIKITECHSTATIC="https://wikitech-static.wikimedia.org/w/api.php"
API_QUERY="action=query&titles=Special:RecentChanges&list=recentchanges&format=xml"

AGE_LIMIT=200000 # seconds

# MAIN
TS_WIKITECH=$(curl $WIKITECH?$API_QUERY 2> /dev/null | grep -o "timestamp.*" | cut -d\" -f2)
TS_STATIC=$(curl $WIKITECHSTATIC?$API_QUERY 2> /dev/null | grep -o "timestamp.*" | cut -d\" -f2)

# echo "wikitech: ${TS_WIKITECH} static: ${TS_STATIC}"

TS_WS=$(date -d "$TS_WIKITECH" "+%s")
TS_SS=$(date -d "$TS_STATIC" "+%s")
TS_DIFF=$(( $TS_WS - $TS_SS ))

# echo "diff is ${TS_DIFF}"

if [ -z $TS_WIKITECH ]; then

    echo "wikitech-static CRIT - failed to fetch timestamp from wikitech"
    exit 2
fi


if [ -z $TS_STATIC ]; then

    echo "wikitech-static CRIT - failed to fetch timestamp from wikitech-static"
    exit 2
fi

if [ $TS_DIFF -gt $AGE_LIMIT ]; then

    echo "wikitech-static CRIT - wikitech and wikitech-static out of sync (${TS_DIFF}s > ${AGE_LIMIT}s)"
    exit 2

fi

if [ $TS_DIFF -lt $AGE_LIMIT ]; then

    echo "wikitech-static OK - wikitech and wikitech-static in sync (${TS_DIFF} < ${AGE_LIMIT}s)"
    exit 0

fi

echo "wikitech-static UNKNOWN - please check $0"
exit 3
