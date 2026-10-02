# Internal protocol: expiry epoch, then token. Shell hooks capture both lines;
# never invoke this helper directly in a terminal or log its output.
set -euo pipefail
unset BUILDKITE_API_TOKEN
export BUILDKITE_ORGANIZATION_SLUG=openai-mono

command -v bk >/dev/null 2>&1 || exit 1
# auth token only reads the store. An API request performs OAuth refresh on 401.
buildkite_status=$(timeout 10 bk --no-input auth status --json 2>/dev/null)
buildkite_expiry=$(printf '%s' "$buildkite_status" | jq -er '
  .token.expires_at | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601
')
buildkite_token=$(timeout 5 bk --no-input auth token 2>/dev/null)
test -n "$buildkite_token"
printf '%s\n%s\n' "$buildkite_expiry" "$buildkite_token"
