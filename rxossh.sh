# https://stackoverflow.com/a/231298
if [[ $* =~ -h ]] || [[ $* =~ --help ]]; then
    cat help.txt
    exit
fi


if [[ $* =~ -v ]] || [[ $* =~ --verbose ]]; then
    var_verbose="-v"
else
    var_verbose=""
fi


if [[ "$var_verbose" == "-v" ]]; then
    var_devnull=""
else
    var_devnull="> /dev/null"
fi


if [[ "$#" == "3" ]]; then
    var_shell_no="$3"
else
    var_shell_no="0"
fi


var_self_filepath=${BASH_SOURCE[0]}
var_self_dir=`realpath $(dirname "$var_self_filepath")`
var_local_commands="$var_self_dir/local_commands"
cp "$1" "$var_local_commands" > /dev/null 2>&1 # for inner shell both files are same
var_remote_commands="$var_self_dir/remote_commands"

var_ssh_has_been_found=0


# https://unix.stackexchange.com/a/7012
IFS=$'\n'; set -f;

# for all lines ..
for var_command in `cat $var_local_commands`; do

    # stop this script ..
    if [[ "$var_command" == "exit #script" ]]; then
        break
    fi

    # ignore empty lines ..
    echo "$var_command" | grep -P "^\s+$"
    if [[ "${PIPESTATUS[1]}" == "0" ]]; then
        continue
    fi

    # ignore comments ..
    if [[ "$var_command" == \#* ]]; then
        continue
    fi

    if [[ "$var_ssh_has_been_found" == "1" ]]; then

        echo $var_command >> $var_remote_commands

        var_exit_no=`echo $var_command | \
            sed -n "s|exit *#\([[:digit:]]*\)|\1|gp" | \
            tr -d '\n'`

        if [[ "$var_ssh_cmd_no" == "$var_exit_no" ]]; then

            var_ssh_has_been_found=0

            var_remote_dir=`eval ssh $var_ssh_target mktemp -d | tr -d '\n'`

            if [[ "$var_verbose" == "-v" ]]; then
                eval >&2 echo [Shell\#$var_shell_no] SCP to $var_ssh_target [Shell\#$var_ssh_cmd_no]
            fi

            eval scp \
                $var_self_filepath \
                $var_ssh_target:"$var_remote_dir/rxossh.sh" \
                $var_devnull

            eval scp \
                $var_remote_commands \
                $var_ssh_target:"$var_remote_dir/local_commands" \
                $var_devnull

            #/dev/null > $var_remote_commands
            rm -f $var_remote_commands

            if [[ "$var_verbose" == "-v" ]]; then
                # https://stackoverflow.com/a/23550347
                eval >&2 echo [Shell\#$var_shell_no] SSH to $var_ssh_target [Shell\#$var_ssh_cmd_no]
            fi

            eval ssh $var_ssh_target . "$var_remote_dir/rxossh.sh" \
                "$var_remote_dir/local_commands" \
                "$var_verbose" \
                "$var_ssh_cmd_no"

            # clean up ..
            eval ssh $var_ssh_target rm -rf "$var_remote_dir"

        fi

    else

        echo $var_command | grep -P 'ssh +([^@]+@)?[^@]+ #\d+' 2>&1 > /dev/null
        if [[ "${PIPESTATUS[1]}" == "0" ]]; then

            var_ssh_has_been_found=1

            var_ssh_cmd_no=`echo $var_command | \
                sed -n 's|ssh  *\(.*\)  *#\([[:digit:]]*\)|\2|gp' | \
                tr -d '\n'`
            var_ssh_target=`echo $var_command | \
                sed -n 's|ssh  *\(.*\)  *#\([[:digit:]]*\)|\1|gp' | \
                tr -d '\n'`

            # the following may give permission denied issues
            # /dev/null > $var_remote_commands
            # so doing the following instead
            if [ -f $var_remote_commands ]; then
                rm -f $var_remote_commands
                touch $var_remote_commands
            fi

        else

            if [[ "$var_verbose" == "-v" ]]; then
                eval >&2 echo [Shell\#$var_shell_no] $var_command
            fi
            eval $var_command

        fi
    fi

done

rm -f $var_local_commands

