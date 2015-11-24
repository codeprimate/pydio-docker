# ------------------------------------------------------------------------------
# Based on a work at https://github.com/docker/docker.
# ------------------------------------------------------------------------------
# Pull base image.
FROM kdelfour/supervisor-docker
MAINTAINER codeprimate <patrick@patrick-morgan.net>

# ------------------------------------------------------------------------------
# Install Base
# ------------------------------------------------------------------------------
RUN apt-get update --fix-missing
RUN apt-get install -yq wget unzip nginx fontconfig-config fonts-dejavu-core \
    php5-fpm php5-common php5-json php5-cli php5-common php5-sqlite \
    php5-gd php5-json php5-mcrypt php5-readline php-pear  \
    psmisc ssl-cert ufw libgd-tools libmcrypt-dev mcrypt vim tmux

# ------------------------------------------------------------------------------
# Configure php-fpm
# ------------------------------------------------------------------------------
RUN sed -i -e "s/output_buffering\s*=\s*4096/output_buffering = Off/g" /etc/php5/fpm/php.ini
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php5/fpm/php.ini
RUN sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 1G/g" /etc/php5/fpm/php.ini
RUN sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 1G/g" /etc/php5/fpm/php.ini
RUN php5enmod mcrypt

# ------------------------------------------------------------------------------
# Configure nginx
# ------------------------------------------------------------------------------
RUN mkdir /var/www
RUN chown www-data:www-data /var/www
RUN rm /etc/nginx/sites-enabled/*
RUN rm /etc/nginx/sites-available/*
RUN sed -i -e"s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf
RUN sed -i -e"s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 100m/" /etc/nginx/nginx.conf
RUN echo "daemon off;" >> /etc/nginx/nginx.conf
ADD conf/pydio /etc/nginx/sites-enabled/
RUN mkdir /etc/nginx/ssl
RUN openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt -subj '/CN=localhost/O=My Company Name LTD./C=US'

# ------------------------------------------------------------------------------
# Configure services
# ------------------------------------------------------------------------------
RUN update-rc.d nginx defaults
RUN update-rc.d php5-fpm defaults

# ------------------------------------------------------------------------------
# Install Pydio
# ------------------------------------------------------------------------------
ENV PYDIO_VERSION 6.2.0
WORKDIR /var/www
RUN wget http://downloads.sourceforge.net/project/ajaxplorer/pydio/stable-channel/${PYDIO_VERSION}/pydio-core-${PYDIO_VERSION}.zip
RUN unzip pydio-core-${PYDIO_VERSION}.zip
RUN mv pydio-core-${PYDIO_VERSION} pydio-core
RUN chown -R www-data:www-data /var/www/pydio-core
RUN chmod -R 770 /var/www/pydio-core
RUN chmod 777  /var/www/pydio-core/data/files/ /var/www/pydio-core/data/personal/
WORKDIR /
RUN ln -s /var/www/pydio-core/data pydio-data

# ------------------------------------------------------------------------------
# Install Transmission
# ------------------------------------------------------------------------------
ENV TRANSMISSION_ADMIN_PASSWORD xmasSON
ENV TRANSMISSION_USER debian-transmission
ADD conf/60-max-file-watches.conf /etc/sysctl.d/60-max-file-watches.conf
RUN apt-get install -y transmission-daemon
RUN touch /var/log/transmission.log && chown $TRANSMISSION_USER:$TRANSMISSION_USER /var/log/transmission.log
RUN usermod -a -G www-data debian-transmission
RUN update-rc.d transmission-daemon defaults
RUN /etc/init.d/transmission-daemon stop
ADD conf/settings.json /etc/transmission-daemon
RUN sed -i -e $(echo "s/transmission_default_password/$TRANSMISSION_ADMIN_PASSWORD/g") /etc/transmission-daemon/settings.json
RUN chown -R $TRANSMISSION_USER:$TRANSMISSION_USER /etc/transmission-daemon/
RUN chmod o-rwx /etc/transmission-daemon/settings.json
RUN mkdir /var/www/pydio-core/torrent && ln -sf /usr/share/transmission/web /var/www/pydio-core/torrent/web

# ------------------------------------------------------------------------------
# Add supervisord conf
# ------------------------------------------------------------------------------
ADD conf/startup.conf /etc/supervisor/conf.d/

# ------------------------------------------------------------------------------
# Expose ports.
# ------------------------------------------------------------------------------
EXPOSE 80
EXPOSE 443

# ------------------------------------------------------------------------------
# Expose volumes
# ------------------------------------------------------------------------------
VOLUME /pydio-data/files
VOLUME /pydio-data/personal
VOLUME /var/log
VOLUME /etc/nginx/ssl

# ------------------------------------------------------------------------------
# Start supervisor, define default command.
# ------------------------------------------------------------------------------
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
