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

temporary_parent_input="${TMPDIR-/tmp}"
while [[ "${temporary_parent_input}" != "/" && "${temporary_parent_input}" == */ ]]; do
	temporary_parent_input="${temporary_parent_input%/}"
done
readonly temporary_parent_input

if [[ -z "${temporary_parent_input}" ||
	! -d "${temporary_parent_input}" ||
	-L "${temporary_parent_input}" ||
	! -w "${temporary_parent_input}" ]]; then
	printf 'temporary parent is not a writable, non-symlink directory: %s\n' \
		"${temporary_parent_input}" >&2
	exit 1
fi

temporary_parent="$(
	cd -- "${temporary_parent_input}" || exit 1
	pwd -P
)"
readonly temporary_parent

if [[ -z "${temporary_parent}" || "${temporary_parent}" != /* ||
	! -d "${temporary_parent}" || -L "${temporary_parent}" ||
	! -w "${temporary_parent}" ]]; then
	printf 'failed to resolve a usable physical temporary parent: %s\n' \
		"${temporary_parent}" >&2
	exit 1
fi

readonly temporary_directory_prefix="candidate-codec-interop."
readonly temporary_suffix_bytes=10
readonly maximum_temporary_directory_attempts=64

temporary_dir=""
temporary_dir_created=0
temporary_sentinel=""
temporary_sentinel_created=0
temporary_owner=""
go_binary=""
go_build_started=0

cleanup() {
	local original_status=$?
	local cleanup_status=0
	local recorded_owner=""

	trap - EXIT

	if ((temporary_dir_created == 0)); then
		exit "${original_status}"
	fi

	if [[ -e "${temporary_dir}" || -L "${temporary_dir}" ]]; then
		if [[ ! -d "${temporary_dir}" || -L "${temporary_dir}" ]]; then
			printf 'refusing to clean unverified temporary path %s\n' \
				"${temporary_dir}" >&2
			cleanup_status=1
		fi

		if ((cleanup_status == 0 && temporary_sentinel_created != 0)); then
			if [[ ! -f "${temporary_sentinel}" || -L "${temporary_sentinel}" ]] ||
				! IFS= read -r recorded_owner <"${temporary_sentinel}" ||
				[[ "${recorded_owner}" != "${temporary_owner}" ]]; then
				printf 'refusing to clean temporary directory with invalid ownership sentinel %s\n' \
					"${temporary_dir}" >&2
				cleanup_status=1
			elif ((go_build_started != 0)) &&
				[[ -e "${go_binary}" || -L "${go_binary}" ]] &&
				! rm -f -- "${go_binary}"; then
				printf 'failed to remove known Go binary %s\n' \
					"${go_binary}" >&2
				cleanup_status=1
			fi

			if ((cleanup_status == 0)) &&
				! rm -f -- "${temporary_sentinel}"; then
				printf 'failed to remove temporary ownership sentinel %s\n' \
					"${temporary_sentinel}" >&2
				cleanup_status=1
			fi
		fi

		if ((cleanup_status == 0)) &&
			! rmdir -- "${temporary_dir}"; then
			printf 'temporary directory contains an unknown entry or could not be removed: %s\n' \
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

create_owned_temporary_directory() {
	local attempt
	local candidate
	local mkdir_status
	local suffix

	for ((attempt = 1; attempt <= maximum_temporary_directory_attempts; attempt++)); do
		if ! suffix="$(
			od -An -N "${temporary_suffix_bytes}" -tx1 /dev/urandom |
				tr -d '[:space:]'
		)"; then
			printf 'failed to generate a temporary directory suffix\n' >&2
			return 1
		fi

		if [[ ! "${suffix}" =~ ^[0-9a-f]{20}$ ]]; then
			printf 'temporary directory suffix is empty, partial, or malformed\n' >&2
			return 1
		fi

		candidate="${temporary_parent}/${temporary_directory_prefix}${suffix}"
		if mkdir --mode=700 -- "${candidate}"; then
			temporary_dir="${candidate}"
			temporary_dir_created=1
			return 0
		else
			mkdir_status=$?
		fi

		if [[ -e "${candidate}" || -L "${candidate}" ]]; then
			continue
		fi

		printf 'failed to create temporary directory %s\n' \
			"${candidate}" >&2
		return "${mkdir_status}"
	done

	printf 'failed to create a unique temporary directory after %d attempts\n' \
		"${maximum_temporary_directory_attempts}" >&2
	return 1
}

umask 077
create_owned_temporary_directory
readonly temporary_dir
readonly temporary_dir_created

if [[ -z "${temporary_dir}" || "${temporary_dir}" != /* ]]; then
	printf 'created temporary directory is not a non-empty absolute path\n' >&2
	exit 1
fi

temporary_name="${temporary_dir##*/}"
temporary_returned_parent="${temporary_dir%/*}"
if [[ -z "${temporary_returned_parent}" ]]; then
	temporary_returned_parent="/"
fi
readonly temporary_name
readonly temporary_returned_parent

if [[ "${temporary_returned_parent}" != "${temporary_parent}" ||
	! "${temporary_name}" =~ ^candidate-codec-interop\.[0-9a-f]{20}$ ||
	! -d "${temporary_dir}" || -L "${temporary_dir}" ]]; then
	printf 'created an untrusted temporary directory path: %s\n' \
		"${temporary_dir}" >&2
	exit 1
fi

temporary_dir_canonical="$(
	cd -- "${temporary_dir}" || exit 1
	pwd -P
)"
readonly temporary_dir_canonical

if [[ "${temporary_dir_canonical}" != "${temporary_dir}" ]]; then
	printf 'created a non-canonical temporary directory path: %s\n' \
		"${temporary_dir}" >&2
	exit 1
fi

temporary_uid="$(stat -c '%u' -- "${temporary_dir}")"
readonly temporary_uid

temporary_mode="$(stat -c '%a' -- "${temporary_dir}")"
readonly temporary_mode

if [[ "${temporary_uid}" != "${EUID}" ]]; then
	printf 'temporary directory owner %s does not match effective UID %s\n' \
		"${temporary_uid}" \
		"${EUID}" >&2
	exit 1
fi

if [[ ! "${temporary_mode}" =~ ^[0-7]{3,4}$ ]] ||
	((8#${temporary_mode} & 077)); then
	printf 'temporary directory permissions are not private: %s\n' \
		"${temporary_mode}" >&2
	exit 1
fi

shopt -s dotglob nullglob
temporary_initial_entries=("${temporary_dir}"/*)
shopt -u dotglob nullglob

if ((${#temporary_initial_entries[@]} != 0)); then
	printf 'temporary directory was not initially empty: %s\n' \
		"${temporary_dir}" >&2
	exit 1
fi

go_binary="${temporary_dir}/candidate-codec-go"
readonly go_binary
temporary_sentinel="${temporary_dir}/.candidate-codec-interop-owner"
readonly temporary_sentinel
temporary_owner="candidate-codec-interop:${BASHPID}:${temporary_dir}"
readonly temporary_owner

if ! (
	set -o noclobber
	printf '%s\n' "${temporary_owner}" >"${temporary_sentinel}"
); then
	printf 'failed to write ownership sentinel in temporary directory %s\n' \
		"${temporary_dir}" >&2
	exit 1
fi
temporary_sentinel_created=1

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

fixtures=("${fixture_dir}"/*.json)

if [[ ! -e "${fixtures[0]}" ]]; then
	printf 'no seed fixtures found in %s\n' \
		"${fixture_dir}" >&2
	exit 1
fi

go_build_started=1
(
	cd -- "${go_dir}" || exit 1
	go build -o "${go_binary}" ./cmd/candidate-codec
)

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
