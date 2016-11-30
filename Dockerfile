FROM danielguerra/debian-bro-develop



# add patches for bro to work with elasticsearch 2.0 (remove . set correct time)
ADD /bro-patch /bro-patch

# build bro + tools
RUN buildDeps='build-essential \
autoconf \
install-info \
libgoogle-perftools-dev \
libcurl3-dev \
curl \
libgeoip-dev \
libpcap-dev \
libssl-dev \
python-dev \
zlib1g-dev \
libedit-dev \
doxygen \
git-core \
cmake \
make \
g++ \
gcc \
libpcre3-dev \
python-setuptools \
libsnappy-dev \
libbz2-dev \
devscripts \
libjemalloc-dev \
libjemalloc1-dbg ' \
&& set -x \
&& cd /tmp \
&& git clone --recursive git://git.bro.org/bro \
&& patch /tmp/bro/aux/plugins/elasticsearch/src/ElasticSearch.cc  /bro-patch/ElasticSearch.cc.patch \
&& cd /tmp/bro \
&& ./configure \
&& make \
&& make install \
&& sed -i "s/127.0.0.1/elasticsearch/g" /tmp/bro/aux/plugins/elasticsearch/scripts/init.bro \
&& sed -i "s/2secs/60secs/g" /tmp/bro/aux/plugins/elasticsearch/scripts/init.bro \
&& sed -i "s/const max_batch_size = 1000/const max_batch_size = 500/g" /tmp/bro/aux/plugins/elasticsearch/scripts/init.bro \
&& cd /tmp/bro/aux/plugins/elasticsearch \
&& ./configure \
&& make \
&& make install \
&& cd /tmp/bro/aux/plugins/tcprs \
&& ./configure \
&& make \
&& make install \
&& cd /tmp \
&& git clone --recursive https://github.com/jonschipp/mal-dnssearch.git \
&& cd /tmp/mal-dnssearch \
&& make \
&& apt-get remove -y $buildDeps \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# add maintance shell scripts
ADD /scripts /scripts

#add extra bro files
ADD /bro-extra /usr/local/bro/share/bro/bro-extra
RUN echo "@load bro-extra" >> /usr/local/bro/share/bro/base/init-default.bro

# add botflex
RUN cd /usr/local/bro/share/bro/  \
&& git clone --recursive https://github.com/sheharbano/botflex.git botflex \
&& echo "@load botflex/detection/correlation/correlation.bro" >> base/init-default.bro

# add dr watson
RUN cd /usr/local/bro/share/bro/  \
&& git clone --recursive https://github.com/broala/bro-drwatson.git drwatson \
&& echo "@load drwatson" >> base/init-default.bro

# add shellshock
RUN cd /usr/local/bro/share/bro/  \
&& git clone --recursive https://github.com/broala/bro-shellshock.git shellshock \
&& echo "@load shellshock" >> base/init-default.bro

#Critical Stack

RUN /scripts/script.deb.sh
RUN apt-get install critical-stack-intel
RUN critical-stack-intel api e9738524-80c0-4d47-7c8a-f1eb1300a3ef

# add bro-scripts
RUN cd /usr/local/bro/share/bro/  \
&& git clone --recursive https://github.com/reservoirlabs/bro-scripts.git bro-scripts \
&& echo "@load bro-scripts/clickbot" >> site/local.bro \
&& echo "@load bro-scripts/supercomputing/producer-consumer-ratio" >> site/local.bro \
&& echo "@load bro-scripts/supercomputing/protocol-stats" >> site/local.bro \
&& echo "@load bro-scripts/supercomputing/http-exe-bad-attributes" >> site/local.bro \
&& echo "@load bro-scripts/supercomputing/smtp-url" >> site/local.bro \
&& echo "@load bro-scripts/supercomputing/top-metrics" >> base/init-default.bro \
&& echo "@load bro-scripts/supercomputing/unique-hosts" >> base/init-default.bro \
&& echo "@load bro-scripts/supercomputing/unique-macs" >> base/init-default.bro\
&& echo "@load bro-scripts/track-dhcp/track-dhcp" >> base/init-default.bro \
&& echo "@load misc/detect-traceroute" >> site/local.bro \
&& echo "@load policy/protocols/smb" >> site/local.bro \
&& echo "@load policy/protocols/ssl/heartbleed" >> site/local.bro
# add bro service
RUN echo "bro             1969/tcp                        # bro pcap feed" >> /etc/services

#fresh intel
RUN /scripts/update-intel.sh
#set the expose ports
EXPOSE 22
EXPOSE 1969
EXPOSE 47761
EXPOSE 47762

#set default dir
WORKDIR /tmp

#Add geolitecityv6
RUN wget http://geolite.maxmind.com/download/geoip/database/GeoLiteCityv6-beta/GeoLiteCityv6.dat.gz
RUN gunzip GeoLiteCityv6.dat.gz
RUN mv GeoLiteCityv6.dat /usr/share/GeoIP/GeoLiteCityv6.dat
RUN ln -s /usr/share/GeoIP/GeoLiteCityv6.dat /usr/share/GeoIP/GeoIPCityv6.dat

# Do some elasticsearch tweaks (couldnt solve it with mapping :`( )
# elastic is not happy about version, type change count/string
RUN sed -i "s/version:     count           \&log/socks_version:     count           \&log/g" /usr/local/bro/share/bro/base/protocols/socks/main.bro
RUN sed -i "s/\$version=/\$socks_version=/g" /usr/local/bro/share/bro/base/protocols/socks/main.bro
RUN sed -i "s/version:          string \&log/ssl_version:     string \&log/g" /usr/local/bro/share/bro/base/protocols/ssl/main.bro
RUN sed -i "s/\$version=/\$ssl_version=/g" /usr/local/bro/share/bro/base/protocols/ssl/main.bro
RUN sed -i "s/version:         count        \&log/ssh_version:         count        \&log/g" /usr/local/bro/share/bro/base/protocols/ssh/main.bro
RUN sed -i "s/\$version =/\$ssh_version =/g" /usr/local/bro/share/bro/base/protocols/ssh/main.bro
RUN sed -i "s/version: string \&log/snmp_version: string \&log/g" /usr/local/bro/share/bro/base/protocols/snmp/main.bro
RUN sed -i "s/\$version=/\$snmp_version=/g" /usr/local/bro/share/bro/base/protocols/snmp/main.bro



# bro pcap-in tcp services
ADD /xinetd /xinetd

# add role scripts
ADD /role /role

# add php scripts
ADD /php/index.php /var/www/html/index.php

# add supervisor config
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf

#create output dirs
RUN mkdir /bro /bro/pcap

CMD ["/role/cmd-bare"]
