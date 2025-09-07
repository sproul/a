#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Pipes will fail if any command in the pipeline fails.
set -o pipefail

debug_mode=''
dry_mode=''
t=`mktemp`; trap "rm $t*" EXIT
verbose_mode=''
while [ -n "$1" ]; do
        case "$1" in
                -dry)
                        dry_mode=-dry
                ;;
                -q|-quiet)
                        verbose_mode=''
                ;;
                -v|-verbose)
                        verbose_mode=-v
                ;;
                -x)
                        set -x
                        debug_mode=-x
                ;;
                -*)
                        echo "FAIL unrecognized flag $1" 1>&2
                        exit 1
                ;;
                *)
                        break
                ;;
        esac
        shift
done
# Treat unset variables as an error when substituting.
set -u

URL="http://localhost:3000/chat"
PROMPT="2+2="
EXPECTED_RESPONSE="4"

# Send the request to the chat endpoint
response=$(curl -s -X POST "$URL" --data-urlencode "chat_input=$PROMPT")

# Check if the response contains the expected answer
if echo "$response" | grep -q "$EXPECTED_RESPONSE"; then
    echo "OK test_LLM_connectivity.sh found '$EXPECTED_RESPONSE' in the response."
    exit 0
else
    echo "FAIL: test_LLM_connectivity.sh did not find '$EXPECTED_RESPONSE' in the response."
    echo "Response: $response"
    exit 1
fi
exit
$dp/git/a/test/test_LLM_connectivity.sh -x