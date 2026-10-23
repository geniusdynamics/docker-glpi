#On choisit une debian
FROM debian:12.15

LABEL org.opencontainers.image.authors="github@genius.ke"

# GLPI release shipped in this image; the checksum is the "digest" of the
# release asset published on GitHub. Bump both together.
ARG GLPI_VERSION=10.0.28
ARG GLPI_SHA256=3e5bede7854414b14acd302f7102ab74968f0c74a89928d8329098b17fafd8e9
# Lowest PHP release with the PHP2Shell fixes (CVE-2026-109618/109619) in the 8.3 branch
ARG PHP_MIN_VERSION=8.3.36

#Ne pas poser de question à l'installation
ENV DEBIAN_FRONTEND=noninteractive

#Installation d'apache et de php8.3 avec extension
RUN apt update \
&& apt install --yes ca-certificates apt-transport-https lsb-release wget curl \
&& curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg \
&& sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' \
&& apt update \
&& apt install --yes --no-install-recommends \
apache2 \
php8.3 \
php8.3-mysql \
php8.3-bcmath \
php8.3-ldap \
php8.3-xmlrpc \
php8.3-imap \
php8.3-curl \
php8.3-gd \
php8.3-mbstring \
php8.3-xml \
php-cas \
php8.3-intl \
php8.3-zip \
php8.3-bz2 \
php8.3-redis \
cron \
jq \
libldap-2.5-0 \
libldap-common \
libsasl2-2 \
libsasl2-modules \
libsasl2-modules-db \
&& rm -rf /var/lib/apt/lists/*

# Refuse to build an image with a PHP release that lacks the security fixes
RUN php -r 'exit(version_compare(PHP_VERSION, getenv("PHP_MIN_VERSION"), ">=") ? 0 : 1);' \
|| { echo "PHP $(php -r 'echo PHP_VERSION;') is older than ${PHP_MIN_VERSION}" >&2; exit 1; }

# GLPI sources are part of the image (verified checksum) instead of being
# downloaded at container start; glpi-start.sh copies them into the volume.
RUN curl -fsSLo /tmp/glpi.tgz "https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz" \
&& echo "${GLPI_SHA256}  /tmp/glpi.tgz" | sha256sum -c - \
&& tar -xzf /tmp/glpi.tgz -C /usr/src \
&& rm /tmp/glpi.tgz \
&& test "$(ls /usr/src/glpi/version)" = "${GLPI_VERSION}"

COPY 99-glpi.ini /etc/php/8.3/apache2/conf.d/99-glpi.ini

#Copie et execution du script pour l'installation et l'initialisation de GLPI
COPY glpi-start.sh /opt/
RUN chmod +x /opt/glpi-start.sh
ENTRYPOINT ["/opt/glpi-start.sh"]

#Exposition des ports
EXPOSE 80 443
