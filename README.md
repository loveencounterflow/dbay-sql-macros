
# 𓆤DBay SQL Macros


<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [𓆤DBay SQL Macros](#%F0%93%86%A4dbay-sql-macros)
  - [Use Case for Macros: Virtual Types](#use-case-for-macros-virtual-types)
- [To Do](#to-do)
  - [Is Done](#is-done)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->



# 𓆤DBay SQL Macros


Because [User-Defined Functions have several shortcomings in
SQLite](https://github.com/loveencounterflow/dbay#notes-on-user-defined-functions-udfs), below), an
alternative mechanism named `dbay-sql-macros` has been conceived to work around some of those issues.

`dbay-sql-macros` has been integrated into [DBay](https://github.com/loveencounterflow/dbay) such that when
one constructs the `db` instance as `db = new DBay { macros: true, }`, all statements will be subjected to
macro expansion implicitly before SQLite gets to see them. That said, `dbay-sql-macros` can be used
independently from DBay as all it is concerned with is really interpolation of values into a given string,
according to the definition of macros it has recorded.

<!-- discuss how much of this makes practical sense: "... and, in fact, outside of any database- or
SQL-related context..." -->

Instances of `dbay-sql-macros` <!-- ### TAINT use class name --> hav two public methods, `declare()` and
`resolve()` to define and use macros. An example:

```coffee
{ DBay_sqlx }     = require 'dbay-sql-macros'
m                 = new DBay_sqlx()
m.declare "@secret_power( @a, @b ) = power( @a, @b ) / @b;"
result  = m.resolve "select @secret_power( 3, 2 ) as p;"
# "select power( 3, 2 ) / 2 as p;"
```

In the above, we have declared a function-like macro named `@secret_power()` that accepts two arguments,
`@a` and `@b`. To the right of the equals sign we see `power( @a, @b ) / @b;` which is, except for the
trailing semicolon, the 'body' of the macro, which is what the macro, when used in an SQL query, will
'resolve' or 'expand' to, with values interpolated to replace the parameters in the body. Schematically and
step by step:

```sql
select @secret_power( 3, 2 ) as p; -- original query w/ macro
--     |-------------------|       -- only this stretch of the query is affected
select power( @a, @b ) / @b  as p; -- the query with the macro body inserted
select power(  3, @b ) / @b  as p; -- the query with the macro body inserted
select power(  3,  2 ) / 2   as p; -- the query with the macro body inserted
--     |-------------------|
```

Notes:

* The use of the `@` (at-sign) in the above is purely a convention to avoid name clashes with existing
  SQLite keywords and identifiers (`@` is not allowed by SQLite in identifiers, so should be safe).
* One can pass a regular expression to setting `name_re` on instantiation; the default is to use `m = new
  DBay_sqlx { name_re: /^(?<name>@[\p{Letter}_][\p{Letter}_\d]*)/yu, }` which mandates the use of `@` as a
  prefix followed by a name made up from letters, digits, and underscores.
* The exact syntax for macro declarations is still under consideration and may change.
* In particular, one wants to allow multiple statements to appear in macros.
* As it stands, everything to the right hand side of the equals sign minus any trailing semicolon becomes
  part of the body.
* The underlying SQLite DB never gets to see the declarations, only the resolved SQL.
* Therefore, the DB file remains valid for external programs like the SQLite Command Line Tool.
* Some effort has been put into parsing parameters and arguments and parentheses pairs. As a happy result,
  it is possible to put unpaired parentheses into string literals without confusing the mechanism, and to
  nest function and macro calls, so this is legal and will resolve correctly: `select @secret_power( foo( x
  ), @bar( y, z, ')' ) )`. However the
  [`dbay-sql-lexer`](https://github.com/loveencounterflow/dbay-sql-lexer) is still in its incipient stage so
  hiccups can not be ruled out.
* Parameters and arguments must always match in length. Only macros with constant arities are currently
  supported.
* It is not allowed to declare or use macros without the parentheses as they are needed to distinguish macro
  names from parameter names.
* Macros are resolved recursively in a way that allows to use macros in macro bodies and macro calls.
  However, a macro can not contain its own name directly or indirectly as that would cause infinite
  regression.
* The characters that appear in a call in the space of a declared parameter are used verbatim to replace any
  appearance of that parameter's name in the macro body, even when they should appear inside of, say, string
  literals. To block replacements, prefix the parameter name in the macro body with a backslash. These
  backslashes will be removed from the result.
* A parameter in a macro's body may end in a 'vanishing terminator', currently fixed as `|`. This enables
  replacements in contexts without explicit spaces or other identifier-delimiters. In order to get a macro
  where a literal `|` should directly follow the replacement text, use `||`.

```
m.declare SQL"""@add( @a, @b ) = ( @a + @b );"""
m.declare SQL"""@mul( @a, @b ) = ( @a * @b );"""
#.........................................................................................................
do ->
  probe   = SQL"""select @add( @mul( @add( 1, 2 ), 3 ), @add( 4, @mul( 5, 6 ) ) ) as p;"""
  matcher = 'select ( ( ( 1 + 2 ) * 3 ) + ( 4 + ( 5 * 6 ) ) ) as p;'
```

* U+3000 'Ideographic space' does not count as whitespace in SQLite
* we do not require any kind of word break; macros and parameters can appear anywhere, even embedded between
  other material or inside a string literal


## Use Case for Macros: Virtual Types

```sql
create table t (
  year        integer check ( year    between 1900  and 2100 ),
  month       integer check ( month   between 1     and 12   ),
  day         integer check ( day     between 1     and 31   ),
  hour        integer check ( hour    between 0     and 23   ),
  minute      integer check ( minute  between 0     and 59   ),
  second      integer check ( second  between 0     and 59   )
  );
```

```sql
  month_name  text    check ( month_name in ( 'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec', ) ),
```

# To Do

* **[–]** documentation
* **[–]** safeguard against using a macro in its own expansion, leads to infinite regress
* **[–]** should we use a more SQL-ish syntax similar to function declarations like `create macro @m as
  [begin] ... [end];`?
* **[–]** allow to escape left parens as `\(` in order to ensure that a parameter name does not get confused
  with a macro name
* **[–]** allow 'constant macros'/'global constant parameters'? would this be a return to paren-less macro
  calls? if a name clash should occur between a macro's parameter names and such a 'global constant', which
  one should win out?—Maybe better to rule out any such name clashes.
* **[–]** allow to escape vanishing terminator with a backslash instead of doubling it to reduce confusion
* **[–]** consider to change escape character from `\` to something with less interaction with common source
  code escapes
* **[–]** check for use of non-prefixed parameters in declaration
* **[–]** add settings to enable putting entire expansion and/or expansion of parameters within parentheses;
  this could happen both at declaration and/or at resolution time
  * **[–]** a similar setting could trigger inline comments that spell out the names of the resolved macros,
    parameters as in `select /*{foo*/ /*{a*/ 3 + /*{b*/ 4 /*}*/`, might be useful for debugging—although
    even this simple snippet is hard to parse visually, so maybe better add a 'demo mode' with tabular
    output (think `explain` / `analyze`)?

## Is Done

* **[+]** after expansions are done, check whether `cfg.name_re` matches any remaining parts
* **[+]** use `u`nicode flag on all regexes
* **[+]** relatedly, either
  * implement an escape sequence that allows to use a parameter value without spacing
    inside of arbitrary text, or else
  * allow braces as in `abc@{foo}xyz` (better) or `abc{@foo}xyz`, or else
  * could use brackets, backticks, and/or dquotes as in `abc@[foo]xyz`, ``abc@`foo`xyz``, `abc@"foo"xyz`,
  * use an optional 'vanishing' terminator, as in `abc@foo;xyz`, `abc@foo|xyz`
* **[+]** allow to escape vanishing terminator
* **[+]** should really search through source to find macro calls, not use regex built from macro names
* **[+]** <del>should macros be undone when declared inside a failed transaction?</del>
* **[+]** do not allow macro calls without parentheses because only then can we distinguish between macro
  names and parameter names
* **[+]** <del>sort macro names by length *and* lexicographically to avoid order of declaration having any kind
  of effect</del>
* **[+]** replaced w/ issue to make this a s setting on declaration and/or resolution time <del>allow
  parameters in parentheses to trigger expansions with parentheses, ex.:

  ```coffee
  declare SQL"""@foo( (@first), @second ) = @first * @second;"""
  resolve SQL"""@foo( 1 + 2, 3 );"""
  # gives
  '( 1+2 ) * 3'
  ```

  Likewise, could allow SQL"""@foo = (( @a, @b ))""" to put parentheses around entire replacement</del>
* **[+]** check for undeclared parameters in replacement text
* **[+]** check for repetitions in parameter declaration


