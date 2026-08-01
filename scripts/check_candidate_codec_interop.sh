#!/usr/bin/env bash
set -euo pipefail

readonly artifact_status="CANDIDATO NO NORMATIVO"
readonly script_dir="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd
)"
readonly repository_root="$(
    cd -- "${script_dir}/.."
    pwd
)"
readonly go_dir="${repository_root}/implementations/go-fxamacker"
readonly python_codec="${repository_root}/implementations/python-manual/candidate_codec.py"
readonly fixture_dir="${repository_root}/testdata/adr001-candidate/seed-positive"
readonly temporary_dir="$(mktemp -d)"
readonly source_commit="$(
    git -C "${repository_root}" rev-parse HEAD
)"

if [[ -z "$(
    git -C "${repository_root}" \
        status --porcelain --untracked-files=all
)" ]]; then
    working_tree_state="clean"
else
    working_tree_state="dirty"
fi
readonly working_tree_state

cleanup() {
    if [[ -n "${temporary_dir}" && "${temporary_dir}" == /tmp/* ]]; then
        rm -rf -- "${temporary_dir}"
    fi
}
trap cleanup EXIT

readonly go_binary="${temporary_dir}/candidate-codec-go"

(
    cd -- "${go_dir}"
    go build -o "${go_binary}" ./cmd/candidate-codec
)

printf '%s | environment | %s\n' \
    "${artifact_status}" \
    "$(uname -srmo)"

printf '%s | environment | %s\n' \
    "${artifact_status}" \
    "$(go version)"

printf '%s | environment | %s\n' \
    "${artifact_status}" \
    "$(python3 --version 2>&1)"

printf '%s | source_commit | %s\n' \
    "${artifact_status}" \
    "${source_commit}"

printf '%s | working_tree | %s\n' \
    "${artifact_status}" \
    "${working_tree_state}"

printf '%s | dependency | %s\n' \
    "${artifact_status}" \
    "$(
        cd -- "${go_dir}"
        go list -m \
            -f '{{.Path}}@{{.Version}}' \
            github.com/fxamacker/cbor/v2
    )"

fixtures=("${fixture_dir}"/*.json)

if [[ ! -e "${fixtures[0]}" ]]; then
    printf 'no seed fixtures found in %s\n' \
        "${fixture_dir}" >&2
    exit 1
fi

validate_hex() {
    local producer="$1"
    local fixture="$2"
    local value="$3"

    if [[ ! "${value}" =~ ^[0-9a-f]+$ ]] \
        || (( ${#value} % 2 != 0 )); then
        printf '%s produced non-lowercase-hex output for %s: %q\n' \
            "${producer}" \
            "${fixture}" \
            "${value}" >&2
        exit 1
    fi
}

for fixture in "${fixtures[@]}"; do
    go_first="$("${go_binary}" "${fixture}")"
    go_second="$("${go_binary}" "${fixture}")"

    python_first="$(
        python3 "${python_codec}" "${fixture}"
    )"
    python_second="$(
        python3 "${python_codec}" "${fixture}"
    )"

    validate_hex \
        "go-fxamacker" \
        "${fixture}" \
        "${go_first}"

    validate_hex \
        "python-manual" \
        "${fixture}" \
        "${python_first}"

    if [[ "${go_first}" != "${go_second}" ]]; then
        printf 'go-fxamacker is not repeatable for %s\n' \
            "${fixture}" >&2
        exit 1
    fi

    if [[ "${python_first}" != "${python_second}" ]]; then
        printf 'python-manual is not repeatable for %s\n' \
            "${fixture}" >&2
        exit 1
    fi

    if [[ "${go_first}" != "${python_first}" ]]; then
        printf 'candidate byte mismatch for %s\n' \
            "${fixture}" >&2
        printf 'go-fxamacker: %s\n' \
            "${go_first}" >&2
        printf 'python-manual: %s\n' \
            "${python_first}" >&2
        exit 1
    fi

    printf '%s | %s | %s\n' \
        "${artifact_status}" \
        "$(basename -- "${fixture}")" \
        "${go_first}"
done

printf '%s | interop | %d/%d seed fixtures matched byte for byte and repeated identically\n' \
    "${artifact_status}" \
    "${#fixtures[@]}" \
    "${#fixtures[@]}"
