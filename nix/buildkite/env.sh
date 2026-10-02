# Sourced after machine-owned startup files by Bash login shells (including Codex).
buildkite_refresh() {
    local buildkite_now buildkite_values buildkite_expiry buildkite_token
    buildkite_now=$(date +%s)
    if [ "${1:-}" != --force ] && [ -n "${BUILDKITE_API_KEY:-}" ] &&
        [ "$buildkite_now" -lt "${DOTFILES_BUILDKITE_EXPIRES_AT:-0}" ] 2>/dev/null; then
        return 0
    fi
    if ! buildkite_values=$("$HOME/.nix-profile/bin/dotfiles-buildkite-token"); then
        unset BUILDKITE_API_KEY BUILDKITE_TOKEN DOTFILES_BUILDKITE_EXPIRES_AT
        return 1
    fi
    buildkite_expiry=${buildkite_values%%$'\n'*}
    buildkite_token=${buildkite_values#*$'\n'}
    if [ -z "$buildkite_token" ] || ! [ "$buildkite_expiry" -gt "$buildkite_now" ] 2>/dev/null; then
        unset BUILDKITE_API_KEY BUILDKITE_TOKEN DOTFILES_BUILDKITE_EXPIRES_AT
        return 1
    fi
    export BUILDKITE_API_KEY="$buildkite_token"
    export BUILDKITE_TOKEN="$buildkite_token"
    export DOTFILES_BUILDKITE_EXPIRES_AT="$buildkite_expiry"
    # An inherited override would prevent bk from refreshing its stored OAuth token.
    unset BUILDKITE_API_TOKEN
}

# Always check at startup: the OpenAI loader may have replaced inherited values.
buildkite_refresh --force 2>/dev/null || :
