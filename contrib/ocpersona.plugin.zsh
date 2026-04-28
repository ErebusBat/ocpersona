if [[ -z ${OCP_PATH:-} ]]; then
  OCP_PATH=${${(%):-%x}:A:h:h}
fi

if [[ ! -x ${OCP_PATH}/bin/ocpersona ]]; then
  return
fi

eval "$(${OCP_PATH}/bin/ocpersona init zsh)"

alias ocp="${OCP_PATH}/bin/ocpersona"
ocp-on() {
  ocpersona activate "$@"
}

ocp-off() {
  ocpersona deactivate
}
