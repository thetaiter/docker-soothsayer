FROM nginx:latest
MAINTAINER Ian Tait <itait@us.ibm.com>

RUN apt-get update && apt-get install -y unzip && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN mkdir /nginx-consul

WORKDIR /nginx-consul

COPY ./run.sh /nginx-consul/run.sh
COPY ./default.ctmpl /nginx-consul/default.ctmpl

ADD https://releases.hashicorp.com/consul-template/0.12.2/consul-template_0.12.2_linux_amd64.zip /nginx-consul/

RUN unzip /nginx-consul/consul-template_0.12.2_linux_amd64.zip -d /usr/local/bin && rm -f /nginx-consul/consul-template_0.12.2_linux_amd64.zip

EXPOSE 80

ENTRYPOINT ["/nginx-consul/run.sh"]
