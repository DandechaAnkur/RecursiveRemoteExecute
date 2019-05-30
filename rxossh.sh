function pass
{
    return
}

# bare log without shell no
function blog
{
    if [[ "$var_verbosity" == "--verbose" ]]; then
        echo $* 2>&1
    fi
}

function log
{
    if [[ "$var_verbosity" == "--verbose" ]]; then
        echo [Shell\#$var_shell_no] $* 2>&1
    fi
}

# log echo
function loge
{
    if [[ "$var_verbosity" == "--verbose" ]]; then
        echo echo [Shell\\#$var_shell_no] $* 2>&1
    fi
}

# log echo v2 echoing on lc flag too
function loge2
{
    if  [[ "$var_verbosity" == "--verbose" ]] || \
        [[ "$var_log_commands" == "--log-commands" ]];
    then
        echo echo [Shell\\#$var_shell_no] $* 2>&1
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
    if [[ "$var_keep_files" != "--keep-files" ]]; then
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


    if [[ " $* " == *" -al "* ]] || [[ " $* " == *" --all-logs "* ]]; then

        var_log_commands="--log-commands"
        var_verbosity="--verbose"
        var_output_stream=/dev/stdout
        var_parser_logs=1

    else

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

    fi


    if [[ " $* " == *" -nic "* ]] || \
       [[ " $* " == *" --no-interactive-commands "* ]]
    then
        var_force_terminal_allocation_arg=--no-interactive-commands
        var_force_terminal_allocation_ssh_arg=
        var_ssh_stderr_rd_text=
    else
        var_force_terminal_allocation_arg=
        var_force_terminal_allocation_ssh_arg=-tt
        # curiously for ssh's -tt option 1&2 streams merge
        # so we can disable disconnected message coming on 2
        var_ssh_stderr_rd_text=2\>/dev/null
    fi


    if [[ " $* " == *" -kf "* ]] || [[ " $* " == *" --keep-files "* ]]; then
        var_keep_files=--keep-files
    else
        var_keep_files=
    fi


    if [[ " $* " == *" -sn "* ]] || [[ " $* " == *" --shell-no "* ]]; then
        var_shell_no=`echo "$*" | sed -nE 's#.* (-sn|--shell-no) +([0-9]+) +.*#\2#gp' | tr -d '\n'`
    else
        var_shell_no="0"
    fi


    if [ ! -f "$1" ]; then
        >&2 echo Not a file: $1
        return 1
    fi

    var_commands_dir=`realpath $(dirname "$1")`
    echo $var_commands_dir | grep -P "^.*/rxossh-.......$" >/dev/null 2>&1
    if [[ "${PIPESTATUS[1]}" == "1" ]]; then
        var_commands_dir_mktemped=1
        var_commands_dir=`mktemp -p "$var_commands_dir" -d -t rxossh-XXXXXXX | sed -E 's|\r||g' | tr -d '\n'`
    fi

    var_local_commands_to_be_sourced="$var_commands_dir/local_commands.sh"

    if [[ $var_log_commands == "--log-commands" ]]; then
        echo "set -x" > $var_local_commands_to_be_sourced 
    else
        echo -n "" > $var_local_commands_to_be_sourced
    fi

    var_local_commands="$var_commands_dir/local_commands"

    cp "$1" "$var_local_commands" >/dev/null 2>&1 # for inner shell both files are same

    var_remote_commands_prefix="$var_commands_dir/remote_commands"


    var_ssh_has_been_found=0

    # https://unix.stackexchange.com/a/7012
    # IFS=$'\n'; set -f;
    # for var_command in `cat $var_local_commands`
    while read -r var_command
    do

        plog line: $var_command

        # stop this script ..
        echo "$var_command" | grep -P "^\s*exit\s+#script\s*$" >/dev/null 2>&1
        if [[ "${PIPESTATUS[1]}" == "0" ]]; then

            plog exit \#script
            log Done parsing initial script.

            break
        fi

        # ignore empty lines ..
        echo "$var_command" | grep -P "^\s*$" >/dev/null 2>&1
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

            echo $var_command >> $var_remote_commands

            var_exit_no=`echo $var_command | \
                sed -n "s|exit *#\([[:digit:]][[:digit:]]*\)|\1|gp" | \
                tr -d '\n'`

            if [[ "$var_ssh_cmd_no" == "$var_exit_no" ]]; then

                plog ssh exit found
                var_ssh_has_been_found=0

                # has to remove all the \r's
                # v=printf "A\rB\rC\r"; echo ${v}D will print only D
                echo var_remote_dir=\`ssh -tt $var_ssh_extras $var_ssh_target 'mktemp -d -t rxossh-XXXXXXX' 2\>/dev/null \| sed -E \"s/\\r//g\" \| tr -d \'\\n\'\` \
                    >> $var_local_commands_to_be_sourced

                loge Copying rxossh with remote commands to $var_ssh_target [Shell\\#$var_ssh_cmd_no] \
                    >> $var_local_commands_to_be_sourced

                echo var_copied=0 \
                    >> $var_local_commands_to_be_sourced

                # -T disables pseudo terminal allocation
                # otherwise if extras have -tt in it there opens up an undying shell
                # also keeping it after extras so as to be processed at the last
                echo dd if=$var_self_filepath 2\>/dev/null \| \
                    ssh $var_ssh_extras -T $var_ssh_target \
                    \"dd of=\$var_remote_dir/rxossh.sh\" \
                    2\>/dev/null \&\& var_copied=1 \
                    >> $var_local_commands_to_be_sourced

                echo dd if=$var_remote_commands 2\>/dev/null \| \
                    ssh $var_ssh_extras -T $var_ssh_target \
                    \"dd of=\$var_remote_dir/local_commands\" \
                    2\>/dev/null \&\& var_copied=2 \
                    >> $var_local_commands_to_be_sourced

                echo "if [[ \$var_copied != 2 ]]; then >&2 echo Copying rxossh with remote commands failed.; fi" \
                    >> $var_local_commands_to_be_sourced

                # because I'm sourcing local_commands.sh remove will get value of its flag
                echo remove $var_remote_commands \
                    >> $var_local_commands_to_be_sourced

                loge2 SSH to $var_ssh_target [Shell\\#$var_ssh_cmd_no] \
                    >> $var_local_commands_to_be_sourced

                echo ssh $var_force_terminal_allocation_ssh_arg \
                    $var_ssh_extras $var_ssh_target \
                    \""( . \$var_remote_dir/rxossh.sh \
                    \$var_remote_dir/local_commands \
                    $var_verbosity \
                    --shell-no $var_ssh_cmd_no \
                    $var_keep_files \
                    $var_force_terminal_allocation_arg \
                    $var_log_commands; ); \
                    . \$var_remote_dir/rxossh.sh --libs; \
                    remove \$var_remote_dir;\"" \
                    $var_ssh_stderr_rd_text \
                    >> $var_local_commands_to_be_sourced

                loge2 Exited $var_ssh_target [Shell\\#$var_ssh_cmd_no] \
                    >> $var_local_commands_to_be_sourced

                if [[ $var_log_commands == "--log-commands" ]]; then
                    echo "set -x" >> $var_local_commands_to_be_sourced 
                fi

            fi

        else

            echo $var_command | grep -P '^ *ssh +[^ ].* +#\d+ *$' >/dev/null 2>&1
            if [[ "${PIPESTATUS[1]}" == "0" ]]; then

                plog ssh command encountered
                var_ssh_has_been_found=1

                if [[ $var_log_commands == "--log-commands" ]]; then
                    echo '{ set +x; } >/dev/null 2>&1' >> $var_local_commands_to_be_sourced
                fi

                var_ssh_cmd_no=`echo $var_command | \
                    sed -nE 's|^ *ssh +(.* +)?(([^@ ]+@)?[^@ ]+) +#([0-9]+) *$|\4|gp' | \
                    tr -d '\n'`
                var_ssh_extras=`echo $var_command | \
                    sed -nE 's|^ *ssh +(.* +)?(([^@ ]+@)?[^@ ]+) +#([0-9]+) *$|\1|gp' | \
                    tr -d '\n'`
                var_ssh_target=`echo $var_command | \
                    sed -nE 's|^ *ssh +(.* +)?(([^@ ]+@)?[^@ ]+) +#([0-9]+) *$|\2|gp' | \
                    tr -d '\n'`
                var_remote_commands=${var_remote_commands_prefix}_$var_ssh_cmd_no
                echo -n "" > $var_remote_commands

            else

                plog execute here
                echo $var_command >> $var_local_commands_to_be_sourced

            fi
        fi

    done < $var_local_commands;
    # done
    remove $var_local_commands

    if [[ $var_log_commands == "--log-commands" ]]; then
        echo '{ set +x; } >/dev/null 2>&1' >> $var_local_commands_to_be_sourced
    fi

    log executing the following here ..
    blog ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░
    cat $var_local_commands_to_be_sourced > $var_output_stream
    blog ░░░░░░░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓

    source $var_local_commands_to_be_sourced
    remove $var_local_commands_to_be_sourced

    if [[ "$var_commands_dir_mktemped" == "1" ]]; then
        remove $var_commands_dir
    fi

}

if [[ " $* " == *" -l "* ]] || [[ " $* " == *" --libs "* ]]; then
    pass
else
    main $*
    { set +x; } >/dev/null 2>&1
fi

