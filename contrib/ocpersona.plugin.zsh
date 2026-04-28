if [[ -z ${OCP_PATH:-} ]]; then
  OCP_PATH=${${(%):-%x}:A:h:h}
fi

if [[ ! -x ${OCP_PATH}/bin/ocpersona ]]; then
  return
fi

eval "$(${OCP_PATH}/bin/ocpersona init zsh)"

ocp-on() {
  ocpersona activate "$@"
}

ocp-off() {
  ocpersona deactivate
}
