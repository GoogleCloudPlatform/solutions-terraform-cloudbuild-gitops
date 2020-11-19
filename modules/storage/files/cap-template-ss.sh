#!/bin/bash
#Install GCSFuse:
 #1-register package on yum
sudo tee /etc/yum.repos.d/gcsfuse.repo > /dev/null <<EOF
[gcsfuse]
name=gcsfuse (packages.cloud.google.com)
baseurl=https://packages.cloud.google.com/yum/repos/gcsfuse-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
 #2-update yum to download GCSFuse
#sudo yum update -y
 #3-install GCSFuse
sudo yum install gcsfuse -y

#Users secrets to be fetched and created
export pocuser1Secret=secret:/cap-secret-v1#1
export archiveuserSecret=secret:/cap-archive-v1#1


sudo sed -i 's/PasswordAuthentication no/#PasswordAuthentication no/g' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sudo sed -i 's/ChallengeResponseAuthentication no/#ChallengeResponseAuthentication no/g' /etc/ssh/sshd_config
sudo sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
sudo sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/g' /etc/ssh/sshd_config

sudo systemctl restart sshd.service

secret_prefix="secret:"

# load the secrets
for i in $(printenv | grep ${secret_prefix})
do
  key=$(echo ${i} | cut -d'=' -f 1)
  val=$(echo ${i} | cut -d'=' -f 2-)
  echo $val
  if [[ ${val} == ${secret_prefix}* ]]
  then
    val=$(echo ${val} | sed -e "s/${secret_prefix}//g")
    projectId=$(echo ${val} | cut -d'/' -f 1)
    secret=$(echo ${val} | cut -d'/' -f 2)

    if [[ -n ${projectId} ]]
    then
      project="--project=${projectId}"
    fi

    secretName=$(echo ${secret} | cut -d'#' -f 1)
    # userAux=$(echo ${secretName} | cut -d'-' -f 2)
    user=$(echo ${secretName})
    
    version="latest"
    if [[ ${val} == *#* ]]
    then
      version=$(echo ${val} | cut -d'#' -f 2)
    fi  
    plain="$(gcloud beta secrets versions access --secret=${secretName} ${version} ${project})"
    #For multiline management
    export $key="$(echo $plain | sed -e 's/\n//g')"
    sudo adduser $user
    echo $plain | sudo passwd --stdin $user


    #Get GCP project ID && project env
    export PROJECT_ID=$(gcloud config list --format 'value(core.project)')
    project_env=$(echo ${PROJECT_ID=} | cut -d'-' -f 4)
    
    #Mount home directory to GCStorage
    uid=$(id -u $user)
    gid=$(id -g $user)
    echo $uid
    fstabline=$( echo reports-main-bucket-test /home/${user} gcsfuse rw,_netdev,allow_other,nonempty,uid=${uid},gid=${gid},only_dir=${user})
    echo $fstabline
    
  if ! [[ "$user" =~ "cap-archive-v1" ]]
  then 
    if !(sudo grep -Fxq "$fstabline"  /etc/fstab)
    then
    sudo echo ${fstabline} >> /etc/fstab
    fi
  fi
  fi
done
sudo systemctl daemon-reload

#Mount GCSFuse manually
sudo mount -a

#Install Apache to give back 200 response back to health check probe
sudo yum install httpd -y
sudo systemctl enable httpd
sudo systemctl start httpd
sudo systemctl status httpd

sudo crontab -l | { cat; echo "0 */8 * * * sudo mv /home/cap-secret-v1/* /home/cap-archive-v1/"; } | crontab -
sudo crontab -l | { cat; echo "0 0 * * 0 sudo find /home/cap-archive-v1/* -mtime +7 -exec rm {} \;"; } | crontab -