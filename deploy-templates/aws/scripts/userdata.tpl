Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0

--//
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="cloud-config.txt"

#cloud-config
cloud_final_modules:
- [scripts-user, always]

--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.txt"

#!/usr/bin/env bash


KES_URL="${kes_download_url}"
BUCKET_NAME="${bucket_name}"
MINIO_URL="${minio_url}"
MC_URL="${mc_url}"
VAULT_IP="${vault_ip}"
MINIO_ROOT_USER="${minio_root_user}"
MINIO_ROOT_PASSWORD="${minio_root_password}"
SYSTEM_VOLUME_PATH=${minio_volume_path}
VAULT_AUTH_ROLE_ID="${vault_auth_role_id}"
VAULT_AUTH_SECRET_ID="${vault_auth_secret_id}"

MINIO_USER="minio"
MINIO_GROUP="minio"
MINIO_HOME="/home/minio"
MINIO_KES_KEY_NAME="minio-$${BUCKET_NAME}"
MINIO_CONFIG_DIR="/etc/minio"
MINIO_ENV_FILE="/etc/default/minio"
MINIO_VOLUME_MOUNT_PATH="/usr/local/share/minio"
MINIO_STORAGE_DIR="$${MINIO_VOLUME_MOUNT_PATH}/storage"
MINIO_KES_CLIENT_DIR="$${MINIO_CONFIG_DIR}/kes-client"
MINIO_KES_CLIENT_KEY_PATH="$${MINIO_KES_CLIENT_DIR}/client.key"
MINIO_KES_CLIENT_CRT_PATH="$${MINIO_KES_CLIENT_DIR}/client.cert"
MINIO_KES_SERVER_TLS_PATH="$${MINIO_KES_CLIENT_DIR}/tls/server.cert"
MINIO_KES_CLIENT_NAME="MinIO"
MINIO_UI_PORT="9001"
MINIO_API_PORT="9000"

PLATFORM_API_KEY_FILE_PATH="$${MINIO_KES_CLIENT_DIR}/platform-api-key"
PLATFORM_KES_CLIENT_NAME="Platform"
PLATFORM_KES_CLIENT_KEY_PATH="$${MINIO_KES_CLIENT_DIR}/platform.key"
PLATFORM_KES_CLIENT_CRT_PATH="$${MINIO_KES_CLIENT_DIR}/platform.cert"


KES_USER="kes"
KES_GROUP="kes"
KES_HOME="/home/kes"
KES_CONFIG_DIR="/etc/kes"
KES_SYSTEMD_PATH="/etc/systemd/system/kes.service"
KES_TLS_DIR="$${KES_CONFIG_DIR}/tls"
KES_SERVER_CONFIG_PATH="$${KES_CONFIG_DIR}/config.yaml"
KES_SERVER_KEY_PATH="$${KES_TLS_DIR}/server.key"
KES_SERVER_CRT_PATH="$${KES_TLS_DIR}/server.cert"
KES_SERVER_IP="127.0.0.1"
KES_SERVER_DNS="localhost"


declare  MINIO_IDENTITY PLATFORM_IDENTITY


function install_prerequisites() {
  apt-get update
  apt-get install -y unzip \
                 libtool \
                 libltdl-dev \
                 sharutils \
                 curl \
                 software-properties-common
  curl --silent --output /usr/local/bin/mc "$${MC_URL}"
  chmod +x /usr/local/bin/mc
}


function create_user() {
  local user group home_dir
  user="$${1}"
  group="$${2}"
  home_dir="$${3}"
  if ! getent group $${user} >/dev/null
  then
    sudo addgroup --system $${group} >/dev/null
  fi

  if ! getent passwd $${user} >/dev/null
  then
    sudo adduser \
    --system \
    --disabled-login \
    --ingroup $${group} \
    --home $${home_dir} \
    --no-create-home \
    --shell /bin/false \
    $${user}  >/dev/null
  fi
}


function create_service_users() {
  create_user "$${MINIO_USER}" "$${MINIO_GROUP}" "$${MINIO_HOME}"
  create_user "$${KES_USER}" "$${KES_GROUP}" "$${KES_HOME}"
  logger "Users setup complete"
}


function create_directories() {
  #Create all dirs that are necessary in installation process
  declare -a directories=("$${KES_TLS_DIR}" "$${MINIO_KES_CLIENT_DIR}/tls")
  for dir in $${directories[@]};do
    mkdir -p "$${dir}"
  done

}


function install_kes_binary(){
  local binary_path
  logger "Downloading KES binary"
  binary_path="/usr/local/bin/kes"
  if [[ ! -f "$${binary_path}" ]]; then
      wget -q $${KES_URL} -O $${binary_path}
      rm -rf kes-linux-amd64
      chmod +x $${binary_path}
      chown $${KES_USER}:$${KES_GROUP} $${binary_path}
  fi
}


function install_minio_binary() {
  local binary_path
  binary_path="/usr/local/bin/minio"
  if [[ -f /lib/systemd/system/minio.service ]]; then
    logger "Stopping MinIO service"
    systemctl stop minio
  fi
  logger "Downloading MINIO binary"
  wget -q $${MINIO_URL} -O $${binary_path}
  chmod +x $${binary_path}
  chown $${MINIO_USER}:$${MINIO_GROUP} $${binary_path}
  if [[ -f /lib/systemd/system/minio.service ]]; then
    logger "Starting MinIO service"
    systemctl start minio
  fi
}


function create_kes_identity() {
    local tmp_file_path api_key_file_path
    tmp_file_path="/tmp/platform-client-identity"
    logger "[INFO] Creating KES server certificates"
    if [[ ! -f "$${KES_SERVER_KEY_PATH}" ]]; then
        kes identity new --key $${KES_SERVER_KEY_PATH} --cert $${KES_SERVER_CRT_PATH} \
                         --ip "$${KES_SERVER_IP}" \
                         --dns $${KES_SERVER_DNS}
    fi
    if [[ ! -f "$${MINIO_KES_CLIENT_CRT_PATH}" ]]; then
        kes identity new --key=$${MINIO_KES_CLIENT_KEY_PATH} \
         --cert=$${MINIO_KES_CLIENT_CRT_PATH} $${MINIO_KES_CLIENT_NAME}
    fi
    if [[ ! -f "$${PLATFORM_KES_CLIENT_CRT_PATH}" ]]; then
       kes identity new --key=$${PLATFORM_KES_CLIENT_KEY_PATH} \
        --cert=$${PLATFORM_KES_CLIENT_CRT_PATH} $${PLATFORM_KES_CLIENT_NAME} > $${tmp_file_path}
        cat $${tmp_file_path} | grep "API key:" -C 2 | tail -n1 | awk '{print $1}' > $${PLATFORM_API_KEY_FILE_PATH}
    fi
    PLATFORM_IDENTITY=$(kes identity of $${PLATFORM_KES_CLIENT_CRT_PATH} | tail -n 1 | awk '{print $1}' | tr -d '\n')
    MINIO_IDENTITY=$(kes identity of $${MINIO_KES_CLIENT_CRT_PATH} | tail -n 1 | awk '{print $1}' | tr -d '\n')
}


function minio_kes_tls() {
  cp $${KES_SERVER_CRT_PATH}  $${MINIO_KES_SERVER_TLS_PATH}
  chown $${MINIO_USER}:$${MINIO_GROUP} $${MINIO_KES_SERVER_TLS_PATH}
}


function create_kes_service() {
    cat <<EOF > $${KES_SERVER_CONFIG_PATH}
    address: 0.0.0.0:7373
    admin:
      identity: disabled
    tls:
      key: /etc/kes/tls/server.key
      cert: /etc/kes/tls/server.cert
    policy:
      minio:
        allow:
        - /v1/key/create/minio-*
        - /v1/key/generate/minio-*
        - /v1/key/decrypt/minio-*
        identities:
        - $${MINIO_IDENTITY}
        - $${PLATFORM_IDENTITY}
    keystore:
      vault:
        endpoint: http://$${VAULT_IP}:8200
        version:  v1
        engine:   kv
        approle:
          id: $${VAULT_AUTH_ROLE_ID}
          secret: $${VAULT_AUTH_SECRET_ID}
EOF

  cat <<EOF > $${KES_SYSTEMD_PATH}
  [Unit]
  Description=KES
  Documentation=https://github.com/minio/kes/wiki
  Wants=network-online.target
  After=network-online.target
  AssertFileIsExecutable=/usr/local/bin/kes

  [Service]
  WorkingDirectory=/etc/kes/

  User=$${KES_USER}
  Group=$${KES_GROUP}

  ProtectProc=invisible

  ExecStart=/usr/local/bin/kes server --config=$${KES_SERVER_CONFIG_PATH}

  # Let systemd restart this service always
  Restart=always

  # Specifies the maximum file descriptor number that can be opened by this process
  LimitNOFILE=65536

  # Specifies the maximum number of threads this process can create
  TasksMax=infinity

  # Disable timeout logic and wait until process is stopped
  TimeoutStopSec=infinity
  SendSIGKILL=no

  # Enable memory locking features used to prevent paging.
  AmbientCapabilities=CAP_IPC_LOCK

  [Install]
  WantedBy=multi-user.target
EOF

  chown $${KES_USER}:$${KES_GROUP} -R /etc/kes

}


function run_kes_server() {
    systemctl daemon-reload
    systemctl enable kes
    systemctl restart kes
}


function mount_minio_volume() {
  MINIO_VOLUME_FS=`blkid -o value -s TYPE $${SYSTEM_VOLUME_PATH}`
  if [[ -z $${MINIO_VOLUME_FS} ]] ; then
          mkfs.xfs $${SYSTEM_VOLUME_PATH}
  fi

  mkdir -p $${MINIO_STORAGE_DIR}
  echo "$${SYSTEM_VOLUME_PATH} $${MINIO_VOLUME_MOUNT_PATH} xfs defaults 0 0" >> /etc/fstab
  mount $${MINIO_VOLUME_MOUNT_PATH}
  chown $${MINIO_USER}:$${MINIO_GROUP} -R $${MINIO_VOLUME_MOUNT_PATH}
}


function config_minio() {
  cat << EOF > $${MINIO_ENV_FILE}
  MINIO_ROOT_USER=$${MINIO_ROOT_USER}
  MINIO_VOLUMES="/usr/local/share/minio/storage"
  MINIO_OPTS="-C /etc/minio --address :$${MINIO_API_PORT} --console-address :$${MINIO_UI_PORT}"
  MINIO_ROOT_PASSWORD="$${MINIO_ROOT_PASSWORD}"
  MINIO_KMS_KES_ENDPOINT=https://$${KES_SERVER_IP}:7373
  MINIO_KMS_KES_CERT_FILE=$${MINIO_KES_CLIENT_CRT_PATH}
  MINIO_KMS_KES_KEY_FILE=$${MINIO_KES_CLIENT_KEY_PATH}
  MINIO_KMS_KES_KEY_NAME=$${MINIO_KES_KEY_NAME}
  MINIO_KMS_KES_CAPATH=$${MINIO_KES_SERVER_TLS_PATH}
EOF

chown $${MINIO_USER}:$${MINIO_GROUP} $${MINIO_ENV_FILE}

  cat << EOF > /lib/systemd/system/minio.service
  [Unit]
  Description=MinIO
  Documentation=https://docs.min.io
  Wants=network-online.target
  After=network-online.target
  AssertFileIsExecutable=/usr/local/bin/minio

  [Service]
  WorkingDirectory=/usr/local/

  User=$${MINIO_USER}
  Group=$${MINIO_GROUP}

  EnvironmentFile=$${MINIO_ENV_FILE}
  ExecStartPre=/bin/bash -c "if [ -z \"/usr/local/share/minio/\" ]; then echo \"Variable MINIO_VOLUMES not set in /etc/default/minio\"; exit 1; fi"

  ExecStart=/usr/local/bin/minio server \$MINIO_OPTS \$MINIO_VOLUMES

  # Let systemd restart this service always
  Restart=always

  # Specifies the maximum file descriptor number that can be opened by this process
  LimitNOFILE=65536

  # Specifies the maximum number of threads this process can create
  TasksMax=infinity

  # Disable timeout logic and wait until process is stopped
  TimeoutStopSec=infinity
  SendSIGKILL=no

  [Install]
  WantedBy=multi-user.target
EOF

chown $${MINIO_USER}:$${MINIO_GROUP} -R $${MINIO_CONFIG_DIR}
}


function run_minio_server() {
    systemctl daemon-reload
    systemctl enable minio
    systemctl restart minio
}

function configure_minio() {
  local server_name
  server_name="platform-minio"
  mc alias set $${server_name} http://localhost:$${MINIO_API_PORT} minio $${MINIO_ROOT_PASSWORD}
  if mc stat "$${server_name}/$${BUCKET_NAME}" &>/dev/null; then
    echo "Bucket '$BUCKET_NAME' exists, skipping next command."
  else
    mc mb $${server_name}/$${BUCKET_NAME}
  fi
  mc encrypt set sse-kms $${MINIO_KES_KEY_NAME} $${server_name}/$${BUCKET_NAME}
}

function wait_for_port() {
    local port=$${MINIO_API_PORT}
    local host="localhost"
    local timeout=5
    local interval=10

    echo "Waiting for port $${port} to be open on $${host}..."
    until nc -z -w $${timeout} $${host} $${port}; do
        echo "Port $${port} is not available yet, retrying in $${interval} seconds..."
        sleep $${interval}
    done

    echo "Port $${port} is now open!"
}

function schedule_task() {
    # Define the script path and log file
    SCRIPT_PATH="/usr/local/bin/update-client-certificates.sh"

    # Create the desired script to run on the 4th day of each month
    cat << EOF > $SCRIPT_PATH
#!/bin/bash
mkdir /tmp/tls
/usr/local/bin/kes identity new --ip "127.0.0.1" --cert /tmp/tls/server.cert --key /tmp/tls/server.key localhost>>/tmp/file-debug 2>&1
/usr/local/bin/kes identity new --cert /tmp/tls/client.cert --key /tmp/tls/client.key MinIO > /tmp/tls/apikey.tmp
NEW_API_KEY=\$(cat /tmp/tls/apikey.tmp | grep "API key:" -C 2 | tail -n1 | awk '{print \$1}')
NEW_CLIENT_IDENTITY=\$(/usr/local/bin/kes identity of /tmp/tls/client.cert  | tail -n 1 | awk '{print \$1}' | tr -d '\n')
OLD_CLIENT_IDENTITY=\$(/usr/local/bin/kes identity of /etc/minio/kes-client/client.cert  | tail -n 1 | awk '{print \$1}' | tr -d '\n')
sed -i 's/'\$${OLD_CLIENT_IDENTITY}'/'\$${NEW_CLIENT_IDENTITY}'/g' /etc/kes/config.yaml
cp /tmp/tls/server.cert /etc/kes/tls/server.cert
cp /tmp/tls/server.key /etc/kes/tls/server.key
cp /tmp/tls/server.cert /etc/minio/kes-client/tls/server.cert
cp /tmp/tls/client.cert /etc/minio/kes-client/client.cert
cp /tmp/tls/client.key /etc/minio/kes-client/client.key
rm -rf /tmp/tls
systemctl restart kes
systemctl restart minio
EOF

    # Make the script executable
    chmod +x $SCRIPT_PATH

    # Add a cron job to execute the script on the 4th day of each month at 2 PM
    CRON_JOB="0 16 4 * * $SCRIPT_PATH"
    echo "$CRON_JOB" | crontab -

    # Initial log entry
    echo "Scheduled task set to run on the 4th day of each month at 16 PM"
}

function run_userdata() {
    install_prerequisites
    create_directories
    create_service_users
    install_kes_binary
    create_kes_identity
    create_kes_service
    run_kes_server
    install_minio_binary
    mount_minio_volume
    minio_kes_tls
    config_minio
    run_minio_server
    wait_for_port
    configure_minio
    schedule_task
}

run_userdata "@"
