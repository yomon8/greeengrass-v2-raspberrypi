FROM python:3.9.16-slim-bullseye

ARG ANSIBLE_VERSION

RUN pip install pip --upgrade
RUN pip install ansible==${ANSIBLE_VERSION}

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ssh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
