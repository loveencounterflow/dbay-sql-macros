
# 𓆤DBay SQL Macros


<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [𓆤DBay SQL Macros](#%F0%93%86%A4dbay-sql-macros)
- [To Do](#to-do)

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
* The exact syntax for macro declarations is still under consideration and may change.
* In particular, one wants to allow multiple statements to appear in macros.
* As it stands, everything to the right hand side of the equals sign minus any trailing semicolon becomes
  part of the body.
* The underlying SQLite DB never gets to see the declarations, only the resolved SQL.
* Therefore, the DB file remains valid for sufficiently compatible software like the SQLite Command Line
  Tool.
* Some effort has been put into parsing parameters and arguments and parentheses pairs. As a happy result,
  it is possible to put unpaired parentheses into string literals without confusing the mechanism, and to
  nest function and macro calls, so this is legal and will resolve correctly: `select @secret_power( foo( x
  ), @bar( y, z, ')' ) )`. However the
  [`dbay-sql-lexer`](https://github.com/loveencounterflow/dbay-sql-lexer) is still in its incipient stage so
  hiccups can not be ruled out.
* Parameters and arguments must always match in length. Only macros with constant arities are currently
  supported.
* It is possible to declare and use macros without the parentheses.
* A macro that has been declared with empty parentheses may be called with empty or without parentheses, and
  vice versa.
* Macros are resolved recursively in way that allows to use macros in macro bodies and macro calls.

```
m.declare SQL"""@add( @a, @b ) = ( @a + @b );"""
m.declare SQL"""@mul( @a, @b ) = ( @a * @b );"""
#.........................................................................................................
do ->
  probe   = SQL"""select @add( @mul( @add( 1, 2 ), 3 ), @add( 4, @mul( 5, 6 ) ) ) as p;"""
  matcher = 'select ( ( ( 1 + 2 ) * 3 ) + ( 4 + ( 5 * 6 ) ) ) as p;'
```


# To Do

* **[–]** documentation
* **[–]** safeguard against using a macro in its own expansion, leads to infinite regress

<!--
## Is Done

* **[+]** use `u`nicode flag on all regexes
 -->