
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
  whisper }               = GUY.trm.get_loggers 'DBAY-SQL-MACROS'
{ rpr
  inspect
  echo
  log     }               = GUY.trm
#...........................................................................................................
{ equals }                = GUY.samesame
# new_xregex                = require 'xregexp'
# E                         = require '../../../apps/dbay/lib/errors'
sql_lexer                 = require 'dbay-sql-lexer'
rx                        = require './regexes'
LTSORT                    = require 'ltsort'


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
class DBay_sqlm_internal_error            extends DBay_sqlm_error
  constructor: ( ref, message )     -> super ref, message
class DBay_sqlm_unknown_macro_error       extends DBay_sqlm_error
  constructor: ( ref, name )        -> super ref, "unknown macro #{rpr name}"
class DBay_sqlm_recursion_level_error       extends DBay_sqlm_error
  constructor: ( ref, max_level )   -> super ref, "maximum recursion depth of #{max_level} reached"
class DBay_sqlm_circular_references_error   extends DBay_sqlm_error
  constructor: ( ref, name, ref_name ) -> super ref, \
    "detected circular references in macro #{rpr name}() referencing #{rpr ref_name}()"
class DBay_sqlm_unknown_parameters_error       extends DBay_sqlm_error
  constructor: ( ref, names )        -> super ref, "unknown parameters #{( rpr n for n from names ).join ', '}"
class DBay_sqlm_duplicate_parameters_error     extends DBay_sqlm_error
  constructor: ( ref, names )        -> super ref, "duplicate parameters #{( rpr n for n from names ).join ', '}"
class DBay_sqlm_arity_error               extends DBay_sqlm_error
  constructor: ( ref, name, declaration_arity, call_arity, source, values ) ->
    super ref, """
      expected #{declaration_arity} arguments in call to macro #{rpr name}, got #{call_arity};
      source: #{rpr source},
      values: #{rpr values}"""
class DBay_sqlm_TOBESPECIFIED_error       extends DBay_sqlm_error
  constructor: ( ref, message )     -> super ref, message


#-----------------------------------------------------------------------------------------------------------
#
#===========================================================================================================
class DBay_sqlx # extends ( require H.dbay_path ).DBay

  #---------------------------------------------------------------------------------------------------------
  constructor: ( cfg ) ->
    GUY.props.hide @, 'types',          ( require './types' )()
    GUY.props.hide @, '_declarations',  {}
    GUY.props.hide @, '_topograph',     LTSORT.new_graph { loners: true, }
    @cfg = @types.create.dbm_constructor_cfg cfg
    return undefined

  #---------------------------------------------------------------------------------------------------------
  declare: ( sqlx ) =>
    @types.validate.nonempty.text sqlx
    parameters_re               = null
    #.......................................................................................................
    unless ( match = sqlx.match @cfg._start_paren_name_re )?
      throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/dbm@1^', "syntax error in #{rpr sqlx}"
    name                        = match[ 0 ]
    position                    = match.index + name.length
    #.......................................................................................................
    parameters_re               = /\(\s*(?<parameters>[^)]*?)\s*\)\s*=\s*/yu
    parameters_re.lastIndex     = position
    unless ( match = sqlx.match parameters_re )?
      throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/dbm@2^', "syntax error in #{rpr sqlx}"
    { parameters, }             = match.groups
    parameters                  = parameters.split /\s*,\s*/u
    parameters                  = [] if equals parameters, [ '', ]
    unless @types.isa.dbm_parameter_list parameters
      throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/dbm@2^', \
        "syntax error in parameters of declaration #{rpr sqlx}"
    #.......................................................................................................
    current_idx                 = parameters_re?.lastIndex
    throw new DBay_sqlm_internal_error '^dbay/dbm@3^', "current_idx has not been set" unless current_idx?
    body                        = sqlx[ current_idx ... ].replace /\s*;\s*$/u, ''
    arity                       = parameters.length
    @_declare { name, parameters, arity, body, }
  #.......................................................................................................
    return null

  #---------------------------------------------------------------------------------------------------------
  _declare: ( cfg ) ->
    if @_declarations[ cfg.name ]?
      throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/dbm@4^', "can not re-declare #{rpr cfg.name}"
    @_validate_parameters cfg.parameters, cfg.body
    @_validate_cycles cfg.name, cfg.body
    cfg.parameter_res           = ( rx.get_rx_for_parameter @cfg, p for p in cfg.parameters )
    @_declarations[ cfg.name ]  = cfg
    return null

  #---------------------------------------------------------------------------------------------------------
  _validate_parameters: ( declared_parameters, body ) ->
    #.......................................................................................................
    counts                = {}
    counts[ p ]           = ( counts[ p ] ?= 0 ) + 1 for p in declared_parameters
    duplicate_parameters  = ( p for p, count of counts when count > 1 )
    if duplicate_parameters.length isnt 0
      throw new DBay_sqlm_duplicate_parameters_error '^dbay/dbm@4^', duplicate_parameters
    #.......................................................................................................
    used_parameters       = ( body.match @cfg._bare_name_re ) ? []
    unknown_parameters    = ( p for p in used_parameters when p not in declared_parameters )
    if unknown_parameters.length isnt 0
      throw new DBay_sqlm_unknown_parameters_error '^dbay/dbm@4^', unknown_parameters
    #.......................................................................................................
    return null

  #---------------------------------------------------------------------------------------------------------
  _validate_cycles: ( name, body ) ->
    ref_names = ( body.match @cfg._paren_name_re ) ? []
    LTSORT.add @_topograph, name
    for ref_name in ref_names
      LTSORT.add @_topograph, name, ref_name
      try dependencies = LTSORT.group @_topograph catch error
        throw error unless ( error.message.match /detected cycle involving node/ )?
        throw new DBay_sqlm_circular_references_error '^dbay/dbm@4^', name, ref_name
    return null

  #---------------------------------------------------------------------------------------------------------
  resolve: ( sqlx ) => @_resolve sqlx, 0, new Set()

  #---------------------------------------------------------------------------------------------------------
  _resolve: ( sqlx, level ) =>
    @types.validate.nonempty.text sqlx
    R         = []
    position  = 0
    pnre      = @cfg._paren_name_re
    count     = 0
    max_level = 50
    #.......................................................................................................
    if level > max_level
      throw new DBay_sqlm_recursion_level_error '^dbay/dbm@4^', max_level
    #.......................................................................................................
    loop
      pnre.lastIndex  = position
      match           = pnre.exec sqlx
      # debug '^57-1^', match
      break unless match?
      R.push sqlx[ position ... match.index ]
      name            = match[ 0 ]
      #.....................................................................................................
      unless ( declaration = @_declarations[ name ] )?
        throw new DBay_sqlm_unknown_macro_error '^dbay/dbm@5^', name
      #.....................................................................................................
      position        = match.index + name.length
      tail            = sqlx[ position ... ]
      # urge '^57-1^', { name, position, tail, }, R
      #.....................................................................................................
      { body }        = declaration
      { values
        stop_idx  }   = @_find_arguments tail
      call_arity      = values.length
      #.....................................................................................................
      unless call_arity is declaration.arity
        source = sqlx[ match.index ... position + stop_idx ]
        throw new DBay_sqlm_arity_error '^dbay/dbm@6^', name, declaration.arity, call_arity, source, values
      #.....................................................................................................
      # help '^56-2^', ( rpr tail ), '->', GUY.trm.reverse GUY.trm.steel values
      for value, value_idx in values
        value = @_resolve value, level + 1 if ( value.match pnre )?
        ### NOTE using a function to avoid accidental replacement semantics ###
        body  = body.replace declaration.parameter_res[ value_idx ], => value
      #.....................................................................................................
      body      = @_resolve body, level + 1 if ( body.match pnre )?
      R.push body
      position += stop_idx
      count++
    #.......................................................................................................
    R.push sqlx[ position ... ] if 0 < position <= sqlx.length
    R = if count is 0 then sqlx else  R.join ''
    #.....................................................................................................
    ### NOTE using a function to avoid accidental replacement semantics ###
    R = R.replace @cfg._escaped_prefix_re, => @cfg.prefix if level is 0
    R = R.replaceAll @cfg._escaped_escape_re, ( _..., { esc, } ) =>
      return if esc.length % 2 is 1 then  @cfg.escape.repeat ( esc.length - 1 ) / 2
      else                                @cfg.escape.repeat   esc.length       / 2
    return R

  #---------------------------------------------------------------------------------------------------------
  _find_arguments: ( sqlx ) ->
    unless sqlx[ 0 ] is '('
      throw new DBay_sqlm_internal_error '^dbay/dbm@7^', "source must start with left bracket, got #{rpr sqlx}"
    sqlx    = sqlx.trim()
    values  = []
    R       = { values, stop_idx: null, }
    #.......................................................................................................
    level       = 0
    comma_idxs  = [ { start: null, stop: 1, }, ]
    do_break    = false
    for token in sql_lexer.tokenize sqlx
      switch token.type
        when 'left_paren'
          level++
        when 'right_paren'
          level--
          if level < 1
            comma_idxs.push { start: token.idx, stop: null, }
            do_break = true
            break
        when 'comma'
          if level is 1
            comma_idxs.push { start: token.idx, stop: token.idx + token.text.length, }
        else
          null
      break if do_break
    R.stop_idx = ( comma_idxs.at -1 ).start + 1 ### NOTE should be Unicode-safe b/c we know it's `)` ###
    #.......................................................................................................
    for idx in [ 1 ... comma_idxs.length ]
      start = comma_idxs[ idx - 1 ].stop
      stop  = comma_idxs[ idx     ].start
      values.push sqlx[ start ... stop ].trim()
    #.......................................................................................................
    values.pop() if equals values, [ '', ]
    return R


############################################################################################################
module.exports = { DBay_sqlx, DBay_sqlm_error, DBay_sqlm_TOBESPECIFIED_error, }
