#!/bin/bash

# This script should support any puppet releases that are available at either apt.puppetlabs.com
#   or at yum.puppetlabs.com for Debian- and RedHat-based systems
#
# This script has been tested on:
# Ubuntu 16.04 (Xenial)
# RHEL/CentOS 7.x
# Fedora 23
# Debian 8 (Jessie), 9 (Stretch)


# Init variables
AFTER_SCRIPT="" # Script to run immediately following the first puppet run
BEFORE_SCRIPT="" # Script to run before the first puppet run
CONF_PATH="/etc/puppetlabs/puppet/puppet.conf" # The puppet agent config file
DISABLE="0" # If set to 1, this will stop and disable the puppet service
ENVIRONMENT="" # You can specify an environment to use; leaving this blank will use the default
EXEC_PATH="/opt/puppetlabs/bin/puppet" # Path the puppet executable
PKG_NAME="" # Name of the puppet package to install
PUPPET_SERVER="" # Puppet master server
REPO="0" # Setting this to 1 will install puppet from OS's package repo
WAITFORCERT="30" # Tells puppet to wait n number of seconds for the server certficate signing

# Get the options passed to the script
while getopts ":a:b:c:de:p:rs:x:w:" opt; do
  case $opt in
    a)
      # Set the after script
      AFTER_SCRIPT="$OPTARG"
      ;;
    b)
      # Set the before script
      BEFORE_SCRIPT="$OPTARG"
      ;;
    c)
      # Set the puppet config path
      CONF_PATH="$OPTARG"
      ;;
    d)
      # Disable puppet service
      DISABLE="1"
      ;;
    e)
      # Set the puppet environment
      ENVIRONMENT="$OPTARG"
      ;;
    p)
      # Set the package name to install
      PKG_NAME="$OPTARG"
      ;;
    r)
      # Use the puppet package found in the system's repos
      REPO="1"
      ;;
    s)
      # Set the puppet server
      PUPPET_SERVER="$OPTARG"
      ;;
    x)
      # Set the pupept executable path
      EXEC_PATH="$OPTARG"
      ;;
    w)
      # Tells puppet to not wait for cert
      WAITFORCERT="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done


# check the OS version only if we're not using the default repo version
if [ "$REPO" != "1" ]; then
  # Set the puppet executable path if it's not already set
  if [ "$EXEC_PATH" != "" ]; then
    EXEC_PATH="/opt/puppetlabs/bin/puppet"
  fi
  # Set the puppet package name if it's not already set
  if [ "$PKG_NAME" != "" ]; then
    PKG_NAME="puppet-agent"
  fi

  # Determine version, update software, install puppet
  if [ -f /etc/lsb-release ]; then
      . /etc/lsb-release
      OS=$DISTRIB_ID
      VER=$DISTRIB_RELEASE
      SUB=$DISTRIB_CODENAME

      # Ubuntu update & puppet install
      wget https://apt.puppetlabs.com/puppetlabs-release-pc1-$SUB.deb
      dpkg -i puppetlabs-release-pc1-$SUB.deb
      apt-get update
      apt-get -y install puppet-agent
  elif [ -f /etc/debian_version ]; then
      VER=$(cat /etc/debian_version | cut -d '.' -f 1)

      if [ $VER = 7 ]; then
        SUB="wheezy"
      elif [ $VER = 8 ]; then
        SUB="jessie"
      elif [ $VER = 9 ]; then
        SUB="stretch"
      fi

      # Debian update & puppet install
      if [ SUB ]; then
        wget https://apt.puppetlabs.com/puppetlabs-release-pc1-$SUB.deb
        dpkg -i puppetlabs-release-pc1-$SUB.deb
        apt-get update
        apt-get -y install puppet-agent
      fi
  elif [ -f /etc/fedora-release ]; then
      OS=fedora
      VER=$(awk '/release/ {split($3,a,"."); print a[1];}' /etc/fedora-release)

      # Fedora update & puppet install
      wget https://yum.puppetlabs.com/puppetlabs-release-pc1-fedora-$VER.noarch.rpm
      rpm -Uvh puppetlabs-release-pc1-fedora-$VER.noarch.rpm
      yum update -y
      yum install -y puppet-agent
  elif [ -f /etc/redhat-release ]; then
      OS=rhel
      # Check if it's Red Hat < 7
      VER=$(awk '/release/ {split($3,a,"."); print a[1];}' /etc/redhat-release)
      # If it's Red Hat 7 (or possibly newer) then it will be "release" because redhat-release changed slightly
      if [ "$VER" == 'release' ]; then
        VER=$(awk '/release/ {split($4,a,"."); print a[1];}' /etc/redhat-release)
      fi

      # RHEL CentOS update & puppet install
      wget https://yum.puppetlabs.com/puppetlabs-release-pc1-el-$VER.noarch.rpm
      rpm -Uvh puppetlabs-release-pc1-el-$VER.noarch.rpm
      yum update -y
      yum install -y puppet-agent
  fi
else
  # Set the puppet executable path if it's not already set
  if [ "$EXEC_PATH" != "" ]; then
    EXEC_PATH="/usr/bin/puppet"
  fi
  # Set the puppet package name if it's not already set
  if [ "$PKG_NAME" != "" ]; then
    PKG_NAME="puppet"
  fi
fi


# Configure Puppet to talk to our puppet server
cat >> "$CONF_PATH" <<EOF
[agent]
server = $PUPPET_SERVER
EOF
# Append the environment to the puppet config file if it's specified
if [ "$ENVIRONMENT" != "" ]; then
  echo "environment = $ENVIRONMENT" >> "$CONF_PATH"
fi

# Run any custom init script before starting puppet
if [ -f "$BEFORE_SCRIPT" ] && [ "$BEFORE_SCRIPT" != "" ]; then
  . "$BEFORE_SCRIPT"
fi

# Enable the puppet agent
"$EXEC_PATH" agent --enable

# Disable puppet service
if [ "$DISABLE" == "1" ]; then
  systemctl stop puppet
  systemctl disable puppet
fi

# Build our puppet command
PUPPET_CMD="$EXEC_PATH agent -t"
if [ "$WAITFORCERT" != "0" ]; then
  PUPPET_CMD="$PUPPET_CMD -w $WAITFORCERT "
fi

# Run the puppet agent
$PUPPET_CMD

# Run any custom script after starting puppet
if [ -f "$AFTER_SCRIPT" ] && [ "$AFTER_SCRIPT" != "" ]; then
  . "$AFTER_SCRIPT"
fi

exit 0
