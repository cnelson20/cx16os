[Back](./)

## scripter

#### scripting language

### Usage:
```
scripter [OPTIONS] script_file
```

#### Command Basics:
- `$` : define a variable
- `@` : run a asm routine
- `-` : execute a program and wait for it to finish
- `?` : conditional
- `%` : goto
- `>` : user input
- `#` : line number label

#### More detailed Syntax:

`$` statement: define or set a variable
```
$variable_name [expression]
```

<br />

`@` statement: run a asm routine
```
@routine_addr [REG=value, [REG2=value2, etc.,]]
```

<br />

`-` statement: run an external program
```
-program_name [ args ]
```

<br />

#### Special variables:
- `.A`: 8-bit value of A register after the last asm routine completed
- `.C`: 16-bit value of A/C register after the last asm routine completed
- `.X`: 16-bit value of X register after the last asm routine completed
- `.AX`: low bytes of A and X registers after the last asm routine completed
- `.Y`: 16-bit value of Y register after the last asm routine completed
- `RETURN`: return code of last external program executed
