Through this, you can execute commands jumping over machines.

That's not the Magic, the Magic is in how you specify your commands!

Your commands, in one file, line by line.
```
    SSH u@m1
    Exec some_command
    Exit
    SSH u@m2
    Exec some_another_command
    SSH u@m3
    Exec some_another_command
    Exit
    Exit
```
And, still every command runs, exactly on whatever shell that it's intended to run.
Please bear with me while I explain this in the following.

Let's assume, I want to execute some commands on some machines, jumping from one machine to another:

```
admin@macihne0:> ssh machine1
admin@machine1:> ssh machine2
admin@machine2:> echo I came on machine2 from machine1
admin@machine2:> exit
admin@machine1:> ssh machine3
admin@machine3:> echo I came on machine3 from machine1
admin@machine3:> exit
admin@machine1:> echo I am on machine1 now
admin@machine1:> exit
```

What if I would be able to specify all these commands serially!? Like below ..

```
ssh machine1
ssh machine2
echo I came on machine2 from machine1
exit
ssh machine3
echo I came on machine3 from machine1
exit
echo I am on machine1 now
exit
```

.. and execute it all, with one press of Enter key!

Well! With the rxossh.sh script, now you can!
Let's put the above commands into one text file, let's name it "remote.commands" file, you can choose any name.
Now, the only addtional effort is, labelling "ssh" and corresponding "exit" with same #number kind of labels, see below,

```
cat remote.commands
```
```
ssh machine1 #1
ssh machine2 #2
echo I came on machine2 from machine1
exit #2
ssh machine3 #3
echo I came on machine3 from machine1
exit #3
echo I am on machine1 now
exit #1
```

And, execute:
```
./rxossh.sh remote.commands
```

That's all!

The jumping over to machines, executing the intended commands, exiting from the shells, etc. - all this is handled by the rxossh script.
Btw, rxossh is for 'Remote Execute over SSH', if you got curious as to why such a name! :)

For command line arguments see this [USAGE](usage.txt) file.

Happy SSHing! Cheers! :)

-Ankur Dandecha

