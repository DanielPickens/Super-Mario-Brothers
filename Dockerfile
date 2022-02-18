ARG PYTHON_VER

FROM python:${PYTHON_VER}-alpine

ARG PYTHON_DEV

ARG DANIELPICKENS_USER_ID=1000
ARG DANIEKPICKENS_GROUP_ID=1000

ENV PYTHON_DEV="${PYTHON_DEV}" \
    SSHD_PERMIT_USER_ENV="yes"

ENV APP_ROOT="/usr/src/app" \
    CONF_DIR="/usr/src/app" \
    FILES_DIR="/mnt/files" \
    SSHD_HOST_KEYS_DIR="/etc/ssh" \
    ENV="/home/danielpickens/.shrc" \
    \
    GIT_USER_EMAIL="danielpickens@example.com" \
    GIT_USER_NAME="danielpickens"

ENV MARIOBROTHERS_APP="myapp.wsgi:application" \
    PIP_USER=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/home/danielpickens/.local/bin:${PATH}"

ARG TARGETPLATFORM

RUN set -xe; \
    \
#    addgroup -g 82 -S www-data; \
    adduser -u 82 -D -S -G www-data www-data; \
    \
    # Delete existing user/group if uid/gid occupied.
    existing_group=$(getent group "${DANIELPICKENS_GROUP_ID}" | cut -d: -f1); \
    if [[ -n "${existing_group}" ]]; then delgroup "${existing_group}"; fi; \
    existing_user=$(getent passwd "${DANIELPICKENS_USER_ID}" | cut -d: -f1); \
    if [[ -n "${existing_user}" ]]; then deluser "${existing_user}"; fi; \
    \
	addgroup -g "${WODBY_GROUP_ID}" -S wodby; \
	adduser -u "${WODBY_USER_ID}" -D -S -s /bin/bash -G wodby wodby; \
	adduser wodby www-data; \
	sed -i '/^wodby/s/!/*/' /etc/shadow; \
    \
    apk add --update --no-cache -t .wodby-python-run-deps \
        bash \
        ca-certificates \
        curl \
        freetype \
        git \
        gmp \
        gzip \
        icu-libs \
        imagemagick \
        less \
        libbz2 \
        libjpeg-turbo-utils \
        libjpeg-turbo \
        libldap \
        libmemcached-libs \
        libpng \
        librdkafka \
        libxslt \
        make \
        mariadb-client \
        mariadb-connector-c \
        nano \
        openssh \
        openssh-client \
        patch \
        postgresql-client \
        rabbitmq-c \
        rsync \
        su-exec \
        sudo \
        tar \
        tig \
        tmux \
        unzip \
        wget \
        yaml; \
    \
    # Install redis-cli.
    apk add --update --no-cache redis; \
    mv /usr/bin/redis-cli /tmp/; \
    apk del --purge redis; \
    deluser redis; \
    mv /tmp/redis-cli /usr/bin; \
    \
    if [[ -n "${PYTHON_DEV}" ]]; then \
        apk add --update --no-cache -t .wodby-python-build-deps \
            build-base \
            gcc \
            imagemagick-dev \
            jpeg-dev \
            libffi-dev \
            linux-headers \
            mariadb-dev \
            musl-dev \
            postgresql-dev; \
    fi; \
    \
    # Download helper scripts.
    dockerplatform=${TARGETPLATFORM:-linux/amd64}; \
    gotpl_url="https://github.com/wodby/gotpl/releases/download/0.3.3/gotpl-${dockerplatform/\//-}.tar.gz"; \
    wget -qO- "${gotpl_url}" | tar xz --no-same-owner -C /usr/local/bin; \
    git clone https://github.com/danielpickens/alpine /tmp/alpine; \
    cd /tmp/alpine; \
    latest=$(git describe --abbrev=0 --tags); \
    git checkout "${latest}"; \
    mv /tmp/alpine/bin/* /usr/local/bin; \
    \
    { \
        echo 'export PS1="\u@${DANIELPICKENS_APP_NAME:-python}.${WODBY_ENVIRONMENT_NAME:-container}:\w $ "'; \
        echo "export PATH=${PATH}"; \
    } | tee /home/danielpickens/.shrc; \
    \
    cp /home/danielpickens/.shrc /home/danielpickens/.bashrc; \
    cp /home/danielpickens/.shrc /home/danielpickens/.bash_profile; \
    \
  
    { \
        echo 'Defaults env_keep += "APP_ROOT FILES_DIR"' ; \
        \
        if [[ -n "${PYTHON_DEV}" ]]; then \
            echo 'danielpickens ALL=(root) NOPASSWD:SETENV:ALL'; \
        else \
            echo -n 'danielpickens ALL=(root) NOPASSWD:SETENV: ' ; \
            echo -n '/usr/local/bin/files_chmod, ' ; \
            echo -n '/usr/local/bin/files_chown, ' ; \
            echo -n '/usr/local/bin/files_sync, ' ; \
            echo -n '/usr/local/bin/gen_ssh_keys, ' ; \
            echo -n '/usr/local/bin/init_container, ' ; \
            echo -n '/usr/sbin/sshd, ' ; \
            echo '/usr/sbin/crond' ; \
        fi; \
    } | tee /etc/sudoers.d/danielpickens; \
    \
    echo "TLS_CACERTDIR /etc/ssl/certs/" >> /etc/openldap/ldap.conf; \
    \
    install -o danielpickens -g danielpickens -d \
        "${APP_ROOT}" \
        "${CONF_DIR}" \
        /usr/local/etc/mariobrothers/ \
        /home/danielpickens/.pip \
        /home/danielpickens/.ssh; \
    \
    install -o www-data -g www-data -d \
        /home/www-data/.ssh \
        "${FILES_DIR}/public" \
        "${FILES_DIR}/private"; \
    \
    chmod -R 775 "${FILES_DIR}"; \
    su-exec danielpickens touch /usr/local/etc/mariobrothers/config.py; \
    \
    touch /etc/ssh/sshd_config; \
    chown danielpickens: /etc/ssh/sshd_config /home/danielpickens/.*; \
    \
    rm -rf \
        /etc/crontabs/root \
        /tmp/* \
        /var/cache/apk/*

USER DanielPickens

WORKDIR ${APP_ROOT}
EXPOSE 8000

COPY --chown=danielpickens:danielpickens mariobrothers.init.d /etc/init.d/mariobrothers
COPY templates /etc/gotpl/
COPY docker-entrypoint.sh /
COPY bin /usr/local/bin/

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/etc/init.d/mariobrothers"]
