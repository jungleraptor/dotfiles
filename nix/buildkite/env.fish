function buildkite_refresh --description 'Refresh exported Buildkite OAuth credentials'
    set -l buildkite_now (date +%s)
    if not contains -- --force $argv; and set -q BUILDKITE_API_KEY DOTFILES_BUILDKITE_EXPIRES_AT
        if test "$buildkite_now" -lt "$DOTFILES_BUILDKITE_EXPIRES_AT"
            return 0
        end
    end
    set -l buildkite_values ("$HOME/.nix-profile/bin/dotfiles-buildkite-token")
    if test $status -ne 0; or test (count $buildkite_values) -ne 2
        set -e BUILDKITE_API_KEY BUILDKITE_TOKEN DOTFILES_BUILDKITE_EXPIRES_AT
        return 1
    end
    if test -z "$buildkite_values[2]"; or not test "$buildkite_values[1]" -gt "$buildkite_now"
        set -e BUILDKITE_API_KEY BUILDKITE_TOKEN DOTFILES_BUILDKITE_EXPIRES_AT
        return 1
    end
    set -gx BUILDKITE_API_KEY "$buildkite_values[2]"
    set -gx BUILDKITE_TOKEN "$buildkite_values[2]"
    set -gx DOTFILES_BUILDKITE_EXPIRES_AT "$buildkite_values[1]"
    set -e BUILDKITE_API_TOKEN
end

function __dotfiles_buildkite_preexec --on-event fish_preexec
    buildkite_refresh 2>/dev/null
end

# Check independently of inherited values or machine-local overrides.
buildkite_refresh --force 2>/dev/null; or true
