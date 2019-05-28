Through this, you can execute a list of bash commands, having random ssh jumps in between, correctly. The user friendly part here, is the ease of specifying what code to execute on what machine.

Let's take something like below - your commands, in one file, line by line:
```
 1    ssh   u1@m1
 2    echo  on m1
 3    exit

 4    ssh   u2@m2
 5    function whereami
 6    {
 7          if [ "$IDK" == "whereami" ];
 8              hostname
 9          fi
10    }
11    whereami

          # indentation is just to signify
          # this is going from machine m2 to m3
12        ssh   u3@m3
13        echo  on m3
14        exit

15    exit
```
The intention here is to execute:
* 1st line on main machine,
* 2-3 on machine m1, and 
* 4th line again on main machine,
* 5-12 on machine m2
* 13-14 on machine m3
* 15th on machine m2

In effect, you want to give your code in one file, line by line, yet, whenever ssh jumps are specified, the later portion of the code, should be executed over to the made ssh, and whensoever that ssh is exited from, the next lines of code should get executed on the parent shell.

This project makes it simple to achieve - all we need to do is label the SSH calls and corresponding EXIT calls with same #Number kind of label at the end of these two commands. Please check the following to see what I mean -

```
 1    ssh   u1@m1   #1
 2    echo  on m1
 3    exit          #1
 4    ssh   u2@m2   #2
 5    function whereami
 6    {
 7          if [ "$IDK" == "whereami" ];
 8              hostname
 9          fi
10    }
11    whereami
12    ssh   u3@m3   #3
13    echo  on m3
14    exit          #3
15    exit          #2
16    exit          #script
```

So, the only additional effort here, is to label every ssh-exit command pairs with same #Numbers.

The #Numbers should not be repeated. Though the increasing order is used in the above example, it is not necessary.

And, as you can see, we end our commands file, with an additional "exit #script" command.

So, have your commands, in one file, with #Number labelled ssh-exit pairs, and give it to the rxossh.sh script as its 1st argument, and you're good to go!

It just have to be a text file, with any suitable name. I have kept above example script [in here](commands.txt).

And when you're ready with your commands file, simply execute:
```
./rxossh.sh commands.txt
```

That's all!

(Btw, 'rxossh' was formed from 1st letters of 'Remote Execute over SSH'!)

For command line arguments see this [USAGE](usage.txt) file.

Happy SSHing! :)

-ADandecha

