nvim_vm() {
  local host_prefix="/home/nx/nixos-config"
  local vm_prefix="/mnt/host"

  local current_dir="${PWD:a}"
  local vm_work_dir
  if [[ "$current_dir" == $host_prefix* ]]; then
    vm_work_dir="${current_dir/$host_prefix/$vm_prefix}"
  else
    vm_work_dir="/tmp"
  fi

  local mapped_args=()
  local tmp_files=()
  local host_files=()

  for arg in "$@"; do
    if [[ "$arg" == -* ]]; then
      mapped_args+=("$arg")
      continue
    fi

    local abs_arg="${arg:a}"
    local vm_arg
    if [[ "$abs_arg" == $host_prefix* ]]; then
      vm_arg="${abs_arg/$host_prefix/$vm_prefix}"
      if ! ssh -i /home/nx/.ssh/nvim-vm user@10.0.0.1 "[ -e ${(q)vm_arg} ]"; then
        echo "File $vm_arg is not mounted. Copying to /tmp on VM..."
        tmpfile="/tmp/$(basename "$abs_arg")"
        scp -i /home/nx/.ssh/nvim-vm "$abs_arg" user@10.0.0.1:"$tmpfile"
        mapped_args+=("$tmpfile")
        tmp_files+=("$tmpfile")
        host_files+=("$abs_arg")
      else
        mapped_args+=("$vm_arg")
      fi
    else
      tmpfile="/tmp/$(basename "$abs_arg")"
      echo "File $abs_arg is not mounted. Copying to /tmp on VM..."
      scp -i /home/nx/.ssh/nvim-vm "$abs_arg" user@10.0.0.1:"$tmpfile"
      mapped_args+=("$tmpfile")
      tmp_files+=("$tmpfile")
      host_files+=("$abs_arg")
    fi
  done

  local cmd="cd ${(q)vm_work_dir} && nvim"
  for arg in "${mapped_args[@]}"; do
    cmd+=" ${(q)arg}"
  done

  ssh -i /home/nx/.ssh/nvim-vm user@10.0.0.1 -t "$cmd"

  # TODO: Uncomment and fix the following section to copy files back from VM to host
  # # After nvim exits, copy files back from VM /tmp to host
  # for i in "${!tmp_files[@]}"; do
  #   vm_tmp="${tmp_files[$i]}"
  #   host_path="${host_files[$i]}"
  #   echo "Copying $vm_tmp back to $host_path..."
  #   scp -i /home/nx/.ssh/nvim-vm user@10.0.0.1:"$vm_tmp" "$host_path"
  # done
}
