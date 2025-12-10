nvim_vm() {
  local host_prefix="/home/nx"
  local vm_prefix="/mnt/host"
  
  # 1. Handle Working Directory
  # Get absolute path of current directory on host
  local current_dir="${PWD:a}"
  # Map to VM path
  local vm_work_dir="${current_dir/$host_prefix/$vm_prefix}"

  # 2. Handle Arguments
  local mapped_args=()
  for arg in "$@"; do
    # Pass flags through untouched
    if [[ "$arg" == -* ]]; then
      mapped_args+=("$arg")
      continue
    fi

    # Resolve relative paths to absolute paths
    local abs_arg="${arg:a}"
    
    # Map absolute path to VM path
    mapped_args+=("${abs_arg/$host_prefix/$vm_prefix}")
  done

  # 3. Construct Remote Command
  # We construct a command string where arguments are safely quoted using ${(q)...}
  # This ensures spaces and special characters are handled correctly in the remote shell.
  # We 'cd' first so nvim opens in the correct context.
  local cmd="cd ${(q)vm_work_dir} && nvim"
  
  for arg in "${mapped_args[@]}"; do
    cmd+=" ${(q)arg}"
  done

  ssh -i /home/nx/.ssh/nvim-vm user@10.0.0.1 -t "$cmd"
}
