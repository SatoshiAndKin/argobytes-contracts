FROM debian:buster

# TODO: magic to make user not root

ENTRYPOINT bash
VOLUME /myapp
WORKDIR /myapp

ENV PATH /venv/bin:$PATH

RUN { set -eux; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        bash \
        gcc \
        python3 \
        python3-dev \
        python3-venv \
    ; \
    rm -rf /var/lib/apt/lists/*; \
}

RUN python3 -m venv /venv

COPY requirements.txt /myapp/

# This will be the python/pip in the venv
RUN pip install --disable-pip-version-check --no-cache-dir -r /myapp/requirements.txt

COPY . /myapp/
