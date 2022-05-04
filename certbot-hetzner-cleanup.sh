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
  echo "zone_id: ${zone_id}" # DEBUG
  echo "zone_domain: ${zone_domain}" # DEBUG
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

# find and delete the validation record (possibly several)
record_ids=$(curl --silent -H "Auth-API-Token: ${api_auth_token}" \
        "https://dns.hetzner.com/api/v1/records?zone_id=$zone_id" | \
       jq ".\"records\"[] | select(.name == \"${challenge_domain}.\") | .id" 2>/dev/null | tr -d '"')

for record_id in $record_ids; do
  curl --silent -H "Auth-API-Token: ${api_auth_token}" \
    -X "DELETE" "https://dns.hetzner.com/api/v1/records/${record_id}"
done