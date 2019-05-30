Through this, you can execute a list of bash commands, having random ssh jumps in between, correctly. The user friendly part here, is the ease of specifying what code to execute on what machine.

Let's take something like below - your commands, in one file, line by line:
```
  1 hostname
  2 ssh machine1
  3 hostname
  4 ssh machine2
  5 hostname
  6 exit
  7 hostname
  8 exit
  9 hostname
```
The intention here is to execute,
* lines 1-2 on the machine we're on,
* lines 3-4 on machine1,
* lines 5-6 on machine2,
* lines 7-8 on machine1,
* And, the 9th line, again on the original machine.

The desired output is,
```
original-machine
machine1
machine2
machine1
original-machine
```

In effect, you want to give your code, in one file, line by line; yet, whenever ssh jumps are specified, the later portion of the code, should be executed over to the made ssh, and whensoever that ssh is exited from, the next lines of code should get executed on the parent shell.

This project makes it simple to achieve - all we need to do, is tag the SSH calls and corresponding EXIT calls with same #Number kind of label at the end of these two commands. Please check the following to see what I mean -

```
  1 hostname
  2 ssh machine1 #1
  3 hostname
  4 ssh machine2 #2
  5 hostname
  6 exit         #2
  7 hostname
  8 exit         #1
  9 hostname
 10 exit         #script
```

So, the only additional effort here, is to label every ssh-exit command pairs with same #Numbers.

The #Numbers must not be repeated. Even though the increasing order is used in the above example, it is not necessary.

And, as you can see, we end our commands file, with an additional "exit #script" command.

So, have your commands, in one file, with #Number labelled ssh-exit pairs, and an "exit #script" at the end, and give it to the rxossh.sh script as its 1st argument, and you're good to go!

It just has to be a text file, with any suitable name. I have kept above example script [in here](commands.txt).

And when you're ready with your commands file, simply execute:
```
./rxossh.sh commands.txt
```

That's all!

(Btw, 'rxossh' was thought of from the 1st letters of 'Remote/Recursive Execute over SSH'!)

For command line arguments see this [USAGE](usage.txt) file.

Happy SSHing! :)

-ADandecha

