FROM nginx

WORKDIR /root

RUN apt-get -yq update && apt-get -yq install certbot cron

COPY assets assets
COPY startup.sh startup.sh
RUN chmod u+x startup.sh

VOLUME /etc/letsencrypt

EXPOSE 80
EXPOSE 443

ENTRYPOINT ["/root/startup.sh"]
CMD ["nginx", "-g", "daemon off;"]
