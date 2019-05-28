function pass
{
    return
}

# bare log without shell no
function blog
{
    if [[ "$var_verbosity" == "-v" ]] || [[ "$var_verbosity" == "--verbose" ]]; then
        echo $* 2>&1
    fi
}

function log
{
    if [[ "$var_verbosity" == "-v" ]] || [[ "$var_verbosity" == "--verbose" ]]; then
        echo [Shell\#$var_shell_no] $* 2>&1
    fi
}

# log echo
function loge
{
    if [[ "$var_verbosity" == "-v" ]] || [[ "$var_verbosity" == "--verbose" ]]; then
        echo echo [Shell\#$var_shell_no] $* 2>&1
    fi
}

# log echo v2 echoing on lc flag too
function loge2
{
    if  [[ "$var_verbosity" == "-v" ]] || \
        [[ "$var_verbosity" == "--verbose" ]] || \
        [[ "$var_log_commands" == "-lc" ]] || \
        [[ "$var_log_commands" == "--log-commands" ]];
    then
        echo echo [Shell\#$var_shell_no] $* 2>&1
    fi
}

# parser log
function plog
{
    if [[ "$var_parser_logs" == "1" ]]; then
        echo [Shell\#$var_shell_no] $* 2>&1
    fi
}

function remove
{
    if [[ "$var_keep_files" == "0" ]]; then
        rm -rf $*
    fi
}

function main
{

    var_self_filepath=${BASH_SOURCE[0]}
    var_self_dir=`realpath $(dirname "$var_self_filepath")`

    if [ $# -lt 1 ] || [[ " $* "  == *" -h "* ]] || [[ " $* " == *" --help "* ]]; then
        cat "$var_self_dir/usage.txt"
        return
    fi


    if [[ " $* " == *" -lc "* ]] || [[ " $* " == *" --log-commands "* ]]; then
        var_log_commands="--log-commands"
    else
        var_log_commands=""
    fi


    if [[ " $* " == *" -v "* ]] || [[ " $* " == *" --verbose "* ]]; then
        var_verbosity="--verbose"
        var_output_stream=/dev/stdout
    else
        var_verbosity="--silent"
        var_output_stream=/dev/null
    fi


    if [[ " $* " == *" -ppl "* ]] || [[ " $* " == *" --print-parser-logs "* ]]; then
        var_parser_logs=1
    else
        var_parser_logs=0
    fi


    if [[ " $* " == *" -kf "* ]] || [[ " $* " == *" --keep-files "* ]]; then
        var_keep_files=1
    else
        var_keep_files=0
    fi


    if [[ " $* " == *" -sn "* ]] || [[ " $* " == *" --shell-no "* ]]; then
        var_shell_no=`echo "$*" | sed -nE 's#.* (-sn|--shell-no) +([0-9]+) +.*#\2#gp' | tr -d '\n'`
    else
        var_shell_no="0"
    fi


    var_local_commands_to_be_sourced="$var_self_dir/local_commands.sh"

    var_local_commands="$var_self_dir/local_commands"

    if [ ! -f "$1" ]; then
        >&2 echo Not a file: $1
        return 1
    fi

    cp "$1" "$var_local_commands" >/dev/null 2>&1 # for inner shell both files are same

    var_remote_commands_prefix="$var_self_dir/remote_commands"

    if [[ $var_log_commands == "--log-commands" ]]; then
        echo "set -x" > $var_local_commands_to_be_sourced 
    else
        printf "" > $var_local_commands_to_be_sourced
    fi

    var_ssh_has_been_found=0

    # https://unix.stackexchange.com/a/7012
    # IFS=$'\n'; set -f;
    # for var_command in `cat $var_local_commands`; do
    while read var_command
    do

        plog line: $var_command

        # stop this script ..
        echo "$var_command" | grep -P "^\s*exit\s+#script\s*$" >/dev/null 2>&1
        if [[ "${PIPESTATUS[1]}" == "0" ]]; then

            plog exit \#script
            log Parsed initial script.

            break
        fi

        # ignore empty lines ..
        echo "$var_command" | grep -P "^\s+$" >/dev/null 2>&1
        if [[ "${PIPESTATUS[1]}" == "0" ]]; then
            plog empty line
            continue
        fi

        # ignore comments ..
        if [[ "$var_command" == \#* ]]; then
            plog comment
            continue
        fi

        if [[ "$var_ssh_has_been_found" == "1" ]]; then

            var_exit_no=`echo $var_command | \
                sed -n "s|exit *#\([[:digit:]][[:digit:]]*\)|\1|gp" | \
                tr -d '\n'`

            if [[ "$var_ssh_cmd_no" == "$var_exit_no" ]]; then

                plog ssh exit found
                var_ssh_has_been_found=0

                echo var_remote_dir=\`ssh $var_ssh_target 'mktemp -d -t rxossh-XXXXXXX' \| tr -d \'\\n\'\` \
                    >> $var_local_commands_to_be_sourced

                loge SCP rxossh with remote commands to $var_ssh_target [Shell\#$var_ssh_cmd_no] \
                    >> $var_local_commands_to_be_sourced

                echo scp $var_self_filepath \
                    $var_ssh_target:"\$var_remote_dir/rxossh.sh" \
                    \> $var_output_stream \
                    >> $var_local_commands_to_be_sourced

                echo scp $var_remote_commands \
                    $var_ssh_target:"\$var_remote_dir/local_commands" \
                    \> $var_output_stream \
                    >> $var_local_commands_to_be_sourced

                echo remove $var_remote_commands \
                    >> $var_local_commands_to_be_sourced

                loge2 SSH to $var_ssh_target [Shell\#$var_ssh_cmd_no] \
                    >> $var_local_commands_to_be_sourced

                echo ssh -tt $var_ssh_target \""bash \$var_remote_dir/rxossh.sh \
                    \$var_remote_dir/local_commands \
                    $var_verbosity \
                    --shell-no $var_ssh_cmd_no \
                    $var_log_commands; \
                    . \$var_remote_dir/rxossh.sh --libs; \
                    remove \$var_remote_dir;\"" \
                    >> $var_local_commands_to_be_sourced

            else

                # not putting exit into remote commands for now
                # check later if sourcing is being done or else
                # dumping exit into remote commands is fine too
                echo $var_command >> $var_remote_commands

            fi

        else

            echo $var_command | grep -P '^ssh +[^ ]+ +#\d+$' >/dev/null 2>&1
            if [[ "${PIPESTATUS[1]}" == "0" ]]; then

                plog ssh command encountered
                var_ssh_has_been_found=1

                if [[ $var_log_commands == "--log-commands" ]]; then
                    echo '{ set +x; } >/dev/null 2>&1' >> $var_local_commands_to_be_sourced
                fi

                var_ssh_cmd_no=`echo $var_command | \
                    sed -n 's|ssh  *\(..*\)  *#\([[:digit:]][[:digit:]]*\)|\2|gp' | \
                    tr -d '\n'`
                var_ssh_target=`echo $var_command | \
                    sed -n 's|ssh  *\(..*\)  *#\([[:digit:]][[:digit:]]*\)|\1|gp' | \
                    tr -d '\n'`
                var_remote_commands=${var_remote_commands_prefix}_$var_ssh_cmd_no
                #printf "" > $var_remote_commands

            else

                plog execute here
                echo $var_command >> $var_local_commands_to_be_sourced

            fi
        fi

    done < $var_local_commands;

    remove $var_local_commands

    log executing the following here ..
    blog ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░
    cat $var_local_commands_to_be_sourced > $var_output_stream
    blog ░░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

    source $var_local_commands_to_be_sourced
    remove $var_local_commands_to_be_sourced

}

if [[ " $* " == *" -l "* ]] || [[ " $* " == *" --libs "* ]]; then
    pass
else
    main $*
    { set +x; } >/dev/null 2>&1
fi

