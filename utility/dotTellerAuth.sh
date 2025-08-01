#!/bin/bash

KEY="~/.dotTellerCreds/certificate.pem"
CERT="~/.dotTellerCreds/private_key.pem"
URL="https://api.teller.io"

if [ "$1" == "accounts" ]; then
  ENDPOINT="/accounts"
elif [ "$1" == "identity" ]; then
  ENDPOINT="/identity"
else
  echo "Usage: $0 [accounts|identity]"
  exit 1
fi

curl --cert "$CERT" --key "$KEY" "$URL$ENDPOINT"


