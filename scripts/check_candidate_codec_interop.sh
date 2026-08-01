#!/usr/bin/env bash
set -euo pipefail

readonly artifact_status="CANDIDATO NO NORMATIVO"

script_dir="$(
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1
	pwd
)"
readonly script_dir

repository_root="$(
	cd -- "${script_dir}/.." || exit 1
	pwd
)"
readonly repository_root

readonly go_dir="${repository_root}/implementations/go-fxamacker"
readonly python_codec="${repository_root}/implementations/python-manual/candidate_codec.py"
readonly fixture_dir="${repository_root}/testdata/adr001-candidate/seed-positive"

temporary_dir="$(mktemp -d)"
readonly temporary_dir

if [[ -z "${temporary_dir}" || ! -e "${temporary_dir}" || ! -d "${temporary_dir}" ]]; then
	printf 'mktemp did not create a usable directory\n' >&2
	exit 1
fi

readonly temporary_sentinel="${temporary_dir}/.candidate-codec-interop-owner"
readonly temporary_owner="candidate-codec-interop:${BASHPID}:${temporary_dir}"

if ! (
	umask 077
	set -o noclobber
	printf '%s\n' "${temporary_owner}" >"${temporary_sentinel}"
); then
	printf 'failed to establish ownership of temporary directory %s\n' \
		"${temporary_dir}" >&2
	rmdir -- "${temporary_dir}" 2>/dev/null || true
	exit 1
fi

cleanup() {
	local original_status=$?
	local cleanup_status=0
	local recorded_owner=""

	trap - EXIT

	if [[ -e "${temporary_dir}" ]]; then
		if [[ ! -d "${temporary_dir}" || ! -f "${temporary_sentinel}" ]]; then
			printf 'refusing to remove unverified temporary path %s\n' \
				"${temporary_dir}" >&2
			cleanup_status=1
		elif ! IFS= read -r recorded_owner <"${temporary_sentinel}" ||
			[[ "${recorded_owner}" != "${temporary_owner}" ]]; then
			printf 'refusing to remove temporary directory with invalid ownership sentinel %s\n' \
				"${temporary_dir}" >&2
			cleanup_status=1
		elif ! rm -rf -- "${temporary_dir}"; then
			printf 'failed to remove temporary directory %s\n' \
				"${temporary_dir}" >&2
			cleanup_status=1
		fi
	fi

	if ((original_status != 0)); then
		exit "${original_status}"
	fi
	exit "${cleanup_status}"
}
trap cleanup EXIT

source_commit="$(
	git -C "${repository_root}" rev-parse HEAD
)"
readonly source_commit

working_tree_output="$(
	git -C "${repository_root}" \
		status --porcelain --untracked-files=all
)"
readonly working_tree_output

if [[ -z "${working_tree_output}" ]]; then
	working_tree_state="clean"
else
	working_tree_state="dirty"
fi
readonly working_tree_state

readonly go_binary="${temporary_dir}/candidate-codec-go"

(
	cd -- "${go_dir}" || exit 1
	go build -o "${go_binary}" ./cmd/candidate-codec
)

environment_description="$(uname -srmo)"
readonly environment_description

go_version="$(go version)"
readonly go_version

python_version="$(python3 --version 2>&1)"
readonly python_version

dependency="$(
	cd -- "${go_dir}" || exit 1
	go list -m \
		-f '{{.Path}}@{{.Version}}' \
		github.com/fxamacker/cbor/v2
)"
readonly dependency

printf '%s | environment | %s\n' \
	"${artifact_status}" \
	"${environment_description}"

printf '%s | environment | %s\n' \
	"${artifact_status}" \
	"${go_version}"

printf '%s | environment | %s\n' \
	"${artifact_status}" \
	"${python_version}"

printf '%s | source_commit | %s\n' \
	"${artifact_status}" \
	"${source_commit}"

printf '%s | working_tree | %s\n' \
	"${artifact_status}" \
	"${working_tree_state}"

printf '%s | dependency | %s\n' \
	"${artifact_status}" \
	"${dependency}"

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

	if [[ ! "${value}" =~ ^[0-9a-f]+$ ]] ||
		(("${#value}" % 2 != 0)); then
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
		"${fixture##*/}" \
		"${go_first}"
done

printf '%s | interop | %d/%d seed fixtures matched byte for byte and repeated identically\n' \
	"${artifact_status}" \
	"${#fixtures[@]}" \
	"${#fixtures[@]}"
