# https://stackoverflow.com/a/231298
if [[ $* =~ -h ]] || [[ $* =~ --help ]]; then
    cat help.txt
    exit
fi

verbose=0
if [ "$1" == "-v" ] || [ "$1" == "1" ]; then verbose=1; fi
if [ "$2" == "-v" ] || [ "$2" == "1" ]; then verbose=1; fi

function pass
{
    return
}


###################################
# colored printing / formatting ..
###################################

c_red=$'\e[1;31m'
c_grn=$'\e[1;32m'
c_blu=$'\e[1;34m'
c_ylo=$'\e[1;33m'
c_mag=$'\e[1;35m'
c_cyn=$'\e[1;36m'
c_rst=$'\e[0m'

function clrp
{
    # pass the first arg as one of the red grn blu ylo mag cyn from above list
    # ex usage: clrp red danger it is!
    clr_var=c_${1}
    clr=${!clr_var}
    shift
    echo $clr$*$c_rst | tr -d '\n'
}

function clre
{
    echo `clrp $*`
}

function clrx
{
    clre $*
    shift
    $*
}

function info
{
    if [ $verbose -eq 0 ]; then return; fi
    clrp ylo "$1 "
    shift
    echo $*
}

function imp
{
    if [ "$verbose" == "0" ]; then return; fi
    clrp red "$1 "
    shift
    echo $*
}

###################################
 
# source bashrc in case you want to include some funcs/vars defined on machine
if [ -f ~/.bashrc ]; then source ~/.bashrc; fi

mkdir -p /tmp

self=${BASH_SOURCE[0]}

ownpath=/tmp/rxossh.sh

cmdfile=/tmp/remote.commands
if [ "$1" != "" ] && [ -f "$1" ]; then cmdfile="$1"; fi
if [ "$2" != "" ] && [ -f "$2" ]; then cmdfile="$2"; fi
if [ "$cmdfile" != "/tmp/remote.commands" ]; then
    cp $cmdfile /tmp/remote.commands
    cmdfile=/tmp/remote.commands
fi
scpfile=/tmp/remote.commands.4scp

ssh_found=0

# for all line numbers ..
for ((i = 1; ; i++)); do

    # get line no $i
    cmd=`sed -n "${i}p" "$cmdfile" | tr -d '\n'`

    if [ "$cmd" == "exit #script" ]; then
        break;
    fi

    if [ "$ssh_found" == "1" ]; then

        echo $cmd >> $scpfile
        info rx: $cmd

        exit_no=`echo $cmd | \
            sed -n "s|exit *#\([[:digit:]]*\)|\1|gp" | \
            tr -d '\n'`

        if [ "$ssh_cmd_no" == "$exit_no" ]; then

            ssh_found=0
            #info exit: $exit_no
            #hnfx cat $scpfile

            if [ $verbose -eq 1 ]; then devnull=""; else devnull="> /dev/null"; fi
            eval scp $self $ssh_target:$ownpath     $devnull
            eval scp $scpfile $ssh_target:$cmdfile  $devnull
            rm -f $scpfile # this command must succeed as I just created the scpfile when I found below that there's ssh
            # eval ssh $ssh_target rm -f $scpfile     $devnull # no need as each script must remove its created scpfiles

            if [ $verbose -eq 0 ]; then
                # https://stackoverflow.com/a/23550347
                eval >&2 echo ssh\#$ssh_cmd_no: $ssh_target
                # but for inner ssh scripts I am not sure if they are dropping differentiation between stdout and stderr
            else
                eval imp ssh\#$ssh_cmd_no: $ssh_target
            fi

            # i added -tt to avoid an err smn' like inner shell no serial input so exiting smn' like that
            # eval ssh -tt $ssh_target . $ownpath $verbose
            # but -tt merges both streams and inner stderr cannot be separated thus .. so avoiding -tt
            # keep an eye on future behavior for above kind of err message or behavior
            eval ssh $ssh_target . $ownpath $verbose

            if [ $verbose -eq 0 ]; then
                >&2 echo exited: shell\#$exit_no
            else
                imp exited: shell\#$exit_no
            fi

            # clean up ..
            info clean-up: removing copied $cmdfile and $ownpath
            eval ssh $ssh_target rm -f $ownpath $cmdfile

        fi

    else

        echo $cmd | grep -P 'ssh +([^@]+@)?[^@]+ #\d+' 2>&1 > /dev/null
        if [ "${PIPESTATUS[1]}" -eq "0" ]; then

            ssh_found=1

            ssh_cmd_no=`echo $cmd | \
                sed -n 's|ssh  *\(.*\)  *#\([[:digit:]]*\)|\2|gp' | \
                tr -d '\n'`
            ssh_target=`echo $cmd | \
                sed -n 's|ssh  *\(.*\)  *#\([[:digit:]]*\)|\1|gp' | \
                tr -d '\n'`

            # following doesn't work as the script exec throuh ssh script_path.sh isn't allowed to rm
            # i guess
            # /dev/null > $scpfile
            rm -f $scpfile && touch $scpfile
            # echo > $scpfile # why even let empty line be parsed when I know my sed parsing is naive/ineffective with n2 passes
            # so i parent shell will emty out the $scpfile himself

            #imp ssh\#$ssh_cmd_no: ssh $ssh_target
            info ssh: $ssh_target

        else

            if [ $verbose -eq 0 ]; then
                eval >&2 echo here: $cmd
            else
                info here: $cmd
            fi
            eval $cmd

        fi
    fi

done

