FROM dev.sangah.com:5043/tomcat-base

COPY server.xml /usr/local/tomcat/conf/
COPY stnd_pmis.war /usr/local/src/

EXPOSE 8080
EXPOSE 8081

# don't add anything else after this!
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
#CMD ["catalina.sh", "run"]