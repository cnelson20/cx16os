## cx16os internals

Each process lives in banked RAM. Even banks are used for program code, and those banks + 1 are used for additional process data. Banks can also be used for data storage, using several kernal calls.

The kernal is still largely 8-bit, but certain routines (notably some of the extmem routines) have added functionality when the accumulator and index registers are 16-bit. 16-bit index registers are also used internally to speed up some helper routines (strlen, strcpy, etc.).

<br />

I want to expand this section of the docs, but am focused on other parts of the docs. Hopefully I'll be able to do better justice to covering the internal workings of cx16os soon.
