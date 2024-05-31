## SRCINFO_BASH

`SRCINFO_BASH` is a one file sourced library for bash that parses [SRCINFO](https://wiki.archlinux.org/title/.SRCINFO) files into native bash dictionaries.

#### Usage
Include/source the entire `src/srcinfo.sh` file in your script, and run the function `srcinfo.parse`. It can take the optional flag `-p` to enable pacstall compatibility. The function has 1 required argument, that being the path to the SRCINFO file, and an optional second argument that takes a variable prefix, useful for avoiding variable name clashes. The function can return a variety of return codes, so you should know about what each one does:

| Error Code | Description                            |
|------------|----------------------------------------|
| 1          | No file passed                         |
| 2          | Invalid parameter passing              |
| 3          | Could not parse a valid key value pair |
| 4          | Could not parse a valid value          |
| 5          | Empty file passed                      |

If you get 0, congratulations, you parsed a file! Since Bash doesn't have good support for anything past a simple dictionary, you're gonna have to parse some stuff yourself after, but here's how any given variable should look:

Without `-p`:
```
{var_prefix}_{pkgbase}_{value}
```

With `-p`:
```
{var_prefix}_{value}
```

Now, the value of that variable can be one of two things:

Array:
```
SRCINFO_ARRAY_REDIRECT:array_name
```

Where `array_name` is the name of the array that holds the contents of it (thanks a lot bash).

Variable:
```
variable_contents
```
