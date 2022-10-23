
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
{ equals }                = GUY.samesame
new_xregex                = require 'xregexp'
# E                         = require '../../../apps/dbay/lib/errors'
sql_lexer                 = require 'dbay-sql-lexer'


#-----------------------------------------------------------------------------------------------------------
#
#===========================================================================================================
class DBay_sqlm_error extends Error
  constructor: ( ref, message ) ->
    super()
    @message  = "#{ref} (#{@constructor.name}) #{message}"
    @ref      = ref
    return undefined ### always return `undefined` from constructor ###

#===========================================================================================================
class DBay_sqlm_TOBESPECIFIED_error            extends DBay_sqlm_error
  constructor: ( ref, message )     -> super ref, message


#-----------------------------------------------------------------------------------------------------------
#
#===========================================================================================================
class DBay_sqlx # extends ( require H.dbay_path ).DBay

  #---------------------------------------------------------------------------------------------------------
  constructor: ( cfg ) ->
    GUY.props.hide @, 'types',          require './types'
    GUY.props.hide @, '_declarations',  {}
    GUY.props.hide @, '_cmd_re',        null
    @cfg = @types.create.dbm_constructor_cfg cfg
    return undefined

  #---------------------------------------------------------------------------------------------------------
  declare: ( sqlx ) =>
    @types.validate.nonempty.text sqlx
    parameters_re           = null
    @cfg.name_re.lastIndex  = 0
    #.......................................................................................................
    unless ( match = sqlx.match @cfg.name_re )?
      throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/sqlx@1^', "syntax error in #{rpr sqlx}"
    { name, }               = match.groups
    #.......................................................................................................
    if sqlx[ @cfg.name_re.lastIndex ] is '('
      parameters_re           = /\(\s*(?<parameters>[^)]*?)\s*\)\s*=\s*/yu
      parameters_re.lastIndex = @cfg.name_re.lastIndex
      unless ( match = sqlx.match parameters_re )?
        throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/sqlx@2^', "syntax error in #{rpr sqlx}"
      { parameters, }         = match.groups
      parameters              = parameters.split /\s*,\s*/u
      parameters              = [] if equals parameters, [ '', ]
    else
      ### extension for declaration, call w/out parentheses left for later ###
      # throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/sqlx@3^', "syntax error: parentheses are obligatory but missing in #{rpr sqlx}"
      parameters              = []
    #.......................................................................................................
    current_idx                 = parameters_re?.lastIndex ? @cfg.name_re.lastIndex
    body                        = sqlx[ current_idx ... ].replace /\s*;\s*$/u, ''
    arity                       = parameters.length
    @_declare { name, parameters, arity, body, }
  #.......................................................................................................
    return null

  #---------------------------------------------------------------------------------------------------------
  _find_all_macro_names: ( sqlx ) -> ( match[ 0 ] for match from sqlx.matchAll @cfg._global_name_re )

  #---------------------------------------------------------------------------------------------------------
  _get_cmd_re: ->
    return R if ( R = @_cmd_re )?
    return /^[]/sgu if ( names = Object.keys @_declarations ).length is 0
    names = names.sort ( a, b ) ->
      a = ( Array.from a ).length
      b = ( Array.from b ).length
      return +1 if a > b
      return -1 if a < b
      return 0
    names = ( GUY.str.escape_for_regex name for name in names ).join '|'
    return @_cmd_re = /// (?<= \W | ^ ) (?<name> #{names} ) (?= \W | $ ) (?<tail> .* ) $ ///gu

  #---------------------------------------------------------------------------------------------------------
  _declare: ( cfg ) ->
    if @_declarations[ cfg.name ]?
      throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/sqlx@2^', "can not re-declare #{rpr cfg.name}"
    @_cmd_re                   = null
    @_declarations[ cfg.name ] = cfg
    return null

  #---------------------------------------------------------------------------------------------------------
  resolve: ( sqlx ) =>
    @types.validate.nonempty.text sqlx
    sql_before  = sqlx
    count       = 0
    #.......................................................................................................
    loop
      break if count++ > 10_000 ### NOTE to avoid deadlock, just in case ###
      sql_after = sql_before.replace @_get_cmd_re(), ( _matches..., idx, _sqlx, groups ) =>
        # debug '^546^', rpr sqlx[ idx ... idx + groups.name.length ]
        { name
          tail  } = groups
        #...................................................................................................
        unless ( declaration = @_declarations[ name ] )?
          ### NOTE should never happen as we always re-compile pattern from declaration keys ###
          throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/sqlx@4^', "unknown name #{rpr name}"
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
          throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/sqlx@5^', "expected #{declaration.arity} argument(s), got #{call_arity}"
        #...................................................................................................
        R = declaration.body
        for parameter, idx in declaration.parameters
          value = values[ idx ]
          R = R.replace ///#{parameter}\b///gu, value
        return R + tail
      break if sql_after is sql_before
      sql_before = sql_after
    #.......................................................................................................
    if ( macro_names = @_find_all_macro_names sql_after ).length isnt 0
      macro_names = macro_names.sort()
      macro_names = ( n for n, idx in macro_names when n isnt macro_names[ idx + 1 ] )
      macro_names = macro_names.join ', '
      throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/sqlx@5^', "found unresolved macros #{macro_names}"
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


############################################################################################################
module.exports = { DBay_sqlx, DBay_sqlm_error, DBay_sqlm_TOBESPECIFIED_error, }
