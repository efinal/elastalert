# current node:alpine is based on alpine 3.9 which install python3.6
# to keep it consistent, we specify the version here
FROM alpine:3.9 as py-ea
ARG ELASTALERT_VERSION=v0.2.1
ENV ELASTALERT_VERSION=${ELASTALERT_VERSION}
# URL from which to download Elastalert.
ARG ELASTALERT_URL=https://github.com/Yelp/elastalert/archive/$ELASTALERT_VERSION.zip
ENV ELASTALERT_URL=${ELASTALERT_URL}
# Elastalert home directory full path.
ENV ELASTALERT_HOME /opt/elastalert

WORKDIR /opt

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories
# rm py3-yaml here as we require higher version of pyyaml later
# add yaml-dev here as we need build higher version of pyyaml later
RUN apk add --update --no-cache ca-certificates openssl-dev openssl python3-dev python3 py3-pip yaml-dev libffi-dev gcc musl-dev wget && \
# Download and unpack Elastalert.
    wget -O elastalert.zip "${ELASTALERT_URL}" && \
    unzip elastalert.zip && \
    rm elastalert.zip && \
    mv e* "${ELASTALERT_HOME}" && \
    sed -i 's/PyYAML>=3.12/PyYAML>=5.1/g' ${ELASTALERT_HOME}/setup.py && \
    sed -i 's/PyYAML>=3.12/PyYAML>=5.1/g' ${ELASTALERT_HOME}/requirements.txt

WORKDIR "${ELASTALERT_HOME}"

# Set mirror
RUN pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple/
# Install Elastalert.
RUN pip3 install "setuptools>=11.3" -i https://mirrors.aliyun.com/pypi/simple/ && \
    /bin/echo -e [easy_install]\\nindex-url = https://mirrors.aliyun.com/pypi/simple >> setup.cfg && \
    python3 setup.py install && \
    pip3 install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/

FROM node:12.8.1-alpine
LABEL maintainer="BitSensor <dev@bitsensor.io>"
# Set timezone for this container
ENV TZ Aisa/Chongqing
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories
RUN apk add --update --no-cache curl tzdata python python3 make libmagic

COPY --from=py-ea /usr/lib/python3.6/site-packages /usr/lib/python3.6/site-packages
COPY --from=py-ea /opt/elastalert /opt/elastalert
COPY --from=py-ea /usr/bin/elastalert* /usr/bin/

WORKDIR /opt/elastalert-server
COPY . /opt/elastalert-server

RUN npm install --production --quiet --registry https://registry.npm.taobao.org
COPY config/elastalert.yaml /opt/elastalert/config.yaml
COPY config/elastalert-test.yaml /opt/elastalert/config-test.yaml
COPY config/config.json config/config.json
COPY rule_templates/ /opt/elastalert/rule_templates
COPY elastalert_modules/ /opt/elastalert/elastalert_modules

# Add default rules directory
# Set permission as unpriviledged user (1000:1000), compatible with Kubernetes
RUN mkdir -p /opt/elastalert/rules/ /opt/elastalert/server_data/tests/ \
    && chown -R node:node /opt

USER node

EXPOSE 3030
ENTRYPOINT ["npm", "start"]
#can keep the container running
#CMD tail -f /dev/null