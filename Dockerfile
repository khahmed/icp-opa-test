# docker build -t icptest .
FROM centos:7
MAINTAINER Khalid Ahmed <khalida@ca.ibm.com>
RUN yum -y  install curl
COPY kubectl /usr/local/bin/kubectl
RUN chmod 755 /usr/local/bin/kubectl
COPY loadopa.sh /loadopa.sh
RUN chmod 755 /loadopa.sh
COPY icpstate.rego  /icpstate.rego

CMD /loadopa.sh


