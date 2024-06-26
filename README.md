## SRCINFO_BASH

`SRCINFO_BASH` is a one file sourced library for bash that parses [SRCINFO](https://wiki.archlinux.org/title/.SRCINFO) files into native bash dictionaries.

#### Usage
Include/source the entire `src/srcinfo.sh` file in your script, and run the function `srcinfo.parse`. It can take the optional flag `-p` to enable pacstall compatibility. The function has 2 required arguments, that being the path to the SRCINFO file, and a variable prefix, useful for avoiding variable name clashes. The function can return a variety of return codes, so you should know about what each one does:

| Error Code | Description                            |
|------------|----------------------------------------|
| 1          | No file passed                         |
| 2          | Invalid parameter passing              |
| 3          | Could not parse a valid key value pair |
| 4          | Could not parse a valid value          |
| 5          | Empty file passed                      |

If you get 0, congratulations, you parsed a file! Since Bash doesn't have good support for anything past a simple dictionary, you're gonna have to parse some stuff yourself after, but here's how you would access something like `pkgbase->source->[1]`:

First to get `pkgbase`, you must access an associated array named `{var_prefix}_access_pkgbase[pkgbase]`, which will contain the name of the array that you must access to get to that package contents, which is `{var_prefix}_pkgname`, another associated array which contains package information. If a key is an array, it will look like this:
```
SRCINFO_ARRAY_REDIRECT:array_name
```

Where `array_name` is the name of the array containing those values.

If `-p` is passed, the first step is irrelevant, so you can start with the second associated array, that being `{var_prefix}_pkgname_inner`.

#### Notes
This library does not check the validity of an SRCINFO file, please use another tool if that is important to you; likewise, this library also does not care about the [SRCINFO specification](https://wiki.archlinux.org/title/.SRCINFO#Specification), with the exception of the two sentences about blank lines, comments, and indentation. Whatever this library finds as a key, it will parse.
