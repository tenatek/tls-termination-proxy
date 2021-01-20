#!/bin/bash

# user-defined variables
declare DOMAIN_MAPPINGS=${DOMAIN_MAPPINGS:-""}
declare EMAIL_FOR_CERTBOT=${EMAIL_FOR_CERTBOT:-""}
declare USE_SINGLE_CERTIFICATE=${USE_SINGLE_CERTIFICATE:-false}

set_up_domains() {
  # wait for nginx to initialize
  until service nginx status &> /dev/null 
  do
    sleep 1
  done

  if [[ "$USE_SINGLE_CERTIFICATE" == true ]]
  then
    set_up_domains_with_single_certificate
  else
    set_up_domains_with_multiple_certificates
  fi

  # apply the configuration changes
  nginx -s reload
}

set_up_domains_with_single_certificate() {
  domain_mappings_as_array=(${DOMAIN_MAPPINGS//,/ })
  domains_as_comma_separated_list=""
  primary_domain=""
  
  for domain_mapping in ${domain_mappings_as_array[@]}
  do
    domain_mapping_as_array=(${domain_mapping//:/ })
    domains_as_comma_separated_list+=${domain_mapping_as_array[0]},

    if [[ "$primary_domain" == "" ]]
    then
      primary_domain=${domain_mapping_as_array[0]}
    fi

    DOMAIN=${domain_mapping_as_array[0]} \
      PRIMARY_DOMAIN=$primary_domain \
      CONTAINER=${domain_mapping_as_array[1]} \
      DOLLAR_SYMBOL=$ \
      envsubst < /root/assets/http.conf > /etc/nginx/conf.d/${domain_mapping_as_array[0]}.conf
  done

  domains_as_comma_separated_list=$(echo $domains_as_comma_separated_list | rev | cut -c 2- | rev)
  certbot certonly \
    --webroot --webroot-path /usr/share/nginx/html  \
    --non-interactive --keep-until-expiring --agree-tos \
    --email "$EMAIL_FOR_CERTBOT" \
    --domains "$domains_as_comma_separated_list"
}

set_up_domains_with_multiple_certificates() {
  domain_mappings_as_array=(${DOMAIN_MAPPINGS//,/ })

  for domain_mapping in ${domain_mappings_as_array[@]}
  do
    domain_mapping_as_array=(${domain_mapping//:/ })

    DOMAIN=${domain_mapping_as_array[0]} \
      PRIMARY_DOMAIN=${domain_mapping_as_array[0]} \
      CONTAINER=${domain_mapping_as_array[1]} \
      DOLLAR_SYMBOL=$ \
      envsubst < /root/assets/http.conf > /etc/nginx/conf.d/${domain_mapping_as_array[0]}.conf
    
    certbot certonly \
      --webroot --webroot-path /usr/share/nginx/html  \
      --non-interactive --keep-until-expiring --agree-tos \
      --email "$EMAIL_FOR_CERTBOT" \
      --domain "${domain_mapping_as_array[0]}"
  done
}

_() {
  # clean up the nginx web directory
  rm -rf /usr/share/nginx/html
  mkdir /usr/share/nginx/html

  # add the default nginx configuration
  rm /etc/nginx/conf.d/default.conf
  mv /root/assets/default.conf /etc/nginx/conf.d/default.conf

  # add a hook script for certbot
  mkdir -p /etc/letsencrypt/renewal-hooks/post
  mv /root/assets/hook.sh /etc/letsencrypt/renewal-hooks/post/hook.sh

  # start cron
  cron &

  # set up domains
  set_up_domains &

  # run nginx
  /docker-entrypoint.sh "$@"
}

_ "$@"
