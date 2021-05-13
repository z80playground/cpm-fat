# C Compiler

I wanted to get a working C compiler on the Z80 playground, so I googled around.

There are a few different C-compilers, but ultimately [this link](https://hackaday.io/project/173479-my-cpm-version-1a/log/181039-adding-a-native-c-compiler) lead me to the Aztec compiler:

* https://www.aztecmuseum.ca/compilers.htm#cpm

## Binaries

You'll find the binaries installed in the [C: Drive](dist/CPM/DISKS/C).


## Sample Code

The following is a traditional sample program:

```
#include "STDIO.H"

main(argc, argv)
int argc;
char *argv[];
{
   printf("Hello, world\n");
   return 0;
}
```

To compile this is a three step process:

* Convert from C -> Assembly.
* Compile.
* Link

Here's how I did completed the three steps.  First of all compile the C to assembly:

```
C>cc hello
C Vers. 1.06D 8080  (C) 1982 1983 1984 by Manx Software Systems
```

Then assemble that:

```
C>as hello
8080 Assembler Vers. 1.06D
```

Finally link it, with the runtime:

```
C>ln hello.o t.lib c.lib
C Linker Vers. 1.06D
Base: 0100   Code: 0690  Data: 0030  Udata: 00dc  Total: 0007a0
```

The end result is `hello.com` which can be executed:

```
C>dir hello.com
C: HELLO   .COM
C>hello
Hello, world
```
