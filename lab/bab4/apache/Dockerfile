FROM httpd:2.4-alpine

RUN sed -i 's|^#Include conf/extra/httpd-vhosts\.conf$|Include conf/extra/httpd-vhosts.conf|' \
      /usr/local/apache2/conf/httpd.conf \
    && printf '\nServerName localhost\n' >> /usr/local/apache2/conf/httpd.conf \
    && httpd -t
