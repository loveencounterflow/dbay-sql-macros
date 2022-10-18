
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
{ equals }                = types
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
  constructor: ->
    # super P...
    GUY.props.hide @, '_sqlx_declarations', {}
    GUY.props.hide @, '_sqlx_cmd_re',       null
    GUY.props.hide @, 'types',              types
    return undefined

  #---------------------------------------------------------------------------------------------------------
  declare: ( sqlx ) ->
    @types.validate.nonempty.text sqlx
    parameters_re           = null
    #.......................................................................................................
    name_re                 = /^(?<name>@[^\s^(]+)/y
    unless ( match = sqlx.match name_re )?
      throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/sqlx@1^', "syntax error in #{rpr sqlx}"
    { name, }               = match.groups
    #.......................................................................................................
    if sqlx[ name_re.lastIndex ] is '('
      parameters_re           = /\(\s*(?<parameters>[^)]*?)\s*\)\s*=\s*/y
      parameters_re.lastIndex = name_re.lastIndex
      unless ( match = sqlx.match parameters_re )?
        throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/sqlx@2^', "syntax error in #{rpr sqlx}"
      { parameters, }         = match.groups
      parameters              = parameters.split /\s*,\s*/
      parameters              = [] if equals parameters, [ '', ]
    else
      ### extension for declaration, call w/out parentheses left for later ###
      # throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/sqlx@3^', "syntax error: parentheses are obligatory but missing in #{rpr sqlx}"
      parameters              = []
    #.......................................................................................................
    current_idx                 = parameters_re?.lastIndex ? name_re.lastIndex
    body                        = sqlx[ current_idx ... ].replace /\s*;\s*$/, ''
    arity                       = parameters.length
    @_declare { name, parameters, arity, body, }
  #.......................................................................................................
    return null

  #---------------------------------------------------------------------------------------------------------
  _get_cmd_re: ->
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
  _declare: ( cfg ) ->
    if @_sqlx_declarations[ cfg.name ]?
      throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/sqlx@2^', "can not re-declare #{rpr cfg.name}"
    @_sqlx_cmd_re                   = null
    @_sqlx_declarations[ cfg.name ] = cfg
    return null

  #---------------------------------------------------------------------------------------------------------
  resolve: ( sqlx ) ->
    @types.validate.nonempty.text sqlx
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


############################################################################################################
module.exports = { DBay_sqlx, DBay_sqlm_error, DBay_sqlm_TOBESPECIFIED_error, }
