FROM ubuntu

RUN apt-get update && \
    apt-get install -y software-properties-common procps vim && \    
    add-apt-repository ppa:longsleep/golang-backports && \
    apt-get update && \
    apt-get install -y golang-go
RUN  touch HOST-ROOT / && mkdir -p /opt/container-filesystem    
WORKDIR /opt/container-filesystem 
COPY ubuntu.tar /opt/container-filesystem
RUN tar xvf ubuntu.tar && touch CONTAINER-ROOT /opt/container-filesystem
ENV PS1="\h$ "
WORKDIR /root