FROM centos:centos6

MAINTAINER Taylor Monacelli <tailor@uw.edu>

# Basic packages
RUN rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
RUN yum install -y passwd
RUN yum install -y sudo
RUN yum install -y git
RUN yum install -y wget
RUN yum install -y openssl
RUN yum install -y openssh
RUN yum install -y openssh-server
RUN yum install -y openssh-clients

# I'm hopelessly stuck on emacs v24 for helm and melpa in general
RUN yum install -y wget
RUN yum install -y tar
RUN yum install -y gcc make ncurses-devel
RUN yum install -y giflib-devel libjpeg-devel libtiff-devel
RUN cd /usr/local/src && wget --timestamping http://ftp.gnu.org/pub/gnu/emacs/emacs-24.3.tar.gz
RUN cd /usr/local/src && tar xzvf emacs-24.3.tar.gz
RUN cd /usr/local/src && cd emacs-24.3 && ./configure --without-x --without-selinux && make && make install

RUN cd /root && git init && git remote add origin https://github.com/taylormonacelli/dotfiles.git && git fetch && git checkout -f -t origin/master
# CentOS is bundled with git v1.7 which can't deal with [push] default = simple
RUN cd /root && sed -i.bak 's,\(.*=.*simple\),#\1,' .gitconfig

RUN TERM=xterm && HOME=/root emacs --daemon

# Create user
RUN useradd hiroakis
RUN echo "hiroakis" | passwd hiroakis --stdin
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config
RUN sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config
RUN echo "hiroakis ALL=(ALL) ALL" >> /etc/sudoers.d/hiroakis

# Redis
RUN yum install -y redis

# RabbitMQ
RUN yum install -y erlang
RUN rpm --import http://www.rabbitmq.com/rabbitmq-signing-key-public.asc
RUN rpm -Uvh http://www.rabbitmq.com/releases/rabbitmq-server/v3.1.4/rabbitmq-server-3.1.4-1.noarch.rpm
RUN git clone git://github.com/joemiller/joemiller.me-intro-to-sensu.git
RUN cd joemiller.me-intro-to-sensu/; ./ssl_certs.sh clean && ./ssl_certs.sh generate
RUN mkdir /etc/rabbitmq/ssl
RUN cp /joemiller.me-intro-to-sensu/server_cert.pem /etc/rabbitmq/ssl/cert.pem
RUN cp /joemiller.me-intro-to-sensu/server_key.pem /etc/rabbitmq/ssl/key.pem
RUN cp /joemiller.me-intro-to-sensu/testca/cacert.pem /etc/rabbitmq/ssl/
ADD ./files/rabbitmq.config /etc/rabbitmq/
RUN rabbitmq-plugins enable rabbitmq_management

# Sensu server
ADD ./files/sensu.repo /etc/yum.repos.d/
RUN yum install -y sensu
ADD ./files/config.json /etc/sensu/
RUN mkdir -p /etc/sensu/ssl
RUN cp /joemiller.me-intro-to-sensu/client_cert.pem /etc/sensu/ssl/cert.pem
RUN cp /joemiller.me-intro-to-sensu/client_key.pem /etc/sensu/ssl/key.pem

# uchiwa
RUN yum install -y uchiwa
ADD ./files/uchiwa.json /etc/sensu/

# supervisord
RUN wget http://peak.telecommunity.com/dist/ez_setup.py;python ez_setup.py
RUN easy_install supervisor
ADD files/supervisord.conf /etc/supervisord.conf

RUN /etc/init.d/sshd start
RUN /etc/init.d/sshd stop

EXPOSE 22 3000 4567 5671 15672

CMD ["/usr/bin/supervisord"]

