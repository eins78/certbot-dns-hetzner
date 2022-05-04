#!/bin/bash
set -eu

# env vars from certbot:
# the hostname that is is validated
challenge_domain="$CERTBOT_DOMAIN"
# the content of the validation challenge
challenge_string="$CERTBOT_VALIDATION"

# our config, the API token for the Hetzner DNS API
api_auth_token=$(cat /etc/hetzner-dns-token)

# check if validation for this hostname was delegated (with a CNAME record)
challenge_cname="$(dig +noall +short "_acme-challenge.${CERTBOT_DOMAIN}" | sed 's/\.$//')"
if test -n "$challenge_cname"; then challenge_domain="$challenge_cname"; fi

# find the id of the "zone" in the DNS console which we need to modify
zone_domain="$challenge_domain"
while test -z "$zone_id" ; do
  zone_id=$(curl --silent -H "Auth-API-Token: ${api_auth_token}" \
    "https://dns.hetzner.com/api/v1/zones?search_name=${zone_domain}" | \
    jq ".\"zones\"[] | select(.name == \"${zone_domain}\") | .id" 2>/dev/null | tr -d '"')
  # if not found yet, continue looking with 1 less sudomain
  zone_domain="$(echo "$zone_domain" | cut -s -d'.' -f 2-)"
  # fail when search is exhausted (no more subdomains to remove)
  if test -z "$zone_domain"; then
    echo "ERROR: could not find DNS zone!" >&2;
    exit 1;
  fi
done

# create the actual "challenge DNS record"
curl --silent -X "POST" "https://dns.hetzner.com/api/v1/records" \
  -H 'Content-Type: application/json' \
  -H "Auth-API-Token: ${api_auth_token}" \
  -d "{ \"value\": \"${challenge_string}\", \"ttl\": 300, \"type\": \"TXT\", \"name\": \"${challenge_domain}.\", \"zone_id\": \"${zone_id}\" }"

# wait until we can observe the correct value in the DNS record
printf "waiting for DNS record to be visible..." && \
while ! test "\"${challenge_string}\"" = "$(dig -t txt +short "${challenge_domain}")"; do printf '.'; sleep 3; done && \
echo " OK!"
