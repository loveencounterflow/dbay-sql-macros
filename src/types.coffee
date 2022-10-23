

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
module.exports            = types = new ( require 'intertype' ).Intertype()
{ declare }               = types


#-----------------------------------------------------------------------------------------------------------
declare.dbm_global_regex ( x ) ->
  return false unless @isa.regex x
  return false unless x.global
  return false if x.sticky
  return true

#-----------------------------------------------------------------------------------------------------------
declare.dbm_nonglobal_sticky_regex ( x ) ->
  return false unless @isa.regex x
  return false if x.global
  return false unless x.sticky
  return true

#-----------------------------------------------------------------------------------------------------------
declare.dbm_constructor_cfg
  ### TAINT use `create()` to convert, checks flags of `name_re` ###
  fields:
    # name_re:      'text.or.regex'
    name_re:          'dbm_nonglobal_sticky_regex'
    _global_name_re:  'dbm_global_regex'
  default:
    name_re:      /(?<name>@[\p{Letter}_][\p{Letter}_\d]*)/yu
  create: ( cfg ) ->
    R = { @registry.dbm_constructor_cfg.default..., cfg..., }
    return R unless @isa.regex R.name_re
    R._global_name_re = GUY.samesame.copy_regex R.name_re, { global: true, sticky: false, }
    return R

