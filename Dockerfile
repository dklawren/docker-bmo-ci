FROM mozillabteam/bmo-base:latest
MAINTAINER David Lawrence <dkl@mozilla.com>

RUN rsync -a /opt/bmo/local/lib/perl5/x86_64-linux-thread-multi/ /usr/local/lib64/perl5/ && \
    rsync -a --exclude x86_64-linux-thread-multi/ \
        /opt/bmo/local/lib/perl5/ /usr/local/share/perl5/

# Environment configuration
ENV BUGS_DB_DRIVER mysql
ENV BUGS_DB_NAME bugs
ENV BUGS_DB_PASS bugs
ENV BUGS_DB_HOST localhost

ENV BUGZILLA_USER bugzilla
ENV BUGZILLA_HOME /home/$BUGZILLA_USER
ENV BUGZILLA_ROOT $BUGZILLA_HOME/devel/htdocs/bmo
ENV BUGZILLA_URL http://localhost/bmo

ENV GITHUB_BASE_GIT https://github.com/mozilla-bteam/bmo
ENV GITHUB_BASE_BRANCH master

ENV ADMIN_EMAIL admin@mozilla.bugs
ENV ADMIN_PASS password

# User configuration
RUN useradd -m -G wheel -u 1000 -s /bin/bash $BUGZILLA_USER \
    && passwd -u -f $BUGZILLA_USER \
    && echo "bugzilla:bugzilla" | chpasswd

# Apache configuration
COPY conf/bugzilla.conf /etc/httpd/conf.d/bugzilla.conf

# MySQL configuration
COPY conf/my.cnf /etc/my.cnf
RUN chmod 644 /etc/my.cnf \
    && chown root.root /etc/my.cnf \
    && rm -vrf /etc/mysql \
    && rm -vrf /var/lib/mysql/*

RUN /usr/bin/mysql_install_db --user=$BUGZILLA_USER --basedir=/usr --datadir=/var/lib/mysql

# Sudoer configuration
COPY conf/sudoers /etc/sudoers
RUN chown root.root /etc/sudoers && chmod 440 /etc/sudoers

# Clone the code repo
RUN su $BUGZILLA_USER -c "git clone $GITHUB_BASE_GIT -b $GITHUB_BASE_BRANCH $BUGZILLA_ROOT"

# Copy setup and test scripts
COPY conf/checksetup_answers.txt /etc/
COPY scripts/* /usr/local/bin/
RUN chmod 755 /usr/local/bin/*

# Bugzilla dependencies and setup
RUN bugzilla_config.sh
RUN my_config.sh

# Final permissions fix
RUN chown -R $BUGZILLA_USER.$BUGZILLA_USER $BUGZILLA_HOME

# Testing scripts for CI
ADD https://selenium-release.storage.googleapis.com/2.53/selenium-server-standalone-2.53.0.jar /selenium-server.jar

# Networking
RUN echo "NETWORKING=yes" > /etc/sysconfig/network
EXPOSE 80
EXPOSE 22
EXPOSE 5900

# Supervisor
COPY conf/supervisord.conf /etc/supervisord.conf
RUN chmod 700 /etc/supervisord.conf
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
