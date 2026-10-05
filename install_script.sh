#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# System Required: CentOS 7+/Ubuntu 18+/Debian 10+
# Version: 2026.10.05-r1
# Description: One click Install Trojan Panel server
# Author: jonssonyan <https://jonssonyan.com>
# Fork: https://github.com/electronlsr/install-script

init_var() {
  ECHO_TYPE="echo -e"

  package_manager=""
  release=""
  get_arch=""
  can_google=0

  # Docker
  DOCKER_MIRROR='"https://hub-mirror.c.163.com","https://ccr.ccs.tencentyun.com","https://mirror.baidubce.com","https://dockerproxy.com"'

  # Project directory
  TP_DATA="/tpdata/"

  STATIC_HTML="https://github.com/trojanpanel/install-script/releases/download/v1.0/html.tar.gz"

  # Web
  WEB_PATH="/tpdata/web/"

  # Cert
  CERT_PATH="/tpdata/cert/"
  DOMAIN_FILE="/tpdata/domain.lock"
  domain=""
  crt_path=""
  key_path=""

  # Caddy2
  CADDY_DATA="/tpdata/caddy/"
  CADDY_CONFIG="${CADDY_DATA}config.json"
  CADDY_LOG="${CADDY_DATA}logs/"
  CADDY_CERT_DIR="${CERT_PATH}certificates/acme-v02.api.letsencrypt.org-directory/"
  caddy_port=80
  caddy_remote_port=8863
  your_email=""
  ssl_option=1
  ssl_module_type=1
  ssl_module="acme"

  # Nginx
  NGINX_DATA="/tpdata/nginx/"
  NGINX_CONFIG="${NGINX_DATA}default.conf"
  nginx_port=80
  nginx_remote_port=8863
  nginx_https=1

  # MariaDB
  MARIA_DATA="/tpdata/mariadb/"
  mariadb_ip="127.0.0.1"
  mariadb_port=9507
  mariadb_user="root"
  mariadb_pas=""

  # Redis
  REDIS_DATA="/tpdata/redis/"
  redis_host="127.0.0.1"
  redis_port=6378
  redis_pass=""

  # Trojan Panel Frontend
  TROJAN_PANEL_UI_DATA="/tpdata/trojan-panel-ui/"
  # Nginx
  UI_NGINX_DATA="${TROJAN_PANEL_UI_DATA}nginx/"
  UI_NGINX_CONFIG="${UI_NGINX_DATA}default.conf"
  trojan_panel_ui_port=8888
  ui_https=1
  trojan_panel_ip="127.0.0.1"
  trojan_panel_server_port=8081

  # Trojan Panel Backend
  TROJAN_PANEL_DATA="/tpdata/trojan-panel/"
  TROJAN_PANEL_WEBFILE="${TROJAN_PANEL_DATA}webfile/"
  TROJAN_PANEL_LOGS="${TROJAN_PANEL_DATA}logs/"
  TROJAN_PANEL_CONFIG="${TROJAN_PANEL_DATA}config/"
  trojan_panel_config_path="${TROJAN_PANEL_DATA}config/config.ini"
  trojan_panel_port=8081

  # Trojan Panel Core
  TROJAN_PANEL_CORE_DATA="/tpdata/trojan-panel-core/"
  TROJAN_PANEL_CORE_LOGS="${TROJAN_PANEL_CORE_DATA}logs/"
  TROJAN_PANEL_CORE_CONFIG="${TROJAN_PANEL_CORE_DATA}config/"
  trojan_panel_core_config_path="${TROJAN_PANEL_CORE_DATA}config/config.ini"
  database="trojan_panel_db"
  account_table="account"
  grpc_port=8100
  trojan_panel_core_port=8082

  # Versioned fork release. Docker selects the native platform from each manifest.
  IMAGE_RELEASE="2026.10.05-r1"
  TROJAN_PANEL_UI_IMAGE="ghcr.io/electronlsr/trojan-panel-ui:${IMAGE_RELEASE}@sha256:a4db5738e9898be6aa5828cf91271e0e3beb0dbeb85d864f726687e4e4e55916"
  TROJAN_PANEL_IMAGE="ghcr.io/electronlsr/trojan-panel:${IMAGE_RELEASE}@sha256:9385f95767d30e6f10959f4b22ca3d6ff53d6c7e593f3370cf5d54179420cd55"
  TROJAN_PANEL_CORE_IMAGE="ghcr.io/electronlsr/trojan-panel-core:${IMAGE_RELEASE}@sha256:4525353d529281a85a6cb14859cebb5ccc2da42a1fbc300ef4fcac101be29df8"

  # Upstream application schema versions (not release/update identifiers).
  trojan_panel_ui_current_version=""
  trojan_panel_ui_latest_version="v2.3.0"
  trojan_panel_current_version=""
  trojan_panel_latest_version="v2.3.1"
  trojan_panel_core_current_version=""
  trojan_panel_core_latest_version="v2.3.1"


}

echo_content() {
  case $1 in
  "red")
    ${ECHO_TYPE} "\033[31m$2\033[0m"
    ;;
  "green")
    ${ECHO_TYPE} "\033[32m$2\033[0m"
    ;;
  "yellow")
    ${ECHO_TYPE} "\033[33m$2\033[0m"
    ;;
  "blue")
    ${ECHO_TYPE} "\033[34m$2\033[0m"
    ;;
  "purple")
    ${ECHO_TYPE} "\033[35m$2\033[0m"
    ;;
  "skyBlue")
    ${ECHO_TYPE} "\033[36m$2\033[0m"
    ;;
  "white")
    ${ECHO_TYPE} "\033[37m$2\033[0m"
    ;;
  esac
}

mkdir_tools() {
  # Project directory
  mkdir -p ${TP_DATA}

  # Web
  mkdir -p ${WEB_PATH}

  # Cert
  mkdir -p ${CERT_PATH}
  touch ${DOMAIN_FILE}

  # Caddy2
  mkdir -p ${CADDY_DATA}
  touch ${CADDY_CONFIG}
  mkdir -p ${CADDY_LOG}

  # Nginx
  mkdir -p ${NGINX_DATA}
  touch ${NGINX_CONFIG}

  # MariaDB
  mkdir -p ${MARIA_DATA}

  # Redis
  mkdir -p ${REDIS_DATA}

  # Trojan Panel Frontend
  mkdir -p ${TROJAN_PANEL_UI_DATA}
  # Nginx
  mkdir -p ${UI_NGINX_DATA}
  touch ${UI_NGINX_CONFIG}

  # Trojan Panel Backend
  mkdir -p ${TROJAN_PANEL_DATA}
  mkdir -p ${TROJAN_PANEL_LOGS}

  # Trojan Panel Core
  mkdir -p ${TROJAN_PANEL_CORE_DATA}
  mkdir -p ${TROJAN_PANEL_CORE_LOGS}
}

can_connect() {
  ping -c2 -i0.3 -W1 "$1" &>/dev/null
  if [[ "$?" == "0" ]]; then
    return 0
  else
    return 1
  fi
}

# query .ini configuration file information
get_ini_value() {
  local config_file="$1"
  local key="$2"
  local section=""
  local section_flag=0

  # split group and key names
  IFS='.' read -r group_name key_name <<<"$key"

  while IFS='=' read -r name val; do
    # processing section name
    if [[ $name =~ ^\[(.*)\]$ ]]; then
      section="${BASH_REMATCH[1]}"
      if [[ $section == $group_name ]]; then
        section_flag=1
      else
        section_flag=0
      fi
      continue
    fi

    # extract the value of the configuration item
    if [[ $section_flag -eq 1 && $name == $key_name ]]; then
      echo "$val"
      return
    fi
  done <"$config_file"
}

# Version number comparison greater than or equal to
version_ge() {
  local v1=${1#v}
  local v2=${2#v}

  local v1_parts=(${v1//./ })
  local v2_parts=(${v2//./ })

  for ((i = 0; i < 3; i++)); do
    if ((${v1_parts[i]} < ${v2_parts[i]})); then
      echo false
      return 0
    elif ((${v1_parts[i]} > ${v2_parts[i]})); then
      echo true
      return 0
    fi
  done
  echo true
}

detect_arch() {
  get_arch=$(arch)
  case "${get_arch}" in
    x86_64|amd64) docker_platform="linux/amd64" ;;
    i386|i486|i586|i686) docker_platform="linux/386" ;;
    armv6l) docker_platform="linux/arm/v6" ;;
    armv7l|armv8l) docker_platform="linux/arm/v7" ;;
    aarch64|arm64) docker_platform="linux/arm64" ;;
    ppc64le) docker_platform="linux/ppc64le" ;;
    s390x) docker_platform="linux/s390x" ;;
    *) echo_content red "Unsupported architecture: ${get_arch}"; return 1 ;;
  esac
}

check_sys() {
  if [[ $(command -v yum) ]]; then
    package_manager='yum'
  elif [[ $(command -v dnf) ]]; then
    package_manager='dnf'
  elif [[ $(command -v apt) ]]; then
    package_manager='apt'
  elif [[ $(command -v apt-get) ]]; then
    package_manager='apt-get'
  fi

  if [[ -z "${package_manager}" ]]; then
    echo_content red "The system is not currently supported"
    exit 0
  fi

  if [[ -n $(find /etc -name "redhat-release") ]] || grep </proc/version -q -i "centos"; then
    release="centos"
  elif grep </etc/issue -q -i "debian" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "debian" && [[ -f "/proc/version" ]]; then
    release="debian"
  elif grep </etc/issue -q -i "ubuntu" && [[ -f "/etc/issue" ]] || grep </etc/issue -q -i "ubuntu" && [[ -f "/proc/version" ]]; then
    release="ubuntu"
  fi

  if [[ -z "${release}" ]]; then
    echo_content red "The operating system only supports CentOS 7+/Ubuntu 18+/Debian 10+"
    exit 0
  fi

  detect_arch || return 1

  can_connect www.google.com
  [[ "$?" == "0" ]] && can_google=1
  return 0
}

depend_install() {
  if [[ "${package_manager}" != 'yum' && "${package_manager}" != 'dnf' ]]; then
    ${package_manager} update -y
  fi
  ${package_manager} install -y \
    curl \
    wget \
    tar \
    lsof \
    systemd
}

# Install Docker
install_docker() {
  if [[ ! $(docker -v 2>/dev/null) ]]; then
    echo_content green "---> Install Docker"

    # turn off firewall
    if [[ "${release}" == "centos" ]]; then
      systemctl disable firewalld
    elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
      sudo ufw disable
    fi

    # set time zone
    timedatectl set-timezone Asia/Shanghai

    if [[ ${can_google} == 0 ]]; then
      sh <(curl -sL https://get.docker.com) --mirror Aliyun
      mkdir -p /etc/docker &&
        cat >/etc/docker/daemon.json <<EOF
{
  "registry-mirrors":[${DOCKER_MIRROR}],
  "log-driver":"json-file",
  "log-opts":{
      "max-size":"50m",
      "max-file":"3"
  }
}
EOF
    else
      sh <(curl -sL https://get.docker.com)
      mkdir -p /etc/docker &&
        cat >/etc/docker/daemon.json <<EOF
{
  "log-driver":"json-file",
  "log-opts":{
      "max-size":"50m",
      "max-file":"3"
  }
}
EOF
    fi

    systemctl enable docker &&
      systemctl restart docker

    if [[ $(docker -v 2>/dev/null) ]]; then
      echo_content skyBlue "---> Docker installation completed"
    else
      echo_content red "---> Docker installation failed"
      exit 0
    fi
  else
    echo_content skyBlue "---> You have installed Docker"
  fi
}

# Custom Settings Certificate
install_custom_cert() {
  if [[ -z "$(cat "${DOMAIN_FILE}")" ]]; then
    while read -r -p "Please enter the file path of the .crt certificate (required): " crt_path; do
      if [[ -z "${crt_path}" ]]; then
        echo_content red "Path cannot be empty"
      else
        if [[ ! -f "${crt_path}" ]]; then
          echo_content red "The file path for the .crt certificate does not exist"
        else
          cp "${crt_path}" "${CERT_PATH}$1.crt"
          break
        fi
      fi
    done
    while read -r -p "Please enter the file path of the .key certificate (required): " key_path; do
      if [[ -z "${key_path}" ]]; then
        echo_content red "Path cannot be empty"
      else
        if [[ ! -f "${key_path}" ]]; then
          echo_content red "The file path for the .key certificate does not exist"
        else
          cp "${key_path}" "${CERT_PATH}$1.key"
          break
        fi
      fi
    done
    cat >${DOMAIN_FILE} <<EOF
$1
EOF
    echo_content red "\n=============================================================="
    echo_content skyBlue "---> Custom settings certificate installation completed"
    echo_content yellow "Certificate Directory: ${CERT_PATH}"
    echo_content red "\n=============================================================="
  fi
}

# Caddy2 https custom settings certificate configuration file
caddy2_https_config() {
  domain=$1
  cat >${CADDY_CONFIG} <<EOF
{
    "admin":{
        "disabled":true
    },
    "logging":{
        "logs":{
            "default":{
                "writer":{
                    "output":"file",
                    "filename":"${CADDY_LOG}error.log"
                },
                "level":"ERROR"
            }
        }
    },
    "storage":{
        "module":"file_system",
        "root":"${CERT_PATH}"
    },
    "apps":{
        "http":{
            "http_port": ${caddy_port},
            "servers":{
                "srv0":{
                    "listen":[
                        ":${caddy_port}"
                    ],
                    "routes":[
                        {
                            "match":[
                                {
                                    "host":[
                                        "${domain}"
                                    ]
                                }
                            ],
                            "handle":[
                                {
                                    "handler":"static_response",
                                    "headers":{
                                        "Location":[
                                            "https://{http.request.host}:${caddy_remote_port}{http.request.uri}"
                                        ]
                                    },
                                    "status_code":301
                                }
                            ]
                        }
                    ]
                },
                "srv1":{
                    "listen":[
                        ":${caddy_remote_port}"
                    ],
                    "routes":[
                        {
                            "handle":[
                                {
                                    "handler":"subroute",
                                    "routes":[
                                        {
                                            "match":[
                                                {
                                                    "host":[
                                                        "${domain}"
                                                    ]
                                                }
                                            ],
                                            "handle":[
                                                {
                                                    "handler":"file_server",
                                                    "root":"${WEB_PATH}",
                                                    "index_names":[
                                                        "index.html",
                                                        "index.htm"
                                                    ]
                                                }
                                            ],
                                            "terminal":true
                                        }
                                    ]
                                }
                            ]
                        }
                    ],
                    "tls_connection_policies":[
                        {
                            "match":{
                                "sni":[
                                    "${domain}"
                                ]
                            }
                        }
                    ],
                    "automatic_https":{
                        "disable":true
                    }
                }
            }
        },
        "tls":{
            "certificates":{
                "automate":[
                    "${domain}"
                ],
                "load_files":[
                    {
                        "certificate":"${CADDY_CERT_DIR}${domain}/${domain}.crt",
                        "key":"${CADDY_CERT_DIR}${domain}/${domain}.key"
                    }
                ]
            },
            "automation":{
                "policies":[
                    {
                        "issuers":[
                            {
                                "module":"${ssl_module}",
                                "email":"${your_email}"
                            }
                        ]
                    }
                ]
            }
        }
    }
}
EOF
}

# Caddy2 https automatic application and renewal certificate configuration file
caddy2_https_auto_config() {
  domain=$1
  cat >${CADDY_CONFIG} <<EOF
{
    "admin":{
        "disabled":true
    },
    "logging":{
        "logs":{
            "default":{
                "writer":{
                    "output":"file",
                    "filename":"${CADDY_LOG}error.log"
                },
                "level":"ERROR"
            }
        }
    },
    "storage":{
        "module":"file_system",
        "root":"${CERT_PATH}"
    },
    "apps":{
        "http":{
            "http_port": ${caddy_port},
            "servers":{
                "srv0":{
                    "listen":[
                        ":${caddy_port}"
                    ],
                    "routes":[
                        {
                            "match":[
                                {
                                    "host":[
                                        "${domain}"
                                    ]
                                }
                            ],
                            "handle":[
                                {
                                    "handler":"static_response",
                                    "headers":{
                                        "Location":[
                                            "https://{http.request.host}:${caddy_remote_port}{http.request.uri}"
                                        ]
                                    },
                                    "status_code":301
                                }
                            ]
                        }
                    ]
                },
                "srv1":{
                    "listen":[
                        ":${caddy_remote_port}"
                    ],
                    "routes":[
                        {
                            "handle":[
                                {
                                    "handler":"subroute",
                                    "routes":[
                                        {
                                            "match":[
                                                {
                                                    "host":[
                                                        "${domain}"
                                                    ]
                                                }
                                            ],
                                            "handle":[
                                                {
                                                    "handler":"file_server",
                                                    "root":"${WEB_PATH}",
                                                    "index_names":[
                                                        "index.html",
                                                        "index.htm"
                                                    ]
                                                }
                                            ],
                                            "terminal":true
                                        }
                                    ]
                                }
                            ]
                        }
                    ],
                    "tls_connection_policies":[
                        {
                            "match":{
                                "sni":[
                                    "${domain}"
                                ]
                            }
                        }
                    ],
                    "automatic_https":{
                        "disable":true
                    }
                }
            }
        },
        "tls":{
            "certificates":{
                "automate":[
                    "${domain}"
                ]
            },
            "automation":{
                "policies":[
                    {
                        "issuers":[
                            {
                                "module":"${ssl_module}",
                                "email":"${your_email}"
                            }
                        ]
                    }
                ]
            }
        }
    }
}
EOF
}

# Install Caddy2
install_caddy2() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
    echo_content green "---> Install Caddy2+https"

    wget --no-check-certificate -O ${WEB_PATH}html.tar.gz -N ${STATIC_HTML} &&
      tar -zxvf ${WEB_PATH}html.tar.gz -k -C ${WEB_PATH}

    read -r -p "Please enter the port of Caddy2 (default: 80): " caddy_port
    [[ -z "${caddy_port}" ]] && caddy_port=80
    read -r -p "Please enter the forwarding port of Caddy2 (default: 8863): " caddy_remote_port
    [[ -z "${caddy_remote_port}" ]] && caddy_remote_port=8863

    echo_content yellow "Tip: Please confirm that the domain name has been resolved to this machine, otherwise the installation may fail"
    while read -r -p "Please enter your domain name (required): " domain; do
      if [[ -z "${domain}" ]]; then
        echo_content red "Domain name cannot be empty"
      else
        break
      fi
    done

    read -r -p "Please enter your email (optional): " your_email

    while read -r -p "Please choose the way to set up the certificate? (1/automatically apply for and renew the certificate 2/manually set the certificate path default: 1: " ssl_option; do
      if [[ -z ${ssl_option} || ${ssl_option} == 1 ]]; then
        while read -r -p "Please choose the way to apply for the certificate (1/acme 2/zerossl default: 1: " ssl_module_type; do
          if [[ -z "${ssl_module_type}" || ${ssl_module_type} == 1 ]]; then
            ssl_module="acme"
            CADDY_CERT_DIR="${CERT_PATH}certificates/acme-v02.api.letsencrypt.org-directory/"
            break
          elif [[ ${ssl_module_type} == 2 ]]; then
            ssl_module="zerossl"
            CADDY_CERT_DIR="${CERT_PATH}certificates/acme.zerossl.com-v2-dv90/"
            break
          else
            echo_content red "Cannot enter other characters except 1 and 2"
          fi
        done
        caddy2_https_auto_config "${domain}"
        break
      elif [[ ${ssl_option} == 2 ]]; then
        install_custom_cert "${domain}"
        caddy2_https_config "${domain}"
        break
      else
        echo_content red "Cannot enter other characters except 1 and 2"
      fi
    done

    # Caddy2 temporary listening port for automatic certificate application
    if [[ -n $(lsof -i:${caddy_port},${caddy_remote_port} -t) ]]; then
      kill -9 "$(lsof -i:${caddy_port},${caddy_remote_port} -t)"
    fi

    docker pull caddy:2.6.2 &&
      docker run -d --name trojan-panel-caddy --restart always \
        --network=host \
        -v "${CADDY_CONFIG}":"${CADDY_CONFIG}" \
        -v ${CERT_PATH}:"${CADDY_CERT_DIR}${domain}/" \
        -v ${WEB_PATH}:${WEB_PATH} \
        -v ${CADDY_LOG}:${CADDY_LOG} \
        caddy:2.6.2 caddy run --config ${CADDY_CONFIG}

    cat >${DOMAIN_FILE} <<EOF
${domain}
EOF

    if [[ -n $(docker ps -q -f "name=^trojan-panel-caddy$" -f "status=running") ]]; then
      echo_content red "\n=============================================================="
      echo_content skyBlue "---> Caddy2+https installation completed"
      echo_content yellow "Certificate Directory: ${CERT_PATH}"
      echo_content red "\n=============================================================="
    else
      echo_content red "---> Caddy2+https installation fails or runs abnormally, please try to repair or uninstall and reinstall"
      exit 0
    fi
  else
    echo_content skyBlue "---> You have installed Caddy2+https"
  fi
}

# Nginx http configuration file
nginx_http_config() {
  cat >${NGINX_CONFIG} <<-EOF
server {
    listen       ${nginx_port};
    server_name  localhost;

    location / {
        root   ${WEB_PATH};
        index  index.html index.htm;
    }

    error_page  497               http://\$host:${nginx_port}\$request_uri;

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF
}

# Nginx https configuration file
nginx_https_config() {
  domain=$1
  cat >${NGINX_CONFIG} <<-EOF
server {
    listen ${nginx_port};
    server_name localhost;

    return 301 http://\$host:${nginx_remote_port}\$request_uri;
}

server {
    listen       ${nginx_remote_port} ssl;
    server_name  localhost;

    # force ssl
    ssl on;
    ssl_certificate      ${CERT_PATH}${domain}.crt;
    ssl_certificate_key  ${CERT_PATH}${domain}.key;
    # cache validity period
    ssl_session_timeout  5m;
    # secure link optional encryption protocol
    ssl_protocols  TLSv1.3;
    # encryption algorithm
    ssl_ciphers  ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
    # use server-side preferred algorithm
    ssl_prefer_server_ciphers  on;

    #access_log  /var/log/nginx/host.access.log  main;

    location / {
        root   ${WEB_PATH};
        index  index.html index.htm;
    }

    #error_page  404              /404.html;
    #497 http->https
    error_page  497               https://\$host:${nginx_remote_port}\$request_uri;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF
}

# Install Nginx
install_nginx() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-nginx$") ]]; then
    echo_content green "---> Install Nginx"

    wget --no-check-certificate -O ${WEB_PATH}html.tar.gz -N ${STATIC_HTML} &&
      tar -zxvf ${WEB_PATH}html.tar.gz -k -C ${WEB_PATH}

    read -r -p "Please enter the port of Nginx (default: 80): " nginx_port
    [[ -z "${nginx_port}" ]] && nginx_port=80
    read -r -p "Please enter the forwarding port of Nginx (default: 8863): " nginx_remote_port
    [[ -z "${nginx_remote_port}" ]] && nginx_remote_port=8863

    while read -r -p "Please choose whether to enable https in Nginx? (0/off 1/on default: 1): " nginx_https; do
      if [[ -z ${nginx_https} || ${nginx_https} == 1 ]]; then
        install_custom_cert "custom_cert"
        nginx_https_config "custom_cert"
        break
      elif [[ ${nginx_https} == 0 ]]; then
        nginx_http_config
        break
      else
        echo_content red "Cannot enter other characters except 1 and 2"
      fi
    done

    docker pull nginx:1.20-alpine &&
      docker run -d --name trojan-panel-nginx --restart always \
        --network=host \
        -v "${NGINX_CONFIG}":"/etc/nginx/conf.d/default.conf" \
        -v ${CERT_PATH}:${CERT_PATH} \
        -v ${WEB_PATH}:${WEB_PATH} \
        nginx:1.20-alpine

    if [[ -n $(docker ps -q -f "name=^trojan-panel-nginx$" -f "status=running") ]]; then
      echo_content skyBlue "---> Nginx installation completed"
    else
      echo_content red "---> Nginx installation fails or runs abnormally, please try to repair or uninstall and reinstall"
      exit 0
    fi
  else
    echo_content skyBlue "---> You have installed Nginx"
  fi
}

# Install a web server
install_reverse_proxy() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-caddy$|^trojan-panel-nginx$") ]]; then
    echo_content green "---> Install a web server"

    while :; do
      echo_content yellow "1. Install Caddy2+https (recommend)"
      echo_content yellow "2. Install Nginx"
      echo_content yellow "3. Not install"
      read -r -p "Please select (default: 1): " whether_install_reverse_proxy
      [[ -z "${whether_install_reverse_proxy}" ]] && whether_install_reverse_proxy=1

      case ${whether_install_reverse_proxy} in
      1)
        install_caddy2
        break
        ;;
      2)
        install_nginx
        break
        ;;
      3)
        break
        ;;
      *)
        echo_content red "No such option"
        continue
        ;;
      esac
    done

    echo_content skyBlue "---> Web server installation completed"
  fi
}

# Set certificate
install_cert() {
  if [[ -z "$(cat "${DOMAIN_FILE}")" ]]; then
    echo_content green "---> Set certificate"

    while :; do
      echo_content yellow "1. Custom certificate"
      echo_content yellow "2. Not set"
      read -r -p "Please select (default: 1): " whether_install_cert
      [[ -z "${whether_install_cert}" ]] && whether_install_cert=1

      case ${whether_install_cert} in
      1)
        install_custom_cert "custom_cert"
        break
        ;;
      2)
        break
        ;;
      *)
        echo_content red "No such option"
        continue
        ;;
      esac
    done

    echo_content green "---> Certificate setup completed"
  fi
}

# Install MariaDB
install_mariadb() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-mariadb$") ]]; then
    echo_content green "---> Install MariaDB"

    read -r -p "Please enter the port of MariaDB (default: 9507): " mariadb_port
    [[ -z "${mariadb_port}" ]] && mariadb_port=9507
    read -r -p "Please enter the username of MariaDB (default: root): " mariadb_user
    [[ -z "${mariadb_user}" ]] && mariadb_user="root"
    while read -r -p "Please enter the password of MariaDB (required): " mariadb_pas; do
      if [[ -z "${mariadb_pas}" ]]; then
        echo_content red "Password can not be empty"
      else
        break
      fi
    done

    if [[ "${mariadb_user}" == "root" ]]; then
      docker pull mariadb:10.7.3 &&
        docker run -d --name trojan-panel-mariadb --restart always \
          --network=host \
          -e MYSQL_DATABASE="trojan_panel_db" \
          -e MYSQL_ROOT_PASSWORD="${mariadb_pas}" \
          -e TZ=Asia/Shanghai \
          mariadb:10.7.3 \
          --port ${mariadb_port} \
          --character-set-server=utf8mb4 \
          --collation-server=utf8mb4_unicode_ci
    else
      docker pull mariadb:10.7.3 &&
        docker run -d --name trojan-panel-mariadb --restart always \
          --network=host \
          -e MYSQL_DATABASE="trojan_panel_db" \
          -e MYSQL_ROOT_PASSWORD="${mariadb_pas}" \
          -e MYSQL_USER="${mariadb_user}" \
          -e MYSQL_PASSWORD="${mariadb_pas}" \
          -e TZ=Asia/Shanghai \
          mariadb:10.7.3 \
          --port ${mariadb_port} \
          --character-set-server=utf8mb4 \
          --collation-server=utf8mb4_unicode_ci
    fi

    if [[ -n $(docker ps -q -f "name=^trojan-panel-mariadb$" -f "status=running") ]]; then
      echo_content skyBlue "---> MariaDB installation completed"
      echo_content yellow "---> The MariaDB password of root (please keep it safe): ${mariadb_pas}"
      if [[ "${mariadb_user}" != "root" ]]; then
        echo_content yellow "---> The MariaDB password of ${mariadb_user} (please keep it safe): ${mariadb_pas}"
      fi
    else
      echo_content red "---> MariaDB installation fails or runs abnormally, please try to repair or uninstall and reinstall"
      exit 0
    fi
  else
    echo_content skyBlue "---> You have installed MariaDB"
  fi
}

# Install Redis
install_redis() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-redis$") ]]; then
    echo_content green "---> Install Redis"

    read -r -p "Please enter the port of Redis (default: 6378): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6378
    while read -r -p "Please enter the Redis password (required): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "Password can not be empty"
      else
        break
      fi
    done

    docker pull redis:6.2.7 &&
      docker run -d --name trojan-panel-redis --restart always \
        --network=host \
        redis:6.2.7 \
        redis-server --requirepass "${redis_pass}" --port "${redis_port}"

    if [[ -n $(docker ps -q -f "name=^trojan-panel-redis$" -f "status=running") ]]; then
      echo_content skyBlue "---> Redis installation completed"
      echo_content yellow "---> Redis password (please keep it safe): ${redis_pass}"
    else
      echo_content red "---> Redis installation fails or runs abnormally, please try to repair or uninstall and reinstall"
      exit 0
    fi
  else
    echo_content skyBlue "---> You have installed Redis"
  fi
}

# Trojan Panel Frontend Nginx http configuration file
ui_http_config() {
  cat >${UI_NGINX_CONFIG} <<-EOF
server {
    listen       ${trojan_panel_ui_port};
    server_name  localhost;

    location / {
        root   ${TROJAN_PANEL_UI_DATA};
        index  index.html index.htm;
    }

    location /api {
        proxy_pass http://${trojan_panel_ip}:${trojan_panel_server_port};
    }

    error_page  497               http://\$host:${trojan_panel_ui_port}\$request_uri;

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF
}

# Trojan Panel Frontend Nginx https configuration file
ui_https_config() {
  cat >${UI_NGINX_CONFIG} <<-EOF
server {
    listen       ${trojan_panel_ui_port} ssl;
    server_name  localhost;

    # force ssl
    ssl on;
    ssl_certificate      ${CERT_PATH}${domain}.crt;
    ssl_certificate_key  ${CERT_PATH}${domain}.key;
    # cache validity period
    ssl_session_timeout  5m;
    # secure link optional encryption protocol
    ssl_protocols  TLSv1.3;
    # encryption algorithm
    ssl_ciphers  ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
    # use server-side preferred algorithm
    ssl_prefer_server_ciphers  on;

    #access_log  /var/log/nginx/host.access.log  main;

    location / {
        root   ${TROJAN_PANEL_UI_DATA};
        index  index.html index.htm;
    }

    location /api {
        proxy_pass http://${trojan_panel_ip}:${trojan_panel_server_port};
    }

    #error_page  404              /404.html;
    #497 http->https
    error_page  497               https://\$host:${trojan_panel_ui_port}\$request_uri;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF
}

# Install Trojan Panel Frontend
install_trojan_panel_ui() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-ui$") ]]; then
    echo_content green "---> Install Trojan Panel Frontend"

    read -r -p "Please enter the IP address of the Trojan Panel Backend (default: local host): " trojan_panel_ip
    [[ -z "${trojan_panel_ip}" ]] && trojan_panel_ip="127.0.0.1"
    read -r -p "Please enter the service port of the Trojan Panel Backend (default: 8081): " trojan_panel_server_port
    [[ -z "${trojan_panel_server_port}" ]] && trojan_panel_server_port=8081

    read -r -p "Please enter the port of the Trojan Panel Frontend (default: 8888): " trojan_panel_ui_port
    [[ -z "${trojan_panel_ui_port}" ]] && trojan_panel_ui_port="8888"
    while read -r -p "Please choose whether to enable https on the Trojan Panel Frontend? (0/off 1/on default: 1): " ui_https; do
      if [[ -z ${ui_https} || ${ui_https} == 1 ]]; then
        install_custom_cert "custom_cert"
        domain=$(cat "${DOMAIN_FILE}")
        ui_https_config
        break
      elif [[ ${ui_https} == 0 ]]; then
        ui_http_config
        break
      else
        echo_content red "Cannot enter other characters except 1 and 2"
      fi
    done

    docker pull "${TROJAN_PANEL_UI_IMAGE}" &&
      docker run -d --name trojan-panel-ui --restart always \
        --network=host \
        -v "${UI_NGINX_CONFIG}":"/etc/nginx/conf.d/default.conf" \
        -v ${CERT_PATH}:${CERT_PATH} \
        "${TROJAN_PANEL_UI_IMAGE}"

    if [[ -n $(docker ps -q -f "name=^trojan-panel-ui$" -f "status=running") ]]; then
      echo_content skyBlue "---> Trojan Panel Frontend installation completed"

      https_flag=$([[ -z ${ui_https} || ${ui_https} == 1 ]] && echo "https" || echo "http")
      domain_or_ip=$([[ -z ${domain} || "${domain}" == "custom_cert" ]] && echo "ip" || echo "${domain}")

      echo_content red "\n=============================================================="
      echo_content skyBlue "Trojan Panel Frontend installed successfully"
      echo_content yellow "Web management panel address: ${https_flag}://${domain_or_ip}:${trojan_panel_ui_port}"
      echo_content red "\n=============================================================="
    else
      echo_content red "---> Trojan Panel Frontend installation fails or runs abnormally, inspect logs and fix the issue without deleting data"
      return 1
    fi
  else
    echo_content skyBlue "---> You have installed the Trojan Panel Frontend"
  fi
}

# Install Trojan Panel Backend
install_trojan_panel() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel$") ]]; then
    echo_content green "---> Install Trojan Panel Backend"

    read -r -p "Please enter the service port of the Trojan Panel Backend (default: 8081): " trojan_panel_port
    [[ -z "${trojan_panel_port}" ]] && trojan_panel_port=8081

    read -r -p "Please enter the IP address of MariaDB (default: local host): " mariadb_ip
    [[ -z "${mariadb_ip}" ]] && mariadb_ip="127.0.0.1"
    read -r -p "Please enter the port of MariaDB (default: 9507): " mariadb_port
    [[ -z "${mariadb_port}" ]] && mariadb_port=9507
    read -r -p "Please enter the username of MariaDB (default: root): " mariadb_user
    [[ -z "${mariadb_user}" ]] && mariadb_user="root"
    while read -r -p "Please enter the password of MariaDB (required): " mariadb_pas; do
      if [[ -z "${mariadb_pas}" ]]; then
        echo_content red "Password can not be empty"
      else
        break
      fi
    done

    docker exec trojan-panel-mariadb mysql --default-character-set=utf8 -h"${mariadb_ip}" -P"${mariadb_port}" -u"${mariadb_user}" -p"${mariadb_pas}" -e "create database if not exists trojan_panel_db;" &>/dev/null

    read -r -p "Please enter the IP address of Redis (default: local host): " redis_host
    [[ -z "${redis_host}" ]] && redis_host="127.0.0.1"
    read -r -p "Please enter the port of Redis (default: 6378): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6378
    while read -r -p "Please enter the Redis password (required): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "Password can not be empty"
      else
        break
      fi
    done

    docker pull "${TROJAN_PANEL_IMAGE}" &&
      docker run -d --name trojan-panel --restart always \
        --network=host \
        -v ${WEB_PATH}:${TROJAN_PANEL_WEBFILE} \
        -v ${TROJAN_PANEL_LOGS}:${TROJAN_PANEL_LOGS} \
        -v ${TROJAN_PANEL_CONFIG}:${TROJAN_PANEL_CONFIG} \
        -v /etc/localtime:/etc/localtime \
        -e GIN_MODE=release \
        -e "mariadb_ip=${mariadb_ip}" \
        -e "mariadb_port=${mariadb_port}" \
        -e "mariadb_user=${mariadb_user}" \
        -e "mariadb_pas=${mariadb_pas}" \
        -e "redis_host=${redis_host}" \
        -e "redis_port=${redis_port}" \
        -e "redis_pass=${redis_pass}" \
        -e "server_port=${trojan_panel_port}" \
        "${TROJAN_PANEL_IMAGE}"

    if [[ -n $(docker ps -q -f "name=^trojan-panel$" -f "status=running") ]]; then
      echo_content skyBlue "---> Trojan Panel Backend installation completed"

      echo_content red "\n=============================================================="
      echo_content skyBlue "Trojan Panel Backend installed successfully"
      echo_content yellow "MariaDB ${mariadb_user} password (please keep it safe): ${mariadb_pas}"
      echo_content yellow "Redis password (please keep it safe): ${redis_pass}"
      echo_content yellow "System administrator Default username: sysadmin Default password: 123456"
      echo_content yellow "Please log in to the management panel to change the password in time"
      echo_content red "\n=============================================================="
    else
      echo_content red "---> Trojan Panel Backend installation fails or runs abnormally, inspect logs and fix the issue without deleting data"
      return 1
    fi
  else
    echo_content skyBlue "---> You have installed the Trojan Panel Backend"
  fi
}

# Install Trojan Panel Core
install_trojan_panel_core() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-core$") ]]; then
    echo_content green "---> Install Trojan Panel Core"

    read -r -p "Please enter the service port of the Trojan Panel Core (default: 8082): " trojan_panel_core_port
    [[ -z "${trojan_panel_core_port}" ]] && trojan_panel_core_port=8082

    read -r -p "Please enter the IP address of MariaDB (default: local host): " mariadb_ip
    [[ -z "${mariadb_ip}" ]] && mariadb_ip="127.0.0.1"
    read -r -p "Please enter the port of MariaDB (default: 9507): " mariadb_port
    [[ -z "${mariadb_port}" ]] && mariadb_port=9507
    read -r -p "Please enter the username of MariaDB (default: root): " mariadb_user
    [[ -z "${mariadb_user}" ]] && mariadb_user="root"
    while read -r -p "Please enter the password of MariaDB (required): " mariadb_pas; do
      if [[ -z "${mariadb_pas}" ]]; then
        echo_content red "Password can not be empty"
      else
        break
      fi
    done
    read -r -p "Please enter the database name (default: trojan_panel_db): " database
    [[ -z "${database}" ]] && database="trojan_panel_db"
    read -r -p "Please enter the user table name of the database (default: account): " account_table
    [[ -z "${account_table}" ]] && account_table="account"

    read -r -p "Please enter the IP address of Redis (default: local host): " redis_host
    [[ -z "${redis_host}" ]] && redis_host="127.0.0.1"
    read -r -p "Please enter the port of Redis (default: 6378): " redis_port
    [[ -z "${redis_port}" ]] && redis_port=6378
    while read -r -p "Please enter the Redis password (required): " redis_pass; do
      if [[ -z "${redis_pass}" ]]; then
        echo_content red "Password can not be empty"
      else
        break
      fi
    done
    read -r -p "Please enter the API port (default: 8100): " grpc_port
    [[ -z "${grpc_port}" ]] && grpc_port=8100

    domain=$(cat "${DOMAIN_FILE}")

    docker pull "${TROJAN_PANEL_CORE_IMAGE}" &&
      docker run -d --name trojan-panel-core --restart always \
        --network=host \
        -v ${TROJAN_PANEL_CORE_DATA}bin/xray/config/:${TROJAN_PANEL_CORE_DATA}bin/xray/config/ \
        -v ${TROJAN_PANEL_CORE_DATA}bin/trojango/config/:${TROJAN_PANEL_CORE_DATA}bin/trojango/config/ \
        -v ${TROJAN_PANEL_CORE_DATA}bin/hysteria/config/:${TROJAN_PANEL_CORE_DATA}bin/hysteria/config/ \
        -v ${TROJAN_PANEL_CORE_DATA}bin/naiveproxy/config/:${TROJAN_PANEL_CORE_DATA}bin/naiveproxy/config/ \
        -v ${TROJAN_PANEL_CORE_DATA}bin/hysteria2/config/:${TROJAN_PANEL_CORE_DATA}bin/hysteria2/config/ \
        -v ${TROJAN_PANEL_CORE_LOGS}:${TROJAN_PANEL_CORE_LOGS} \
        -v ${TROJAN_PANEL_CORE_CONFIG}:${TROJAN_PANEL_CORE_CONFIG} \
        -v ${CERT_PATH}:${CERT_PATH} \
        -v ${WEB_PATH}:${WEB_PATH} \
        -v /etc/localtime:/etc/localtime \
        -e GIN_MODE=release \
        -e "mariadb_ip=${mariadb_ip}" \
        -e "mariadb_port=${mariadb_port}" \
        -e "mariadb_user=${mariadb_user}" \
        -e "mariadb_pas=${mariadb_pas}" \
        -e "database=${database}" \
        -e "account_table=${account_table}" \
        -e "redis_host=${redis_host}" \
        -e "redis_port=${redis_port}" \
        -e "redis_pass=${redis_pass}" \
        -e "crt_path=${CERT_PATH}${domain}.crt" \
        -e "key_path=${CERT_PATH}${domain}.key" \
        -e "grpc_port=${grpc_port}" \
        -e "server_port=${trojan_panel_core_port}" \
        "${TROJAN_PANEL_CORE_IMAGE}"
    if [[ -n $(docker ps -q -f "name=^trojan-panel-core$" -f "status=running") ]]; then
      echo_content skyBlue "---> Trojan Panel Core installation completed"
    else
      echo_content red "---> Trojan Panel Core installation fails or runs abnormally, inspect logs and fix the issue without deleting data"
      return 1
    fi
  else
    echo_content skyBlue "---> You have installed the Trojan Panel Core"
  fi
}

# Upgrade preserves inspected mounts, environment, names and runtime options.
# The Python helper is embedded so the one-click script needs no second download.
safe_upgrade() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo_content red "Python 3.6+ is required for backup and safe upgrade. Install python3, then rerun this menu. Nothing was changed."
    return 1
  fi
  if ! command -v docker >/dev/null 2>&1; then
    echo_content red "Docker is not installed. This option only upgrades existing containers."
    return 1
  fi
  echo_content yellow "Existing install: images will be pulled before a brief interruption. Config/data and credentials are preserved."
  echo_content yellow "Backups go to /var/backups/trojan-panel (contains secrets). Keep an off-server snapshot too."
  echo_content yellow "Node-only upgrade: back up the central MySQL database on the backend server first."
  echo_content yellow "No Redis flush or SQL migration is performed. Container rollback does not undo database/configuration writes."
  local confirm
  read -r -p "Continue with safe upgrade? [y/N]: " confirm
  [[ "${confirm}" == "y" || "${confirm}" == "Y" ]] || return 0
# BEGIN EMBEDDED SAFE UPGRADE
  python3 - "$@" <<'TP_SAFE_UPGRADE_PY'
#!/usr/bin/env python3
"""Non-destructive upgrade of existing upstream Trojan Panel Docker containers.

Embedded verbatim in install_script.sh by scripts/embed_upgrade.py. No dependencies
beyond Python 3.6+, Docker CLI and tar. Never run this on a production host in tests.
"""
import configparser
import copy
import datetime
import fcntl
import http.client
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import time
import urllib.parse


def log(message, **kwargs):
    try:
        print(message, **kwargs)
    except OSError:
        pass  # A closed terminal must never interrupt container recovery.


class UpgradeError(Exception):
    pass


def run(args, **kwargs):
    try:
        result = subprocess.run(args, stdout=kwargs.pop("stdout", subprocess.PIPE),
                                stderr=subprocess.PIPE, **kwargs)
    except OSError as error:
        raise UpgradeError("{} could not run: {}".format(args[0], error))
    if result.returncode:
        # Do not echo command arguments: Docker exec may contain database secrets.
        raise UpgradeError("{} failed: {}".format(args[0], result.stderr.decode(errors="replace").strip()))
    return result.stdout.decode().strip() if result.stdout is not None else ""


def docker(*args):
    return run(["docker"] + list(args))


def inspect(name, kind="container"):
    return json.loads(docker(kind, "inspect", name))[0]


class UnixHTTPConnection(http.client.HTTPConnection):
    def __init__(self, path):
        super().__init__("localhost", timeout=90)
        self.path = path

    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect(self.path)


class Engine:
    def __init__(self):
        host = os.environ.get("DOCKER_HOST")
        if not host or os.environ.get("DOCKER_CONTEXT"):
            host = docker("context", "inspect", "--format", "{{.Endpoints.docker.Host}}")
        if not host.startswith("unix://"):
            raise UpgradeError("Upgrade requires the local Docker Unix socket; remote contexts are not supported.")
        self.socket = host[7:]
        self.prefix = ""
        self.prefix = "/v" + self.request("GET", "/version")["ApiVersion"]

    def request(self, method, path, body=None, missing_ok=False):
        connection = UnixHTTPConnection(self.socket)
        payload = json.dumps(body).encode() if body is not None else None
        try:
            connection.request(method, self.prefix + path, payload, {"Content-Type": "application/json"})
            response = connection.getresponse()
            data = response.read()
            if response.status == 404 and missing_ok:
                return None
            if response.status >= 300:
                # Server error may repeat config values, so avoid printing raw request data.
                raise UpgradeError("Docker API {} {} failed (HTTP {}).".format(method, path, response.status))
            return json.loads(data) if data else {}
        except (OSError, http.client.HTTPException, ValueError) as error:
            raise UpgradeError("Docker API connection/response failed: " + str(error))
        finally:
            connection.close()

    def inspect_optional(self, name):
        return self.request("GET", "/containers/" + urllib.parse.quote(name, safe="") + "/json", missing_ok=True)

    def create(self, name, payload):
        path = "/containers/create?name=" + urllib.parse.quote(name, safe="")
        return self.request("POST", path, payload)["Id"]


def create_payload(container, old_image, new_image, target):
    """Preserve user settings, while allowing changed image startup defaults."""
    config = copy.deepcopy(container["Config"])
    old_defaults = old_image.get("Config", {})
    new_defaults = new_image.get("Config", {})
    for field in ("Entrypoint", "Cmd", "WorkingDir", "User", "Healthcheck", "StopSignal", "Shell"):
        if config.get(field) == old_defaults.get(field):
            if field in new_defaults:
                config[field] = copy.deepcopy(new_defaults[field])
            else:
                config.pop(field, None)
    config["Image"] = target
    old_env = config.get("Env") or []
    keys = {item.split("=", 1)[0] for item in old_env}
    config["Env"] = old_env + [item for item in new_defaults.get("Env", []) if item.split("=", 1)[0] not in keys]
    if config.get("Hostname") == container["Id"][:12]:
        config.pop("Hostname", None)
    labels = copy.deepcopy(config.get("Labels") or {})
    for key, value in (new_defaults.get("Labels") or {}).items():
        if key.startswith("org.opencontainers.image."):
            labels[key] = value
    config["Labels"] = labels
    host = copy.deepcopy(container["HostConfig"])
    if host.get("AutoRemove"):
        raise UpgradeError("AutoRemove containers are not supported; no containers were changed.")
    # Preserve anonymous volumes from both legacy -v and modern --mount syntax.
    volumes = {item["Destination"]: item for item in container.get("Mounts", []) if item["Type"] == "volume"}
    for mount in host.get("Mounts") or []:
        if mount.get("Type") == "volume" and not mount.get("Source"):
            prior = volumes.get(mount["Target"])
            if not prior:
                raise UpgradeError("Cannot resolve anonymous volume: " + mount["Target"])
            mount["Source"] = prior["Name"]
    if host.get("Binds"):
        binds = []
        for item in host["Binds"]:
            parts = item.split(":")
            if parts[0] in volumes and (len(parts) == 1 or (len(parts) == 2 and not parts[1].startswith("/"))):
                mode = parts[1] if len(parts) == 2 else ("rw" if volumes[parts[0]]["RW"] else "ro")
                item = "{}:{}:{}".format(volumes[parts[0]]["Name"], parts[0], mode)
            binds.append(item)
        host["Binds"] = binds
    destinations = {item.split(":")[1] for item in host.get("Binds") or [] if ":" in item}
    destinations.update(item.get("Target") for item in host.get("Mounts") or [])
    for mount in container.get("Mounts", []):
        if mount["Type"] == "volume" and mount["Destination"] not in destinations:
            host.setdefault("Binds", [])
            if host["Binds"] is None:
                host["Binds"] = []
            host["Binds"].append("{}:{}:{}".format(mount["Name"], mount["Destination"], "rw" if mount["RW"] else "ro"))
    config["HostConfig"] = host
    if host.get("NetworkMode") not in ("host", "none"):
        endpoints = {}
        for name, endpoint in container.get("NetworkSettings", {}).get("Networks", {}).items():
            endpoints[name] = {key: copy.deepcopy(endpoint[key]) for key in ("IPAMConfig", "Links", "Aliases", "DriverOpts") if endpoint.get(key)}
        if endpoints:
            config["NetworkingConfig"] = {"EndpointsConfig": endpoints}
    return config


def mounted_source(container, filename):
    # Nested mounts override parents; an exact file bind overrides its directory.
    mounts = sorted(container.get("Mounts", []), key=lambda mount: len(mount["Destination"].rstrip("/")), reverse=True)
    for mount in mounts:
        destination = mount["Destination"].rstrip("/")
        if filename == destination or filename.startswith(destination + "/"):
            if mount["Type"] not in ("bind", "volume") or not mount.get("Source"):
                raise UpgradeError("{} is covered by a non-persistent mount; manual migration is required.".format(filename))
            if filename == destination:
                return Path(mount["Source"])
            return Path(mount["Source"]) / filename[len(destination):].lstrip("/")
    raise UpgradeError("{} does not persist {} in a mount; manual migration is required.".format(container["Name"], filename))


def working_directory(container):
    return (container.get("Config", {}).get("WorkingDir") or "/tpdata/" + container["Name"].lstrip("/")).rstrip("/")


def config_source(container):
    return mounted_source(container, working_directory(container) + "/config/config.ini")


def backup_database(container, backup):
    config = configparser.ConfigParser(interpolation=None, inline_comment_prefixes=None)
    if not config.read(str(config_source(container))):
        raise UpgradeError("Cannot read the backend config.ini for a database backup.")
    try:
        connection = config["mysql"]
        env = dict(os.environ, MYSQL_PWD=connection["password"])
        args = ["--protocol=TCP", "--host=" + connection["host"], "--port=" + connection["port"],
                "--user=" + connection["user"], "--single-transaction", "--quick",
                "--routines", "--events", "--triggers", "--hex-blob", "--databases", "trojan_panel_db"]
    except KeyError:
        raise UpgradeError("Incomplete mysql settings in config.ini; database backup is required.")
    client = shutil.which("mariadb-dump") or shutil.which("mysqldump")
    if client:
        command = [client] + args
    else:
        # Use the already-installed database container; do not change its version/data.
        try:
            db = inspect("trojan-panel-mariadb")
        except UpgradeError:
            raise UpgradeError("Database backup requires a running trojan-panel-mariadb container or a local mariadb-dump/mysqldump client. No containers changed.")
        if not db["State"]["Running"] or db["HostConfig"].get("NetworkMode") != "host":
            raise UpgradeError("Install a local mariadb-dump client for this database topology; no containers changed.")
        command = ["docker", "exec", "-e", "MYSQL_PWD", "trojan-panel-mariadb", "mysqldump"] + args
    filename = backup / "trojan_panel_db.sql"
    with filename.open("wb") as output:
        run(command, stdout=output, env=env)
    if filename.stat().st_size == 0:
        raise UpgradeError("Database dump was empty; no containers changed.")


def backup_mounts(containers, backup):
    sources = set()
    for container in containers:
        for mount in container.get("Mounts", []):
            if mount["Type"] in ("bind", "volume") and mount["Source"] != "/etc/localtime":
                path = os.path.abspath(mount["Source"])
                if not os.path.exists(path):
                    raise UpgradeError("Missing mount source: " + path)
                if path == "/" or os.path.commonpath([str(backup), path]) == path:
                    raise UpgradeError("Backup path must not be inside a container mount: " + path)
                sources.add(path)
                # A bind source itself can be a symlink. Archive both the link
                # and its target; tar otherwise saves only the link, not the data.
                if os.path.islink(path):
                    resolved = os.path.realpath(path)
                    if resolved == "/" or os.path.commonpath([str(backup), resolved]) == resolved:
                        raise UpgradeError("Unsafe backup location relative to symlinked mount: " + path)
                    sources.add(resolved)
    # Remove nested duplicates. GNU tar preserves ownership, modes, ACLs and xattrs.
    roots = [path for path in sorted(sources) if not any(path.startswith(parent + "/") for parent in sources if parent != path)]
    if roots:
        run(["tar", "--acls", "--xattrs", "--numeric-owner", "-czpf", str(backup / "mounted-data.tar.gz"),
             "-C", "/", "--"] + [path.lstrip("/") for path in roots])


def restart_value(container):
    policy = container["HostConfig"].get("RestartPolicy") or {}
    value = policy.get("Name") or "no"
    if value == "on-failure" and policy.get("MaximumRetryCount"):
        value += ":" + str(policy["MaximumRetryCount"])
    return value


def wait_running(name, timeout=45):
    deadline = time.monotonic() + timeout
    stable = 0
    while time.monotonic() < deadline:
        current = inspect(name)
        state = current["State"]
        if not state.get("Running") or state.get("Restarting") or current.get("RestartCount", 0):
            raise UpgradeError(name + " stopped or restarted during startup.")
        health = state.get("Health", {}).get("Status")
        if health == "unhealthy":
            raise UpgradeError(name + " failed its image health check.")
        stable = stable + 1 if health in (None, "healthy") else 0
        if stable >= 5:
            return
        time.sleep(2)
    raise UpgradeError(name + " did not become ready before timeout.")


def check_version(name):
    if name == "trojan-panel-ui":
        version = docker("exec", name, "cat", "/tpdata/trojan-panel-ui/version")
        compatible = version == "v2.3.0" or version.startswith("v2.3.0-")
    else:
        version = docker("exec", name, "./" + name, "-version")
        compatible = version in ("v2.3.0", "v2.3.1") or version.startswith("v2.3.1-")
    if not compatible:
        raise UpgradeError("{} reports unsupported schema version {}. Upgrade older installations separately; no legacy SQL is run here.".format(name, version))


def write_recovery(backup, records):
    manifest = {"created_at": datetime.datetime.utcnow().isoformat() + "Z", "containers": records}
    (backup / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    lines = ["Trojan Panel upgrade recovery", "", "This directory contains passwords and private keys. Keep it root-only and copy it securely off-host.",
             "Old containers and their images are retained. Database/Redis containers were not replaced or flushed.",
             "Container rollback does NOT roll back MySQL, SQLite or configuration writes. Do not restore an old SQL dump into a live deployment.",
             "Before data recovery stop ALL writers, including Core nodes on other servers. Restoring a snapshot discards later writes.",
             "mounted-data.tar.gz paths are relative to /. Review the archive before restoring with tar --acls --xattrs -xzpf <archive> -C /.",
             "trojan_panel_db.sql is a logical single-transaction database snapshot when backend was selected. Keep database credentials private.",
             "For a node-only upgrade, the central MySQL database is NOT backed up here. Back it up on the backend host first.",
             "", "For container-only rollback, first review actual container names/states with docker ps -a. Then, for each upgraded component:"]
    for record in records:
        lines += ["", "# " + record["name"], "docker update --restart=no " + record["name"], "docker stop " + record["name"],
                  "docker rename {} {}.failed".format(record["name"], record["old_name"]),
                  "docker rename {} {}".format(record["old_name"], record["name"]),
                  "docker update --restart={} {}".format(record["restart"], record["name"]),
                  "docker start " + record["name"]]
    lines += ["", "After functional verification, remove retained old containers manually only when rollback is no longer needed.",
              "Do not use docker system prune or image prune while relying on rollback containers."]
    (backup / "RECOVERY.txt").write_text("\n".join(lines) + "\n")


def upgrade(targets, backup_root="/var/backups/trojan-panel"):
    engine = Engine()
    snapshots = []
    for name, target in targets:
        container = inspect(name)
        if not container["State"]["Running"]:
            raise UpgradeError(name + " is not running; investigate it before upgrading.")
        old_image = inspect(container["Image"], "image")
        check_version(name)
        log("Pulling {} before touching {}...".format(target, name), flush=True)
        docker("pull", target)
        new_image = inspect(target, "image")
        if container["Image"] == new_image["Id"]:
            log(name + " already runs this image.", flush=True)
            continue
        payload = create_payload(container, old_image, new_image, target)
        if name != "trojan-panel-ui":
            config_source(container)
        if name == "trojan-panel-core":
            # A config.ini-only mount is insufficient: SQLite and its journal
            # must survive replacement, so require its whole directory persisted.
            mounted_source(container, working_directory(container) + "/config/sqlite")
        snapshots.append((name, container, payload))
    if not snapshots:
        log("All selected containers are current.")
        return None
    stamp = datetime.datetime.utcnow().strftime("%Y%m%dT%H%M%S") + "-" + str(os.getpid())
    backup = Path(backup_root).resolve() / stamp
    backup.mkdir(mode=0o700, parents=True, exist_ok=False)
    os.chmod(str(backup), 0o700)
    records = [{"name": name, "old_name": name + ".pre-" + stamp,
                "restart": restart_value(container), "inspect": container, "new_image": payload["Image"]}
               for name, container, payload in snapshots]
    write_recovery(backup, records)
    log("Backup and recovery instructions: " + str(backup), flush=True)
    for name, container, payload in snapshots:
        if name == "trojan-panel":
            backup_database(container, backup)
    transaction_label = "io.electronlsr.trojan-panel.upgrade"
    for _, _, payload in snapshots:
        payload["Labels"][transaction_label] = stamp
    try:
        for record in records:
            docker("update", "--restart=no", record["name"])
            docker("stop", "--time", "30", record["name"])
        backup_mounts([item[1] for item in snapshots], backup)
        for record, (_, container, payload) in zip(records, snapshots):
            docker("rename", record["name"], record["old_name"])
            new_id = engine.create(record["name"], payload)
            docker("start", new_id)
            wait_running(record["name"])
    except BaseException:
        # A second terminal disconnect/interrupt must not abort recovery halfway.
        saved_handlers = {sig: signal.signal(sig, signal.SIG_IGN) for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)}
        log("Upgrade failed. Restoring original container names and restart policies...", file=sys.stderr, flush=True)
        errors = []
        # All old containers stay intact. Never delete an old container or its image.
        safe_to_restart = []
        # Reinspect immutable old IDs and transaction labels, including a Docker
        # operation that succeeded on the daemon but lost its response to the CLI.
        for record in reversed(records):
            try:
                candidate = engine.inspect_optional(record["name"])
                if candidate and candidate["Id"] != record["inspect"]["Id"]:
                    if candidate.get("Config", {}).get("Labels", {}).get(transaction_label) != stamp:
                        raise UpgradeError("Unexpected container owns " + record["name"] + "; it was left untouched.")
                    docker("rm", "-f", candidate["Id"])
                    if engine.inspect_optional(record["name"]) is not None:
                        raise UpgradeError("Replacement still exists: " + record["name"])
                original = inspect(record["inspect"]["Id"])
                actual_name = original["Name"].lstrip("/")
                if actual_name != record["name"]:
                    docker("rename", actual_name, record["name"])
                safe_to_restart.append(record)
            except UpgradeError as error:
                # Do not restart an old writer when a replacement might still run.
                errors.append(str(error) + " Original remains stopped/disabled; inspect manually.")
        for record in safe_to_restart:
            try:
                old_id = record["inspect"]["Id"]
                docker("update", "--restart=" + record["restart"], old_id)
                docker("start", old_id)
            except UpgradeError as error:
                errors.append(str(error))
        for sig, handler in saved_handlers.items():
            signal.signal(sig, handler)
        log("Database/configuration writes were NOT rewound. Review " + str(backup / "RECOVERY.txt"), file=sys.stderr)
        if errors:
            log("Rollback needs manual attention: " + "; ".join(errors), file=sys.stderr)
        raise
    log("Updated containers passed startup checks. Verify login, subscriptions and node traffic before upgrading other servers.")
    log("Old containers/images retained; backup: " + str(backup))
    log("Startup checks are not an end-to-end traffic test. Container rollback cannot undo database/configuration writes.")
    return backup


def main():
    if os.geteuid() != 0:
        raise UpgradeError("Run this installer as root on the server being upgraded.")
    os.umask(0o077)
    # Prevent competing upgrade invocations from stopping/renaming the same containers.
    with open("/var/lock/trojan-panel-upgrade.lock", "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise UpgradeError("Another Trojan Panel upgrade is running.")
        if len(sys.argv) < 3 or len(sys.argv) % 2 != 1:
            raise UpgradeError("Expected pairs of container name and image reference.")
        targets = list(zip(sys.argv[1::2], sys.argv[2::2]))
        def interrupted(signum, frame):
            raise UpgradeError("Upgrade interrupted; recovering original containers.")
        signal.signal(signal.SIGTERM, interrupted)
        signal.signal(signal.SIGHUP, interrupted)
        upgrade(targets)


if __name__ == "__main__":
    try:
        main()
    except (UpgradeError, OSError, ValueError, KeyError, KeyboardInterrupt) as error:
        log("ERROR: " + str(error), file=sys.stderr)
        sys.exit(1)
TP_SAFE_UPGRADE_PY
# END EMBEDDED SAFE UPGRADE
}

update_trojan_panel_ui() {
  safe_upgrade trojan-panel-ui "${TROJAN_PANEL_UI_IMAGE}"
}

update_trojan_panel() {
  safe_upgrade trojan-panel "${TROJAN_PANEL_IMAGE}"
}

update_trojan_panel_core() {
  safe_upgrade trojan-panel-core "${TROJAN_PANEL_CORE_IMAGE}"
}

update_all_installed() {
  local targets=() name image
  for name in trojan-panel trojan-panel-core trojan-panel-ui; do
    if docker container inspect "${name}" >/dev/null 2>&1; then
      case "${name}" in
        trojan-panel) image="${TROJAN_PANEL_IMAGE}" ;;
        trojan-panel-core) image="${TROJAN_PANEL_CORE_IMAGE}" ;;
        trojan-panel-ui) image="${TROJAN_PANEL_UI_IMAGE}" ;;
      esac
      targets+=("${name}" "${image}")
    fi
  done
  if [[ ${#targets[@]} -eq 0 ]]; then
    echo_content red "No existing Trojan Panel components found. Use install options only for a new deployment."
    return 1
  fi
  safe_upgrade "${targets[@]}"
}

# Uninstall Caddy2+https
uninstall_caddy2() {
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
    echo_content green "---> Uninstall Caddy2+https"

    docker rm -f trojan-panel-caddy &&
      rm -rf ${CADDY_DATA}

    echo_content skyBlue "---> Caddy2+https uninstallation completed"
  else
    echo_content red "---> Please install Caddy2+https first"
  fi
}

# Uninstall Nginx
uninstall_nginx() {
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-nginx") ]]; then
    echo_content green "---> Uninstall Nginx"

    docker rm -f trojan-panel-nginx &&
      rm -rf ${NGINX_DATA}

    echo_content skyBlue "---> Nginx uninstallation completed"
  else
    echo_content red "---> Please install Nginx first"
  fi
}

# Uninstall MariaDB
uninstall_mariadb() {
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-mariadb$") ]]; then
    echo_content green "---> Uninstall MariaDB"

    docker rm -f trojan-panel-mariadb &&
      rm -rf ${MARIA_DATA}

    echo_content skyBlue "---> MariaDB uninstall completed"
  else
    echo_content red "---> Please install MariaDB first"
  fi
}

# Uninstall Redis
uninstall_redis() {
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-redis$") ]]; then
    echo_content green "---> Uninstall Redis"

    docker rm -f trojan-panel-redis &&
      rm -rf ${REDIS_DATA}

    echo_content skyBlue "---> Redis uninstall completed"
  else
    echo_content red "---> Please install Redis first"
  fi
}

# Uninstall Trojan Panel Frontend
uninstall_trojan_panel_ui() {
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-ui$") ]]; then
    echo_content green "---> Uninstall Trojan Panel Frontend"

    docker rm -f trojan-panel-ui &&
      rm -rf ${TROJAN_PANEL_UI_DATA}

    echo_content skyBlue "---> Trojan Panel Frontend uninstallation completed"
  else
    echo_content red "---> Please install the Trojan Panel Frontend first"
  fi
}

# Uninstall Trojan Panel Backend
uninstall_trojan_panel() {
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel$") ]]; then
    echo_content green "---> Uninstall Trojan Panel Backend"

    docker rm -f trojan-panel &&
      rm -rf ${TROJAN_PANEL_DATA}

    echo_content skyBlue "---> Trojan Panel Backend uninstallation completed"
  else
    echo_content red "---> Please install the Trojan Panel Backend first"
  fi
}

# Uninstall Trojan Panel Core
uninstall_trojan_panel_core() {
  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-core$") ]]; then
    echo_content green "---> Uninstall Trojan Panel Core"

    docker rm -f trojan-panel-core &&
      rm -rf ${TROJAN_PANEL_CORE_DATA}

    echo_content skyBlue "---> Trojan Panel Core uninstallation completed"
  else
    echo_content red "---> Please install the Trojan Panel Core first"
  fi
}

# Uninstall all Trojan Panel related containers
uninstall_all() {
  echo_content green "---> Uninstall all Trojan Panel related containers"

  docker rm -f $(docker ps -a -q -f "name=^trojan-panel")
  docker rmi -f $(docker images | grep "^jonssonyan/trojan-panel" | awk '{print $3}')
  rm -rf ${TP_DATA}

  echo_content skyBlue "---> Uninstall all Trojan Panel related containers completed"
}

# Modify Trojan Panel Frontend port
update_trojan_panel_ui_port() {
  if [[ -n $(docker ps -q -f "name=^trojan-panel-ui$" -f "status=running") ]]; then
    echo_content green "---> Modify Trojan Panel Frontend port"

    trojan_panel_ui_port=$(grep 'listen.*ssl' ${UI_NGINX_CONFIG} | awk '{print $2}')
    if [[ -z "${trojan_panel_ui_port}" ]]; then
      ui_https=0
      trojan_panel_ui_port=$(grep -oP 'listen\s+\K\d+' ${UI_NGINX_CONFIG} | awk 'NR==1')
    fi
    if [[ -z "${trojan_panel_ui_port}" ]]; then
      echo_content red "---> Trojan Panel Frontend port not queried"
      exit 0
    fi
    echo_content yellow "Tip: The current port of the Trojan Panel Frontend (trojan-panel-ui) is ${trojan_panel_ui_port}"

    read -r -p "Please enter the new port of the Trojan Panel Frontend (default: 8888): " trojan_panel_ui_port
    [[ -z "${trojan_panel_ui_port}" ]] && trojan_panel_ui_port="8888"

    if [[ ${ui_https} == 0 ]]; then
      # http
      sed -i "s/listen.*;/listen       ${trojan_panel_ui_port};/g" ${UI_NGINX_CONFIG} &&
        sed -i "s/http:\/\/\$host:.*\$request_uri;/http:\/\/\$host:${trojan_panel_ui_port}\$request_uri;/g" ${UI_NGINX_CONFIG} &&
        docker restart trojan-panel-ui
    else
      # https
      sed -i "s/listen.*ssl;/listen       ${trojan_panel_ui_port} ssl;/g" ${UI_NGINX_CONFIG} &&
        sed -i "s/https:\/\/\$host:.*\$request_uri;/https:\/\/\$host:${trojan_panel_ui_port}\$request_uri;/g" ${UI_NGINX_CONFIG} &&
        docker restart trojan-panel-ui
    fi

    if [[ "$?" == "0" ]]; then
      echo_content skyBlue "---> Trojan Panel Frontend port modification completed"
    else
      echo_content red "---> Trojan Panel Frontend port modification failed"
    fi
  else
    echo_content red "---> The Trojan Panel Frontend is not installed or is running abnormally, please repair or uninstall and reinstall and try again"
  fi
}

# Refresh Redis cache
redis_flush_all() {
  if [[ -z $(docker ps -a -q -f "name=^trojan-panel-redis$") ]]; then
    echo_content red "---> Please install Redis first"
    exit 0
  fi

  if [[ -z $(docker ps -q -f "name=^trojan-panel-redis$" -f "status=running") ]]; then
    echo_content red "---> Redis is running abnormally"
    exit 0
  fi

  echo_content green "---> Refresh Redis cache"

  read -r -p "Please enter the IP address of Redis (default: local host): " redis_host
  [[ -z "${redis_host}" ]] && redis_host="127.0.0.1"
  read -r -p "Please enter the port of Redis (default: 6378): " redis_port
  [[ -z "${redis_port}" ]] && redis_port=6378
  while read -r -p "Please enter the Redis password (required): " redis_pass; do
    if [[ -z "${redis_pass}" ]]; then
      echo_content red "Password can not be empty"
    else
      break
    fi
  done

  docker exec trojan-panel-redis redis-cli -h "${redis_host}" -p "${redis_port}" -a "${redis_pass}" -e "flushall" &>/dev/null

  echo_content skyBlue "---> Redis cache refresh completed"
}

# Replace certificate
change_cert() {
  domain_1=$(cat "${DOMAIN_FILE}")

  if [[ -n $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
    docker rm -f trojan-panel-caddy &&
      rm -rf ${CADDY_LOG}* &&
      echo "" >${CADDY_CONFIG} &&
      rm -rf ${WEB_PATH}*
  fi

  rm -rf ${CERT_PATH}* &&
    echo "" >${DOMAIN_FILE}

  install_reverse_proxy
  install_cert

  domain_2=$(cat "${DOMAIN_FILE}")
  if [[ -n "${domain_1}" && -n "${domain_2}" ]]; then
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-nginx$") ]]; then
      sed -i "s/${domain_1}/${domain_2}/g" ${NGINX_CONFIG} &&
        docker restart trojan-panel-nginx
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-ui$") ]]; then
      sed -i "s/${domain_1}/${domain_2}/g" ${UI_NGINX_DATA} &&
        docker restart trojan-panel-ui
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-core$") ]]; then
      find /tpdata/trojan-panel-core/bin/ -type f -exec sed -i "s/${domain_1}/${domain_2}/g" {} + &&
        sed -i "s/${domain_1}/${domain_2}/g" ${trojan_panel_core_config_path} &&
        docker restart trojan-panel-core
    fi
  fi
}

# Forgot sysadmin password
forget_pass() {
  while :; do
    echo_content yellow "1. Query MariaDB password"
    echo_content yellow "2. Query Redis password"
    echo_content yellow "3. Reset the username and password of the admin panel system administrator"
    echo_content yellow "4. Quit"
    read -r -p "Please choose (default: 4): " forget_pass_option
    [[ -z "${forget_pass_option}" ]] && forget_pass_option=4
    case ${forget_pass_option} in
    1)
      if [[ -n $(docker ps -a -q -f "name=^trojan-panel$") ]]; then
        mariadb_user=$(get_ini_value ${trojan_panel_config_path} mysql.user)
        mariadb_pas=$(get_ini_value ${trojan_panel_config_path} mysql.password)
        echo_content red "\n=============================================================="
        echo_content yellow "MariaDB ${mariadb_user} password (please keep it safe): ${mariadb_pas}"
        echo_content red "\n=============================================================="
      else
        echo_content red "---> Please execute on the Trojan Panel backend server"
      fi
      ;;
    2)
      if [[ -n $(docker ps -a -q -f "name=^trojan-panel$") ]]; then
        redis_pass=$(get_ini_value ${trojan_panel_config_path} redis.password)
        echo_content red "\n=============================================================="
        echo_content yellow "Redis password (please keep it safe): ${redis_pass}"
        echo_content red "\n=============================================================="
      else
        echo_content red "---> Please execute on the Trojan Panel backend server"
      fi
      ;;
    3)
      if [[ -n $(docker ps -a -q -f "name=^trojan-panel-mariadb$") ]]; then
        read -r -p "Please enter the IP address of MariaDB (default: local host): " mariadb_ip
        [[ -z "${mariadb_ip}" ]] && mariadb_ip="127.0.0.1"
        read -r -p "Please enter the port of MariaDB (default: 9507): " mariadb_port
        [[ -z "${mariadb_port}" ]] && mariadb_port=9507
        read -r -p "Please enter the username of MariaDB (default: root): " mariadb_user
        [[ -z "${mariadb_user}" ]] && mariadb_user="root"
        while read -r -p "Please enter the password of MariaDB (required): " mariadb_pas; do
          if [[ -z "${mariadb_pas}" ]]; then
            echo_content red "Password can not be empty"
          else
            break
          fi
        done

        docker exec trojan-panel-mariadb mysql --default-character-set=utf8 -h"${mariadb_ip}" -P"${mariadb_port}" -u"${mariadb_user}" -p"${mariadb_pas}" -Dtrojan_panel_db -e "update account set username = 'sysadmin',pass = 'tFjD2X1F6i9FfWp2GDU5Vbi1conuaChDKIYbw9zMFrqvMoSz',hash='4366294571b8b267d9cf15b56660f0a70659568a86fc270a52fdc9e5',deleted = 0 where id = 1 limit 1"
        if [[ "$?" == "0" ]]; then
          echo_content red "\n=============================================================="
          echo_content yellow "System administrator Default username: sysadmin Default password: 123456"
          echo_content yellow "Please log in to the management panel to change the password in time"
          echo_content red "\n=============================================================="
        else
          echo_content red "Admin panel sysadmin username and password reset failed"
        fi
      else
        echo_content red "---> Please execute on the MariaDB server"
      fi
      ;;
    4)
      break
      ;;
    *)
      echo_content red "No such option"
      continue
      ;;
    esac
  done
}

# Fault detection
failure_testing() {
  echo_content green "---> Start troubleshooting"
  if [[ ! $(docker -v 2>/dev/null) ]]; then
    echo_content red "---> Docker is running abnormally"
  else
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-caddy$") ]]; then
      if [[ -z $(docker ps -q -f "name=^trojan-panel-caddy$" -f "status=running") ]]; then
        echo_content red "---> Caddy2 is running abnormally and the running log is as follows:"
        docker logs trojan-panel-caddy
      fi
      domain=$(cat "${DOMAIN_FILE}")
      if [[ -n ${domain} && ! -f "${CERT_PATH}${domain}.crt" ]]; then
        echo_content red "---> The certificate application is abnormal, please try 1. Change the sub-domain name to re-build 2. Restart the server to re-apply for the certificate 3. Re-build and select the custom certificate option"
        if [[ -f ${CADDY_LOG}error.log ]]; then
          echo_content red "Caddy2 error log is as follows:"
          tail -n 20 ${CADDY_LOG}error.log | grep error
        fi
      fi
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-mariadb$") && -z $(docker ps -q -f "name=^trojan-panel-mariadb$" -f "status=running") ]]; then
      echo_content red "---> The MariaDB is running abnormally and the running log is as follows:"
      docker logs trojan-panel-mariadb
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-redis$") && -z $(docker ps -q -f "name=^trojan-panel-redis$" -f "status=running") ]]; then
      echo_content red "---> The Redis is running abnormally and the running log is as follows:"
      docker logs trojan-panel-redis
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel$") && -z $(docker ps -q -f "name=^trojan-panel$" -f "status=running") ]]; then
      echo_content red "---> The Trojan Panel Backend is running abnormally and the running log is as follows:"
      if [[ -f ${TROJAN_PANEL_LOGS}trojan-panel.log ]]; then
        tail -n 20 ${TROJAN_PANEL_LOGS}trojan-panel.log | grep error
      else
        docker logs trojan-panel
      fi
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-ui$") && -z $(docker ps -q -f "name=^trojan-panel-ui$" -f "status=running") ]]; then
      echo_content red "---> The Trojan Panel Frontend is running abnormally and the running log is as follows:"
      docker logs trojan-panel-ui
    fi
    if [[ -n $(docker ps -a -q -f "name=^trojan-panel-core$") && -z $(docker ps -q -f "name=^trojan-panel-core$" -f "status=running") ]]; then
      echo_content red "---> The Trojan Panel Core is running abnormally and the running log is as follows:"
      if [[ -f ${TROJAN_PANEL_CORE_LOGS}trojan-panel.log ]]; then
        tail -n 20 ${TROJAN_PANEL_CORE_LOGS}trojan-panel.log | grep error
      else
        docker logs trojan-panel-core
      fi
    fi
  fi
  echo_content green "---> Troubleshooting ended"
}

log_query() {
  while :; do
    echo_content skyBlue "Applications that can query logs are as follows:"
    echo_content yellow "1. Trojan Panel Backend"
    echo_content yellow "2. Trojan Panel Frontend"
    echo_content yellow "3. Quit"
    read -r -p "Please select an application (default: 3): " select_log_query_type
    [[ -z "${select_log_query_type}" ]] && select_log_query_type=3

    case ${select_log_query_type} in
    1)
      log_file_path=${TROJAN_PANEL_LOGS}trojan-panel.log
      ;;
    2)
      log_file_path=${TROJAN_PANEL_CORE_LOGS}trojan-panel-core.log
      ;;
    3)
      break
      ;;
    *)
      echo_content red "No such option"
      continue
      ;;
    esac

    read -r -p "Please enter the number of rows to query (default: 20): " select_log_query_line_type
    [[ -z "${select_log_query_line_type}" ]] && select_log_query_line_type=20

    if [[ -f ${log_file_path} ]]; then
      echo_content skyBlue "The log is as follows:"
      tail -n ${select_log_query_line_type} ${log_file_path}
    else
      echo_content red "No log file exists"
    fi
  done
}

version_query() {
  local name image
  for name in trojan-panel-ui trojan-panel trojan-panel-core; do
    case "${name}" in
      trojan-panel-ui) image="${TROJAN_PANEL_UI_IMAGE}" ;;
      trojan-panel) image="${TROJAN_PANEL_IMAGE}" ;;
      trojan-panel-core) image="${TROJAN_PANEL_CORE_IMAGE}" ;;
    esac
    if docker container inspect "${name}" >/dev/null 2>&1; then
      echo_content yellow "${name}: $(docker inspect --format '{{.Config.Image}} ({{.Image}})' "${name}")"
      echo_content yellow "Target release: ${image}"
    fi
  done
}

main() {
  cd "$HOME" || exit 0
  init_var
  clear
  echo_content red "\n=============================================================="
  echo_content skyBlue "System Required: CentOS 7+/Ubuntu 18+/Debian 10+"
  echo_content skyBlue "Fork release: ${IMAGE_RELEASE}"
  echo_content skyBlue "Description: One click Install Trojan Panel server"
  echo_content skyBlue "Author: jonssonyan <https://jonssonyan.com>"
  echo_content skyBlue "Github: https://github.com/electronlsr/install-script"
  echo_content skyBlue "Docs: https://trojanpanel.github.io"
  echo_content red "\n=============================================================="
  echo_content yellow "1. Install Trojan Panel Frontend"
  echo_content yellow "2. Install Trojan Panel Backend"
  echo_content yellow "3. Install Trojan Panel Core"
  echo_content yellow "4. Install Caddy2+https"
  echo_content yellow "5. Install Nginx"
  echo_content yellow "6. Install MariaDB"
  echo_content yellow "7. Install Redis"
  echo_content green "\n=============================================================="
  echo_content yellow "26. SAFE UPGRADE all installed Panel components (recommended for existing servers)"
  echo_content yellow "8. Safe upgrade Trojan Panel Frontend"
  echo_content yellow "9. Safe upgrade Trojan Panel Backend"
  echo_content yellow "10. Safe upgrade Trojan Panel Core"
  echo_content green "\n=============================================================="
  echo_content yellow "11. Uninstall Trojan Panel Frontend"
  echo_content yellow "12. Uninstall Trojan Panel Backend"
  echo_content yellow "13. Uninstall Trojan Panel Core"
  echo_content yellow "14. Uninstall Caddy2+https"
  echo_content yellow "15. Uninstall Nginx"
  echo_content yellow "16. Uninstall MariaDB"
  echo_content yellow "17. Uninstall Redis"
  echo_content yellow "18. Uninstall all Trojan Panel related containers"
  echo_content green "\n=============================================================="
  echo_content yellow "19. Modify Trojan Panel Frontend port"
  echo_content yellow "20. Refresh Redis cache"
  echo_content yellow "21. Replace certificate"
  echo_content yellow "22. Forgot sysadmin password"
  echo_content green "\n=============================================================="
  echo_content yellow "23. Fault detection"
  echo_content yellow "24. Log query"
  echo_content yellow "25. Version query"
  read -r -p "Please choose: " selectInstall_type
  # Read-only/version/upgrade menus must not update OS packages or touch config files.
  if [[ "${selectInstall_type}" =~ ^[1-7]$ ]]; then
    case "${selectInstall_type}" in
      1) existing_component=trojan-panel-ui ;;
      2) existing_component=trojan-panel ;;
      3) existing_component=trojan-panel-core ;;
      *) existing_component="" ;;
    esac
    if [[ -n "${existing_component}" ]] && docker container inspect "${existing_component}" >/dev/null 2>&1; then
      echo_content yellow "${existing_component} is already installed. Choose 26 or its safe upgrade menu; do not uninstall/reinstall."
      return 1
    fi
    check_sys || return 1
    depend_install || return 1
    mkdir_tools || return 1
  fi
  case ${selectInstall_type} in
  1)
    install_docker
    install_reverse_proxy
    install_cert
    install_trojan_panel_ui
    ;;
  2)
    install_docker
    install_mariadb
    install_redis
    install_trojan_panel
    ;;
  3)
    install_docker
    install_reverse_proxy
    install_cert
    install_trojan_panel_core
    ;;
  4)
    install_docker
    install_caddy2
    ;;
  5)
    install_docker
    install_nginx
    ;;
  6)
    install_docker
    install_mariadb
    ;;
  7)
    install_docker
    install_redis
    ;;
  8)
    update_trojan_panel_ui
    ;;
  9)
    update_trojan_panel
    ;;
  10)
    update_trojan_panel_core
    ;;
  11)
    uninstall_trojan_panel_ui
    ;;
  12)
    uninstall_trojan_panel
    ;;
  13)
    uninstall_trojan_panel_core
    ;;
  14)
    uninstall_caddy2
    ;;
  15)
    uninstall_nginx
    ;;
  16)
    uninstall_mariadb
    ;;
  17)
    uninstall_redis
    ;;
  18)
    uninstall_all
    ;;
  19)
    update_trojan_panel_ui_port
    ;;
  20)
    redis_flush_all
    ;;
  21)
    change_cert
    ;;
  22)
    forget_pass
    ;;
  23)
    failure_testing
    ;;
  24)
    log_query
    ;;
  25)
    version_query
    ;;
  26)
    update_all_installed
    ;;
  *)
    echo_content red "No such option"
    ;;
  esac
}

# Test suites may source functions without running server-side commands.
if [[ "${TP_INSTALLER_TEST_MODE:-0}" != "1" ]]; then
  main "$@"
fi
