[Back](./)

## scripter

#### scripting language

### Usage:
```
scripter [OPTIONS]... FILE
```

#### Command Basics:
- `$` : define a variable
- `@` : run a asm routine
- `-`/`!` : execute a program and wait for it to finish
- `?` : conditional
- `%` : goto
- `>` : user input
- `#` : line number label
- `x` : exit, if in interactive mode (entered by using the `-i` flag)

#### More detailed Syntax:

`$` statement: define or set a variable
```
$variable_name [EXPRESSION]
```

<br />

`@` statement: run a asm routine
```
@routine_addr [REG=value]...
```

<br />

`-` / `!` statement: run an external program
```
-program_name [ARGS]
```

<br />

`?` statement: perform a statement conditionally
```
? CONDITION, $@-?% STATEMENT
```

<br />

`%` statement: goto a line number
```
% #LABEL_NAME
```
or
```
% LINE_NUMBER
```

<br />

`>` statement: get a line of input from the user
```
>$variable_to_write_input
```

<br />

`#` statement: set a label equal to the curr line number, to use in conjunction `%` statements
```
#label_name
```

<br />

#### Special variables:
- `.A`: 8-bit value of A register after the last asm routine completed
- `.C`: 16-bit value of A/C register after the last asm routine completed
- `.X`: 16-bit value of X register after the last asm routine completed
- `.AX`: low bytes of A and X registers after the last asm routine completed
- `.Y`: 16-bit value of Y register after the last asm routine completed
- `RETURN`: return code of last external program executed
- `.`: current line number
