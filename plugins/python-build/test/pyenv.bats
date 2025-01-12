#!/usr/bin/env bats

load test_helper
export PYENV_ROOT="${TMP}/pyenv"

setup() {
  stub pyenv-hooks 'install : true'
  stub pyenv-rehash 'true'
}

stub_python_build() {
  stub python-build "--lib : $BATS_TEST_DIRNAME/../bin/python-build --lib" "$@"
  stub pyenv-latest ": false"
}

@test "install proper" {
  stub_python_build 'echo python-build "$@"'

  run pyenv-install 3.4.2
  assert_success "python-build 3.4.2 ${PYENV_ROOT}/versions/3.4.2"

  unstub python-build
  unstub pyenv-hooks
  unstub pyenv-rehash
}

@test "install proper multi versions" {
  #stub python-build "--lib : $BATS_TEST_DIRNAME/../bin/python-build --lib" 'echo python-build "$@"' 'echo python-build "$@"'
  #stub pyenv-latest ": false" ": false"
  stub_python_build 'echo python-build "$@"' 'echo python-build "$@"'
  stub pyenv-latest ": false"
  stub pyenv-rehash 'true'

  run pyenv-install 3.4.1 3.4.2
  assert_success
  assert_output <<OUT
python-build 3.4.1 ${TMP}/pyenv/versions/3.4.1
python-build 3.4.2 ${TMP}/pyenv/versions/3.4.2
OUT

  unstub python-build
  unstub pyenv-latest
  unstub pyenv-hooks
  unstub pyenv-rehash
}

@test "install resolves a prefix" {
  stub_python_build 'echo python-build "$@"'
  stub pyenv-latest '-q -k 3.4 : echo 3.4.2'
  pyenv-latest || true  # pass through the stub entry added by stub_python_build

  run pyenv-install 3.4
  assert_success "python-build 3.4.2 ${PYENV_ROOT}/versions/3.4.2"

  unstub python-build
  unstub pyenv-hooks
  unstub pyenv-rehash
}

@test "install resolves a prefix with multi versions" {
  stub_python_build 'echo python-build "$@"' 'echo python-build "$@"'
  stub pyenv-latest '-q -k 3.4 : echo 3.4.2' '-q -k 3.5 : echo 3.5.2'
  stub pyenv-rehash 'true'
  pyenv-latest || true  # pass through the stub entry added by stub_python_build

  run pyenv-install 3.4 3.5
  assert_success <<OUT
python-build 3.4.2 ${PYENV_ROOT}/versions/3.4.2
python-build 3.5.2 ${PYENV_ROOT}/versions/3.5.2
OUT


  unstub python-build
  unstub pyenv-hooks
  unstub pyenv-rehash
}

@test "install pyenv local version by default" {
  stub_python_build 'echo python-build "$1"'
  stub pyenv-local 'echo 3.4.2'

  run pyenv-install
  assert_success "python-build 3.4.2"

  unstub python-build
  unstub pyenv-local
}

@test "install pyenv local multi versions by default" {
  stub_python_build 'echo python-build "$1"' 'echo python-build "$1"'
  stub pyenv-local 'printf "%s\n%s\n" 3.4.2 3.4.1'
  stub pyenv-latest ": false"

  run pyenv-install
  assert_success <<OUT
python-build 3.4.2"
python-build 3.4.1"
OUT

  unstub python-build
  unstub pyenv-local
}

@test "list available versions" {
  stub_python_build \
    "--definitions : echo 2.6.9 2.7.9-rc1 2.7.9-rc2 3.4.2 | tr ' ' $'\\n'"

  run pyenv-install --list
  assert_success
  assert_output <<OUT
Available versions:
  2.6.9
  2.7.9-rc1
  2.7.9-rc2
  3.4.2
OUT

  unstub python-build
}

@test "nonexistent version" {
  stub brew false
  stub_python_build 'echo ERROR >&2 && exit 2' \
    "--definitions : echo 2.6.9 2.7.9-rc1 2.7.9-rc2 3.4.2 | tr ' ' $'\\n'"

  run pyenv-install 2.7.9
  assert_failure
  assert_output <<OUT
ERROR

The following versions contain \`2.7.9' in the name:
  2.7.9-rc1
  2.7.9-rc2

See all available versions with \`pyenv install --list'.

If the version you need is missing, try upgrading pyenv:

  cd ${BATS_TEST_DIRNAME}/../../.. && git pull && cd -
OUT

  unstub python-build
}

@test "Homebrew upgrade instructions" {
  stub brew "--prefix : echo '${BATS_TEST_DIRNAME%/*}'"
  stub_python_build 'echo ERROR >&2 && exit 2' \
    "--definitions : true"

  run pyenv-install 1.9.3
  assert_failure
  assert_output <<OUT
ERROR

See all available versions with \`pyenv install --list'.

If the version you need is missing, try upgrading pyenv:

  brew update && brew upgrade pyenv
OUT

  unstub brew
  unstub python-build
}

@test "no build definitions from plugins" {
  assert [ ! -e "${PYENV_ROOT}/plugins" ]
  stub_python_build 'echo $PYTHON_BUILD_DEFINITIONS'

  run pyenv-install 3.4.2
  assert_success ""
}

@test "some build definitions from plugins" {
  mkdir -p "${PYENV_ROOT}/plugins/foo/share/python-build"
  mkdir -p "${PYENV_ROOT}/plugins/bar/share/python-build"
  stub_python_build "echo \$PYTHON_BUILD_DEFINITIONS | tr ':' $'\\n'"

  run pyenv-install 3.4.2
  assert_success
  assert_output <<OUT

${PYENV_ROOT}/plugins/bar/share/python-build
${PYENV_ROOT}/plugins/foo/share/python-build
OUT
}

@test "list build definitions from plugins" {
  mkdir -p "${PYENV_ROOT}/plugins/foo/share/python-build"
  mkdir -p "${PYENV_ROOT}/plugins/bar/share/python-build"
  stub_python_build "--definitions : echo \$PYTHON_BUILD_DEFINITIONS | tr ':' $'\\n'"

  run pyenv-install --list
  assert_success
  assert_output <<OUT
Available versions:
  
  ${PYENV_ROOT}/plugins/bar/share/python-build
  ${PYENV_ROOT}/plugins/foo/share/python-build
OUT
}

@test "completion results include build definitions from plugins" {
  mkdir -p "${PYENV_ROOT}/plugins/foo/share/python-build"
  mkdir -p "${PYENV_ROOT}/plugins/bar/share/python-build"
  stub python-build "--definitions : echo \$PYTHON_BUILD_DEFINITIONS | tr ':' $'\\n'"

  run pyenv-install --complete
  assert_success
  assert_output <<OUT
--list
--force
--skip-existing
--keep
--patch
--verbose
--version
--debug

${PYENV_ROOT}/plugins/bar/share/python-build
${PYENV_ROOT}/plugins/foo/share/python-build
OUT
}

@test "not enough arguments for pyenv-install if no local version" {
  stub_python_build
  stub pyenv-help 'install : true'

  run pyenv-install
  assert_failure
  unstub pyenv-help
  assert_output ""
}

@test "multi arguments for pyenv-install" {
  stub_python_build
  stub pyenv-help 'install : true'

  run pyenv-install 3.4.1 3.4.2
  assert_success
  assert_output ""
}

@test "show help for pyenv-install" {
  stub_python_build
  stub pyenv-help 'install : true'

  run pyenv-install -h
  assert_success
  unstub pyenv-help
}

@test "pyenv-install has usage help preface" {
  run head "$(command -v pyenv-install)"
  assert_output_contains 'Usage: pyenv install'
}

@test "not enough arguments pyenv-uninstall" {
  stub pyenv-help 'uninstall : true'

  run pyenv-uninstall
  assert_failure
  unstub pyenv-help
}

@test "more than one argument for pyenv-uninstall" {
  mkdir -p "${PYENV_ROOT}/versions/3.4.1"
  mkdir -p "${PYENV_ROOT}/versions/3.4.2"
  run pyenv-uninstall -f 3.4.1 3.4.2

  assert_success
  refute [ -d "${PYENV_ROOT}/versions/3.4.1" ]
  refute [ -d "${PYENV_ROOT}/versions/3.4.2" ]
}

@test "invalid arguments for pyenv-uninstall" {
  mkdir -p "${PYENV_ROOT}/versions/3.10.3"
  mkdir -p "${PYENV_ROOT}/versions/3.10.4"

  run pyenv-uninstall -f 3.10.3 --invalid-option 3.10.4
  assert_failure

  assert [ -d "${PYENV_ROOT}/versions/3.10.3" ]
  assert [ -d "${PYENV_ROOT}/versions/3.10.4" ]

  rmdir "${PYENV_ROOT}/versions/3.10.3"
  rmdir "${PYENV_ROOT}/versions/3.10.4"
}

@test "show help for pyenv-uninstall" {
  stub pyenv-help 'uninstall : true'

  run pyenv-uninstall -h
  assert_success
  unstub pyenv-help
}

@test "pyenv-uninstall has usage help preface" {
  run head "$(command -v pyenv-uninstall)"
  assert_output_contains 'Usage: pyenv uninstall'
}
