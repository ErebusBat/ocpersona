if [[ -z ${OCP_PATH:-} ]]; then
  OCP_PATH=${${(%):-%x}:A:h:h}
fi

if [[ ! -x ${OCP_PATH}/bin/ocpersona ]]; then
  return
fi

eval "$(${OCP_PATH}/bin/ocpersona init zsh)"

alias ocp="${OCP_PATH}/bin/ocpersona"
ocp-on() {
  if [ "${1:-}" = "--unset" ]; then
    ocpersona activate --unset
  else
    ocpersona activate --local "$@"
  fi
}

ocp-off() {
  ocpersona deactivate
}
