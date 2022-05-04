# Lets’ Encrypt x Hetzner DNS challenge

> _forked from <https://github.com/dschoeffm/hetzner-dns-certbot>_

## usage

install:

- get a [API TOken for the Hetzner DNS Console](https://docs.hetzner.com/dns-console/dns/general/api-access-token)

```bash
apt update && apt install -y curl jq certbot
for SCRIPT in certbot-hetzner-auth.sh certbot-hetzner-cleanup.sh; do
  curl -sL "https://github.com/eins78/hetzner-dns-certbot/raw/master/${SCRIPT}" > "/usr/local/bin/${SCRIPT}" && chmod +x "/usr/local/bin/${SCRIPT}"
done
echo 'your_secret_hetzner_dns_api_token' > /etc/hetzner-dns-token
```

<!--
```bash
# could be run in a docker container or on the linux
❯ docker run --rm -it ubuntu
❯ ssh root@letsencrypt-test.example.org
```
-->

run:

```bash
# regular
certbot certonly -n \
--agree-tos --no-eff-email \
-m 'office+letest@kte.is' --manual-public-ip-logging-ok \
--manual --preferred-challenges=dns --manual-auth-hook /usr/local/bin/certbot-hetzner-auth.sh --manual-cleanup-hook /usr/local/bin/certbot-hetzner-cleanup.sh \
-d customer.example.org

# wildcard
certbot certonly -n \
--agree-tos --no-eff-email \
-m 'office+letest@kte.is' --manual-public-ip-logging-ok \
--manual --preferred-challenges=dns --manual-auth-hook /usr/local/bin/certbot-hetzner-auth.sh --manual-cleanup-hook /usr/local/bin/certbot-hetzner-cleanup.sh \
-d letsencrypt-test.kiste.li -d *.letsencrypt-test.kiste.li

```

## Delegation via `CNAME`

Its possible to delegate the DNS-validation of a domain A to another domain B.
Common example: A is a customer and B is a hosting provider.

Advantages:

- a domain can be validated without the host needing to be reachable via HTTP from the internet (like for internal sytems that are behind a firewall)
- a (customer) domain can be validated without the customer needing a secret token
- a (customer) domain can be validated without the hosting provider needing permissions to configure the customer domains DNS
- because it is a DNS challenge, a _wildcard_ certificate can also be issued

Further Reading:

- LetsEncrypt post about this: <https://letsencrypt.org/2019/10/09/onboarding-your-customers-with-lets-encrypt-and-acme.html>

- Hetzner Docs:
  <https://community.hetzner.com/tutorials/letsencrypt-dns>

### DNS record at customer domain

This delegates the DNS-validation of the domain customer.example.org to another domain under the example.com namespace

```text
_acme-challenge.customer.example.org. 10800 IN CNAME letsencrypt-test.example.org._validation.example.com.
```

## fork

the repo was forked to fix the problem:

- Hetzner script tries the real domain, not the delegated one. Could be solved by looking up in DNS, but for the example we can hardcode it.
  <!-- - Lookup with dig: $ dig +noall +short \_acme-challenge.customer.example.org | sed 's/.$//' -->
- original project [was declared to be unmaintained](https://github.com/dschoeffm/hetzner-dns-certbot/issues/9#issuecomment-949838474)
