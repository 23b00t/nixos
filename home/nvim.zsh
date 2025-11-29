nvim_vm() {
  local host_prefix="/home/nx/"
  local vm_prefix="/mnt/host/"
  local args=()

  if [ $# -eq 0 ]; then
    args=()
  else
    args=("$@")
  fi

  local mapped=()
  for arg in "${args[@]}"; do
    mapped+=("${arg/$host_prefix/$vm_prefix}")
  done

  ssh -i /home/nx/.ssh/nvim-vm user@10.0.0.1 -t nvim "${mapped[@]}"
}
