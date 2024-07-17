#! /usr/bin/env nix-shell
#! nix-shell -i /bin/sh -p findutils

show_help() {
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  strays       List strays (use --different to show different ones)"
    echo "  ephemeral    List ephemeral (use --root <path> to specify root)"
}

if [[ "$*" == *"--help"* || $# -lt 1 ]]; then
    show_help
    exit 0
fi

command="$1"
shift

search_paths=""
exclude_paths=""
find_options=""

case "$command" in
    ephemeral)
        os=false
        home=false
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --os)
                    os=true
                    shift
                    ;;
                --home)
                    home=true
                    shift
                    ;;
                *)
                    echo "Error: Invalid option '$1' for 'ephemeral'"
                    echo
                    show_help
                    exit 1
                    ;;
            esac
        done

        if [[ "$os" == false && "$home" == false ]]; then
            os=true
            home=true
        fi

        if [ "$os" = true ]; then
            search_paths+=$EPHT_SEARCH_ROOT
            exclude_paths+=$EPHT_EXCLUDE_ROOT
        fi

        if [[ $os && $home ]]; then
            search_path+=":"
        fi

        if [ "$home" = true ]; then
            search_paths+=$EPHT_SEARCH_HOME
            exclude_paths+=$EPHT_EXCLUDE_HOME
        fi

        find_options="-type f -print"
        ;;
    strays)
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --os)
                    os=true
                    shift
                    ;;
                --home)
                    home=true
                    shift
                    ;;
                *)
                    echo "Error: Invalid option '$1' for 'ephemeral'"
                    echo
                    show_help
                    exit 1
                    ;;
            esac
        done

        if [[ "$os" == false && "$home" == false ]]; then
            os=true
            home=true
        fi

        if [ "$os" = true ]; then
            search_paths+=$EPHT_SEARCH_P_ROOT
            exclude_paths+=$EPHT_EXCLUDE_P_ROOT
        fi

        if [[ $os && $home ]]; then
            search_path+=":"
        fi

        if [ "$home" = true ]; then
            search_paths+=$EPHT_SEARCH_P_HOME
            exclude_paths+=$EPHT_EXCLUDE_P_HOME
        fi

        find_options="\( -empty -type d -print \) -o \( -type f -print \)"
        ;;
    *)
        echo "Error: Unknown command '$command'."
        echo
        show_help
        exit 1
        ;;
esac

find_command="find"

IFS=":"

for path in $search_paths; do
    find_command+=" ${path@Q}"
done

find_command+=" \("

first_iteration=true
for path in $exclude_paths; do
    if $first_iteration; then
        find_command+=" -path ${path@Q}"
        first_iteration=false
    else
        find_command+=" -o -path ${path@Q}"
    fi
done

find_command+=" \) -prune -o $find_options"

echo "$find_command"
