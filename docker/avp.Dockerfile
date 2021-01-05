FROM golang:1.14.13-stretch

ENV GO111MODULE=on

WORKDIR $GOPATH/src/github.com/pion/ion

COPY go.mod go.sum ./
RUN cd $GOPATH/src/github.com/pion/ion && go mod download

COPY pkg/ $GOPATH/src/github.com/pion/ion/pkg
COPY cmd/ $GOPATH/src/github.com/pion/ion/cmd

WORKDIR $GOPATH/src/github.com/pion/ion/cmd/avp
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o /avp .

FROM ubuntu:18.04
COPY --from=0 /avp /usr/local/bin/avp
COPY configs/docker/avp.toml /configs/avp.toml

# logging
RUN apt update -y
RUN apt-get update && apt-get install -y gnupg2
RUN apt install -y wget
RUN wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
RUN apt-get install apt-transport-https
RUN echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-7.x.list
RUN apt-get install -y systemd
RUN apt-get update && apt-get install filebeat
RUN systemctl enable filebeat
RUN update-rc.d filebeat defaults 95 10
RUN mkdir -p /etc/pki/tls/certs
RUN wget https://raw.githubusercontent.com/logzio/public-certificates/master/AAACertificateServices.crt -O /etc/pki/tls/certs/COMODORSADomainValidationSecureServerCA.crt
RUN apt-get install -y --reinstall rsyslog
RUN update-rc.d rsyslog defaults
RUN update-rc.d rsyslog enable

RUN cp /etc/pki/tls/certs/COMODORSADomainValidationSecureServerCA.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates

COPY filebeat.yml /etc/filebeat/filebeat.yml

CMD ["bash", "-c", "cd /etc/init.d && ./filebeat start && /usr/local/bin/avp -c /configs/avp.toml &> /var/log/ion.log"]
