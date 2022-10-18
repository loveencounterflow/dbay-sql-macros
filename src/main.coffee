
'use strict'


############################################################################################################
GUY                       = require 'guy'
{ alert
  debug
  help
  info
  plain
  praise
  urge
  warn
  whisper }               = GUY.trm.get_loggers 'DBAY/sqlx'
{ rpr
  inspect
  echo
  log     }               = GUY.trm
#...........................................................................................................
types                     = new ( require 'intertype' ).Intertype
new_xregex                = require 'xregexp'
# E                         = require '../../../apps/dbay/lib/errors'
sql_lexer                 = require 'dbay-sql-lexer'

E = {}

#===========================================================================================================
class E.DBay_sqlx_error            extends E.DBay_error
  constructor: ( ref, message )     -> super ref, message


#===========================================================================================================
class DBay_sqlx # extends ( require H.dbay_path ).DBay

  #---------------------------------------------------------------------------------------------------------
  constructor: ( P... ) ->
    # super P...
    GUY.props.hide @, '_sqlx_declarations', {}
    GUY.props.hide @, '_sqlx_cmd_re',       null
    GUY.props.hide @, 'types',              types
    return undefined

  #---------------------------------------------------------------------------------------------------------
  declare: ( sqlx ) ->
    @types.validate.nonempty_text sqlx
    parameters_re           = null
    #.......................................................................................................
    name_re                 = /^(?<name>@[^\s^(]+)/y
    unless ( match = sqlx.match name_re )?
      throw new E.DBay_sqlx_error '^dbay/sqlx@1^', "syntax error in #{rpr sqlx}"
    { name, }               = match.groups
    #.......................................................................................................
    if sqlx[ name_re.lastIndex ] is '('
      parameters_re           = /\(\s*(?<parameters>[^)]*?)\s*\)\s*=\s*/y
      parameters_re.lastIndex = name_re.lastIndex
      unless ( match = sqlx.match parameters_re )?
        throw new E.DBay_sqlx_error '^dbay/sqlx@2^', "syntax error in #{rpr sqlx}"
      { parameters, }         = match.groups
      parameters              = parameters.split /\s*,\s*/
      parameters              = [] if equals parameters, [ '', ]
    else
      ### extension for declaration, call w/out parentheses left for later ###
      # throw new E.DBay_sqlx_error '^dbay/sqlx@3^', "syntax error: parentheses are obligatory but missing in #{rpr sqlx}"
      parameters              = []
    #.......................................................................................................
    current_idx                 = parameters_re?.lastIndex ? name_re.lastIndex
    body                        = sqlx[ current_idx ... ].replace /\s*;\s*$/, ''
    arity                       = parameters.length
    @_sqlx_declare { name, parameters, arity, body, }
  #.......................................................................................................
    return null

  #---------------------------------------------------------------------------------------------------------
  _sqlx_get_cmd_re: ->
    return R if ( R = @_sqlx_cmd_re )?
    names = ( Object.keys @_sqlx_declarations ).sort ( a, b ) ->
      a = ( Array.from a ).length
      b = ( Array.from b ).length
      return +1 if a > b
      return -1 if a < b
      return 0
    names = ( @_escape_literal_for_regex name for name in names ).join '|'
    return @_sqlx_cmd_re = /// (?<= \W | ^ ) (?<name> #{names} ) (?= \W | $ ) (?<tail> .* ) $ ///g

  #---------------------------------------------------------------------------------------------------------
  ### thx to https://stackoverflow.com/a/6969486/7568091 and
  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Regular_Expressions#escaping ###
  _escape_literal_for_regex: ( literal ) -> literal.replace /[.*+?^${}()|[\]\\]/g, '\\$&'

  #---------------------------------------------------------------------------------------------------------
  _sqlx_declare: ( cfg ) ->
    if @_sqlx_declarations[ cfg.name ]?
      throw new E.DBay_sqlx_error '^dbay/sqlx@2^', "can not re-declare #{rpr cfg.name}"
    @_sqlx_cmd_re                   = null
    @_sqlx_declarations[ cfg.name ] = cfg
    return null

  #---------------------------------------------------------------------------------------------------------
  resolve: ( sqlx ) ->
    @types.validate.nonempty_text sqlx
    sql_before  = sqlx
    count       = 0
    #.......................................................................................................
    loop
      break if count++ > 10_000 ### NOTE to avoid deadlock, just in case ###
      sql_after = sql_before.replace @_sqlx_get_cmd_re(), ( _matches..., idx, _sqlx, groups ) =>
        # debug '^546^', rpr sqlx[ idx ... idx + groups.name.length ]
        { name
          tail  } = groups
        #...................................................................................................
        unless ( declaration = @_sqlx_declarations[ name ] )?
          ### NOTE should never happen as we always re-compile pattern from declaration keys ###
          throw new E.DBay_sqlx_error '^dbay/sqlx@4^', "unknown name #{rpr name}"
        #...................................................................................................
        if tail.startsWith '('
          matches     = new_xregex.matchRecursive tail, '\\(', '\\)', '', \
            { escapeChar: '\\', unbalanced: 'skip-lazy', valueNames: [ 'ignore', 'left', 'center', 'right', ], }
          [ left
            center
            right   ] = matches
          tail        = tail[ right.end ... ]
          values      = @_find_arguments center.value
          call_arity  = values.length
        else
          call_arity  = 0
        #...................................................................................................
        unless call_arity is declaration.arity
          throw new E.DBay_sqlx_error '^dbay/sqlx@5^', "expected #{declaration.arity} argument(s), got #{call_arity}"
        #...................................................................................................
        R = declaration.body
        for parameter, idx in declaration.parameters
          value = values[ idx ]
          R = R.replace ///#{parameter}///g, value
        return R + tail
      break if sql_after is sql_before
      sql_before = sql_after
    #.......................................................................................................
    return sql_after

  #---------------------------------------------------------------------------------------------------------
  _find_arguments: ( sqlx ) ->
    sqlx    = sqlx.trim()
    R       = []
    #.......................................................................................................
    level       = 0
    comma_idxs  = [ { start: null, stop: 0, }, ]
    for token in sql_lexer.tokenize sqlx
      switch token.type
        when 'left_paren'
          level++
        when 'right_paren'
          level--
        when 'comma'
          if level is 0
            comma_idxs.push { start: token.idx, stop: token.idx + token.text.length, }
        else
          null
    comma_idxs.push { start: sqlx.length, stop: null, }
    #.......................................................................................................
    for idx in [ 1 ... comma_idxs.length ]
      start = comma_idxs[ idx - 1 ].stop
      stop  = comma_idxs[ idx     ].start
      R.push sqlx[ start ... stop ].trim()
    #.......................................................................................................
    R = [] if equals R, [ '', ]
    return R


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@dbay_sqlx_function = ( T, done ) ->
  # T?.halt_on_error()
  { DBay }          = require H.dbay_path
  { SQL  }          = DBay
  db                = new DBay_sqlx()
  #.........................................................................................................
  _test = ( probe, matcher ) ->
    try
      sqlx  = probe
      sql   = db.resolve sqlx
      help rpr sqlx
      info rpr sql
      T?.eq sql, matcher
    catch error
      T?.eq "ERROR", "#{error.message}\n#{rpr probe}"
  #.........................................................................................................
  db.declare SQL"""@secret_power( @a, @b ) = power( @a, @b ) / @b;"""
  db.declare SQL"""@max( @a, @b ) = case when @a > @b then @a else @b end;"""
  db.declare SQL"""@concat( @first, @second ) = @first || @second;"""
  db.declare SQL"""@intnn() = integer not null;"""
  #.........................................................................................................
  do ->
    sqlx  = SQL"""select @secret_power( 3, 2 );"""
    sql   = SQL"""select power( 3, 2 ) / 2;"""
    _test sqlx, sql
  #.........................................................................................................
  do ->
    sqlx  = SQL"""select @max( 3, 2 ) as the_bigger_the_better;"""
    sql   = SQL"""select case when 3 > 2 then 3 else 2 end as the_bigger_the_better;"""
    _test sqlx, sql
  #.........................................................................................................
  do ->
    sqlx  = SQL"""select @concat( 'here', '\\)' );"""
    sql   = SQL"""select 'here' || '\\)';"""
    _test sqlx, sql
  #.........................................................................................................
  do ->
    sqlx  = SQL"""
      create table numbers (
        n @intnn() primary key );"""
    sql   = SQL"""
      create table numbers (
        n integer not null primary key );"""
    _test sqlx, sql
  #.........................................................................................................
  do ->
    sqlx  = SQL"""
      create table numbers (
        n @intnn primary key );"""
    sql   = SQL"""
      create table numbers (
        n integer not null primary key );"""
    _test sqlx, sql
  #.........................................................................................................
  do ->
    sqlx  = SQL"""select @concat( 'a', 'b' ) as c1, @concat( 'c', 'd' ) as c2;"""
    sql   = SQL"""select 'a' || 'b' as c1, 'c' || 'd' as c2;"""
    _test sqlx, sql
  #.........................................................................................................
  do ->
    sqlx  = SQL"""select @concat( 'a', @concat( 'c', 'd' ) );"""
    sql   = SQL"""select 'a' || 'c' || 'd';"""
    _test sqlx, sql
  #.........................................................................................................
  do ->
    sqlx  = SQL"""select @concat( ',', @concat( ',', ',' ) );"""
    sql   = SQL"""select ',' || ',' || ',';"""
    _test sqlx, sql
  #.........................................................................................................
  done?()

#-----------------------------------------------------------------------------------------------------------
@dbay_sqlx_find_arguments = ( T, done ) ->
  # T?.halt_on_error()
  { DBay }          = require H.dbay_path
  { SQL  }          = DBay
  db                = new DBay_sqlx()
  _test             = ( probe, matcher ) ->
    result = db._find_arguments probe
    help '^43-1^', probe
    urge '^43-1^', result
    T?.eq result, matcher
  _test SQL""" 3, 2 """,                      [ '3', '2', ]
  _test SQL""" 3, f( 2, 4 ) """,              [ '3', 'f( 2, 4 )' ]
  _test SQL""" 3, f( 2, @g( 4, 5, 6 ) ) """,  [ '3', 'f( 2, @g( 4, 5, 6 ) )' ]
  _test SQL""" 3, 2, "strange,name" """,      [ '3', '2', '"strange,name"' ]
  _test SQL"""           """,                 []
  done?()

#-----------------------------------------------------------------------------------------------------------
@dbay_sql_lexer = ( T, done ) ->
  { DBay }          = require H.dbay_path
  { SQL  }          = DBay
  lexer             = require '../../../../dbay-sql-lexer'
  info k for k in ( GUY.props.keys lexer ).sort()
  #.........................................................................................................
  show = ( sql, tokens ) ->
    info rpr sql
    echo dtab._tabulate tokens
    return null
  #.........................................................................................................
  probes_and_matchers = [
    [ SQL"select * from my_table",          [
      { type: 'select', text: 'select', idx: 0 },
      { type: 'star', text: '*', idx: 7 },
      { type: 'from', text: 'from', idx: 9 },
      { type: 'identifier', text: 'my_table', idx: 14 }, ], null ]
    [ SQL"select a from my_table",          [
      { type: 'select', text: 'select', idx: 0 },
      { type: 'identifier', text: 'a', idx: 7 },
      { type: 'from', text: 'from', idx: 9 },
      { type: 'identifier', text: 'my_table', idx: 14 }, ], null ]
    [ SQL"select 阿 from my_table",          [
      { type: 'select', text: 'select', idx: 0 },
      { type: 'identifier', text: '阿', idx: 7 },
      { type: 'from', text: 'from', idx: 9 },
      { type: 'identifier', text: 'my_table', idx: 14 }, ], null ]
    [ SQL"select '阿' as c$",          [
      { type: 'select', text: 'select', idx: 0 },
      { type: 'string', text: '阿', idx: 7 },
      { type: 'as', text: 'as', idx: 11 },
      { type: 'identifier', text: 'c$', idx: 14 } ], null ]
    [ SQL"42",                              [ { type: 'number', text: '42', idx: 0 }, ], null ]
    [ SQL"( 'text', 'another''text', 42 )", [ { type: 'left_paren', text: '(', idx: 0 }, { type: 'string', text: 'text', idx: 2 }, { type: 'comma', text: ',', idx: 8 }, { type: 'string', text: "another'text", idx: 10 }, { type: 'comma', text: ',', idx: 25 }, { type: 'number', text: '42', idx: 27 }, { type: 'right_paren', text: ')', idx: 30 }, ], null ]
    [ SQL"( 'text', @f( 1, 2, 3 ), 42 )",   [ { type: 'left_paren', text: '(', idx: 0 }, { type: 'string', text: 'text', idx: 2 }, { type: 'comma', text: ',', idx: 8 }, { type: 'unknown', text: '@', idx: 10 }, { type: 'identifier', text: 'f', idx: 11 }, { type: 'left_paren', text: '(', idx: 12 }, { type: 'number', text: '1', idx: 14 }, { type: 'comma', text: ',', idx: 15 }, { type: 'number', text: '2', idx: 17 }, { type: 'comma', text: ',', idx: 18 }, { type: 'number', text: '3', idx: 20 }, { type: 'right_paren', text: ')', idx: 22 }, { type: 'comma', text: ',', idx: 23 }, { type: 'number', text: '42', idx: 25 }, { type: 'right_paren', text: ')', idx: 28 }, ], null ]
    [ SQL'SELECT 42 as c;',                 [ { type: 'select', text: 'SELECT', idx: 0 }, { type: 'number', text: '42', idx: 7 }, { type: 'as', text: 'as', idx: 10 }, { type: 'identifier', text: 'c', idx: 13 }, { type: 'semicolon', text: ';', idx: 14 }, ], null ]
    [ SQL"select 'helo', 'world''';",       [ { type: 'select', text: 'select', idx: 0 }, { type: 'string', text: 'helo', idx: 7 }, { type: 'comma', text: ',', idx: 13 }, { type: 'string', text: "world'", idx: 15 }, { type: 'semicolon', text: ';', idx: 24 }, ], null ]
    [ SQL"select 'helo', 'world'''",        [ { type: 'select', text: 'select', idx: 0 }, { type: 'string', text: 'helo', idx: 7 }, { type: 'comma', text: ',', idx: 13 }, { type: 'string', text: "world'", idx: 15 }, ], null ]
    [ SQL"this is any text $%§'§",          [ { type: 'identifier', text: 'this', idx: 0 }, { type: 'operator', text: 'is', idx: 5 }, { type: 'sub_select_op', text: 'any', idx: 8 }, { type: 'identifier', text: 'text', idx: 12 }, { type: 'unknown', text: '$', idx: 17 }, { type: 'unknown', text: '%', idx: 18 }, { type: 'unknown', text: '§', idx: 19 }, { type: 'unknown', text: "'", idx: 20 }, { type: 'unknown', text: '§', idx: 21 }, ], null ]
    [ SQL"""'a' "b" [c] `d` {e}""",         [
      { type: 'string',             text: 'a', idx: 0 },
      { type: 'quoted_identifier',  text: 'b', idx: 4 },
      { type: 'unknown',            text: '[', idx: 8 },
      { type: 'identifier',         text: 'c', idx: 9 },
      { type: 'unknown',            text: ']', idx: 10 },
      { type: 'identifier',         text: 'd', idx: 12 },
      { type: 'unknown',            text: '{', idx: 16 },
      { type: 'identifier',         text: 'e', idx: 17 },
      { type: 'unknown',            text: '}', idx: 18 },
      ], null ]
    [ SQL"select * from t where t.a between 0 and 1;", [
      { type: 'select',       text: 'select',   idx: 0 },
      { type: 'star',         text: '*',        idx: 7 },
      { type: 'from',         text: 'from',     idx: 9 },
      { type: 'identifier',   text: 't',        idx: 14 },
      { type: 'where',        text: 'where',    idx: 16 },
      { type: 'identifier',   text: 't',        idx: 22 },
      { type: 'dot',          text: '.',        idx: 23 },
      { type: 'identifier',   text: 'a',        idx: 24 },
      { type: 'between',      text: 'between',  idx: 26 },
      { type: 'number',       text: '0',        idx: 34 },
      { type: 'conditional',  text: 'and',      idx: 36 },
      { type: 'number',       text: '1',        idx: 40 },
      { type: 'semicolon',    text: ';',        idx: 41 } ], null ]
    [ SQL"select * from t where t.a not between 0 and 1;", [
      { type: 'select',       text: 'select',   idx: 0 },
      { type: 'star',         text: '*',        idx: 7 },
      { type: 'from',         text: 'from',     idx: 9 },
      { type: 'identifier',   text: 't',        idx: 14 },
      { type: 'where',        text: 'where',    idx: 16 },
      { type: 'identifier',   text: 't',        idx: 22 },
      { type: 'dot',          text: '.',        idx: 23 },
      { type: 'identifier',   text: 'a',        idx: 24 },
      { type: 'not',          text: 'not',      idx: 26 },
      { type: 'between',      text: 'between',  idx: 30 },
      { type: 'number',       text: '0',        idx: 38 },
      { type: 'conditional',  text: 'and',      idx: 40 },
      { type: 'number',       text: '1',        idx: 44 },
      { type: 'semicolon',    text: ';',        idx: 45 } ], null ]
    [ SQL"select * from t where t.a not      between 0 and 1;", [
      { type: 'select',       text: 'select',   idx: 0 },
      { type: 'star',         text: '*',        idx: 7 },
      { type: 'from',         text: 'from',     idx: 9 },
      { type: 'identifier',   text: 't',        idx: 14 },
      { type: 'where',        text: 'where',    idx: 16 },
      { type: 'identifier',   text: 't',        idx: 22 },
      { type: 'dot',          text: '.',        idx: 23 },
      { type: 'identifier',   text: 'a',        idx: 24 },
      { type: 'not',          text: 'not',      idx: 26 },
      { type: 'between',      text: 'between',  idx: 35 },
      { type: 'number',       text: '0',        idx: 43 },
      { type: 'conditional',  text: 'and',      idx: 45 },
      { type: 'number',       text: '1',        idx: 49 },
      { type: 'semicolon',    text: ';',        idx: 50 } ], null ]
    [ SQL"a not in ( 'a', 'b', )", [
      { type: 'identifier',     text: 'a',      idx: 0 },
      { type: 'not',            text: 'not',    idx: 2 },
      { type: 'sub_select_op',  text: 'in',     idx: 6 },
      { type: 'left_paren',     text: '(',      idx: 9 },
      { type: 'string',         text: 'a',      idx: 11 },
      { type: 'comma',          text: ',',      idx: 14 },
      { type: 'string',         text: 'b',      idx: 16 },
      { type: 'comma',          text: ',',      idx: 19 },
      { type: 'right_paren',    text: ')',      idx: 21 } ], null ]
    [ SQL"select avg( x )", [
      { type: 'select',       text: 'select',   idx: 0 },
      { type: 'identifier',   text: 'avg',      idx: 7 },
      { type: 'left_paren',   text: '(',        idx: 10 },
      { type: 'identifier',   text: 'x',        idx: 12 },
      { type: 'right_paren',  text: ')',        idx: 14 } ], null ]
    [ SQL"select f( x )", [
      { type: 'select',       text: 'select',   idx: 0 },
      { type: 'identifier',   text: 'f',        idx: 7 },
      { type: 'left_paren',   text: '(',        idx: 8 },
      { type: 'identifier',   text: 'x',        idx: 10 },
      { type: 'right_paren',  text: ')',        idx: 12 } ], null ]
    ]
  #.........................................................................................................
  for [ probe, matcher, error, ] in probes_and_matchers
    await T.perform probe, matcher, error, -> return new Promise ( resolve, reject ) ->
      result = lexer.tokenize probe
      show probe, result
      resolve result
  #.........................................................................................................
  done?()


