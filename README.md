
# 𓆤DBay SQL Macros


<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [𓆤DBay SQL Macros](#%F0%93%86%A4dbay-sql-macros)
- [To Do](#to-do)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->



# 𓆤DBay SQL Macros

<!--

### NOTE below is preliminary documentation ###


The working principle of SQLx is to enable users to declare more or less arbitrary character sequences and
their replacements, together with a simple-minded parsing of formal parameters and actual arguments for
UDF-like functionality. An example: imagine one has to use the expression ${a^b\over b}$ over and
over in SQL queries. With SQLx, one can declare a macro like this:

```coffee
db.declare SQL"""@secret_power( @a, @b ) = power( @a, @b ) / @b;"""
```

The left-hand side, `@secret_power( @a, @b )`, declares the name (`@secret_power`) and the parameters (`@a`
and `@b`) for the macro; the right-hand side declares the parametrized 'body' of the macro, `power( @a, @b )
/ @b` (where `power()` is a standard SQLite math function). In order to use the macro, write its name and
the parentheses like in the declaration, substituting values or other expressions for the parameters:

```coffee
SQL"""select @secret_power( 3, 2 );"""
```

The macro can then be 'resolved':

```coffee
db.resolve SQL"""select @secret_power( 3, 2 );"""
```

which returns the same string, with the macro name and the arguments replaced by the body of the macro and
the values:

```coffee
'select power( 3, 2 ) / 2;'
```

No syntax checking is performed of any kind, the only requirement being that the parenthized arguments do
not contain any parentheses themselves (a restriction that can hopefully be lifted soon) and that the
resulting SQL must, of course, get accepted by the SQLite parser.

Two more examples:

```coffee
db.declare SQL"""@max( @a, @b ) = case when @a > @b then @a else @b end;"""
sqlx  = SQL"""select @max( 3, 2 ) as the_bigger_the_better;"""
sql   = db.resolve sqlx
```

results in

```coffee
'select case when 3 > 2 then 3 else 2 end as the_bigger_the_better;'
```

and

```coffee
db.declare SQL"""@intnn() = integer not null;"""
sqlx  = SQL"""
  create table numbers (
    n @intnn() primary key );"""
```

gives

```coffee
create table numbers (
  n integer not null primary key );
```




 -->



# To Do

* **[–]** documentation
* **[–]** safeguard against using a macro in its own expansion, leads to infinite regress

<!--
## Is Done

* **[+]** use `u`nicode flag on all regexes
 -->