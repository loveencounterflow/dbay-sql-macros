

'use strict'


############################################################################################################
GUY                       = require 'guy'
{ debug
  info
  whisper
  warn
  urge
  help }                  = GUY.trm.get_loggers 'DBAY-SQL-MACROS/types'
{ rpr
  echo }                  = GUY.trm
{ escape_for_regex }      = GUY.str
rx                        = require './regexes'


# #-----------------------------------------------------------------------------------------------------------
# escape_for_replacement = ( text ) ->
#   R = text
#   R = R.replace /[$]/g,

#-----------------------------------------------------------------------------------------------------------
module.exports = ->
  types       = new ( require 'intertype' ).Intertype()
  { declare } = types

  #---------------------------------------------------------------------------------------------------------
  declare.dbm_global_regex ( x ) ->
    return false unless @isa.regex x
    return false unless x.global
    return false if x.sticky
    return true

  #---------------------------------------------------------------------------------------------------------
  declare.dbm_anchored_regex ( x ) ->
    return false unless @isa.regex x
    return false if x.global
    return false if x.sticky
    return true


  #---------------------------------------------------------------------------------------------------------
  declare.dbm_constructor_cfg
    fields:
      prefix:               'nonempty.text'
      _any_name_re:         'regex'
      _bare_name_re:        'dbm_global_regex'
      _paren_name_re:       'dbm_global_regex'
      _start_paren_name_re: 'dbm_anchored_regex'
      _escaped_prefix_re:   'dbm_global_regex'
      # _global_name_re:  'regex'
    default:
      prefix:               '@'
      # _any_name_re:              /[\p{Letter}_][\p{Letter}_\d]*/u
      ### this regex lifted from Intertype@0.105.1/declarations ###
      _any_name_re:         null
      _bare_name_re:        null
      _paren_name_re:       null
      _start_paren_name_re: null
      _escaped_prefix_re:   null
      # _global_name_re:  null
    create: ( cfg ) ->
      R = { @registry.dbm_constructor_cfg.default..., cfg..., }
      return R unless @isa.nonempty.text R.prefix
      #.....................................................................................................
      return R if R._any_name_re?
      return R if R._bare_name_re?
      return R if R._paren_name_re?
      return R if R._start_paren_name_re?
      return R if R._escaped_prefix_re?
      #.....................................................................................................
      ### TAINT harmonize naming, use either `re` or `rx` ###
      prefix                  = escape_for_regex R.prefix
      R._any_name_re          = rx.get_rx_for_any_name          prefix, 'practical'
      R._bare_name_re         = rx.get_rx_for_bare_name         prefix, 'practical'
      R._paren_name_re        = rx.get_rx_for_paren_name        prefix, 'practical'
      R._start_paren_name_re  = rx.get_rx_for_start_paren_name  prefix, 'practical'
      R._escaped_prefix_re    = /// \\ #{prefix} ///gu
      #.....................................................................................................
      declare.dbm_parameter_list ( x ) ->
        return false unless @isa.list.of.nonempty.text x
        return false unless x.every ( p ) -> ( p.match R._lone_name_re )?
        return true
      return R

  #---------------------------------------------------------------------------------------------------------
  return types
