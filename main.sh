#!/bin/bash
# set -ex

function dump_event(){ 
  echo "[${1}] ${2}" 
  [ ${ignore_errors} ] || exit 1
}

function usage(){
  echo "Please use as $0 user1 user2 user3 ..."
}

function get_bin_path(){
  path=$(which ${1}) 2>/dev/null
  if [[ "${?}" -ne 0 ]]
  then dump_event "Info" "Installing ${1}"
  ${package_menager} install ${1} -y 2>${output} >/dev/null || dump_event "Error" "Cant able to locate packages in repository"
  path=$(which ${1}) 2>/dev/null
  fi
}

debug_level=0
product_name=srelia
logdir=/var/log/${product_name}/
clone_path="/tmp/.${product_name}/cloned_repo"
clone_url="https://github.com/Vortexdude/${product_name}"
branch_name="main"
os_family=$(awk '/^ID=/' /etc/*-release | sed 's/ID=//' | tr '[:upper:]' '[:lower:]')
if [[ ${os_family} -eq 'ubuntu' ]]; then package_menager=apt; else package_menager=yum; fi
server=localhost
connection=local
ignore_errors=true
role=create_users

# ( set -o posix ; set ) | less

# for info in product_name logdir clone_path clone_url branch_name
# do
#   dump_event "Info" "${info} ${info}"
# done

if [[ "${debug_level}" -eq 0 ]]; then output="/dev/null"; else output=">${logdir}/error.log"; fi


function dump_event(){ 
  echo "[${1}] ${2}" 
  if [[ "${1}" -eq 'Error' ]]; then [ ${ignore_errors} ] || exit 1; fi
}

function usage(){
echo "Please use as ${0} user1 user2 user3 ..."
}

function clone_repo(){
  git clone -b ${branch_name} ${clone_url} ${clone_path} 2>${output} || dump_event "Error" "Can't able to clone the Repo check the logs at ${log_dir}"
}

function required_directories(){
  umask 77
  if [ -d ${clone_path} ]; then dump_event "Warning" "Directory Exist" && rm -rf ${clone_path} ${logdir}; else  mkdir -p ${clone_path} ${logdir}; fi
}

# exit from usages
if [[ "${#}" -lt 1 ]]; then usage && exit 1; fi

# installing ansible 
path=$(get_bin_path "ansible")

# set the defualt permissions
required_directories

#cloning github repo
clone_repo && dump_event "Info" "Cloning the repo ${clone_url} in the ${branch_name} branch "

# overwrring defaul variables
default_variable_file="${clone_path}/ansible/roles/${role}/defaults/main.yml"
echo "password_file_path: ${clone_path}" >${default_variable_file} 
echo "users: " >>${default_variable_file}
for name in "${@}"
do
cat << EOF >> ${default_variable_file}
  - { name: ${name}, password: ${name}, admin: true}
EOF
done

# run the ansible playbook
dump_event "Info" "Running Ansible playbook"
ansible-playbook ${clone_path}/ansible/${role}.yml -i ${server}, -c ${connection} 
[ "${?}" -eq 0 ] && dump_event "Info" "Succesfully created ${#} users - ${@}" ||  dump_event "Error" "There might be an issue with playbook "

cat ${clone_path}/password.txt || dump_event "Warning" "Passsword File doesn't exists"
# Deleting temprary files
[ -d ${clone_path} ] && dump_event "Info" "Deleting temprary files" && rm -rf ${clone_path} || dump_event "Error" "Permission denied"
