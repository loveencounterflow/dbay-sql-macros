

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
{ copy_regex }            = GUY.samesame
module.exports            = types = new ( require 'intertype' ).Intertype()
{ declare }               = types


#-----------------------------------------------------------------------------------------------------------
declare.dbm_global_regex ( x ) ->
  return false unless @isa.regex x
  return false unless x.global
  return false unless x.sticky
  return true

#-----------------------------------------------------------------------------------------------------------
declare.dbm_nonglobal_sticky_regex ( x ) ->
  return false unless @isa.regex x
  return false if x.global
  return false unless x.sticky
  return true

# #-----------------------------------------------------------------------------------------------------------
# ### TAINT must adapt lexer in order to allow for configurable brackets ###
# declare.dbm_brackets ( x ) ->
#   return false unless @isa.list x
#   return false unless x.length is 2
#   return false unless @isa.nonempty.text x[ 0 ]
#   return false unless @isa.nonempty.text x[ 1 ]
#   return true

#-----------------------------------------------------------------------------------------------------------
declare.dbm_constructor_cfg
  ### TAINT use `create()` to convert, checks flags of `name_re` ###
  fields:
    # name_re:          'dbm_nonglobal_sticky_regex'
    # name_re:          'dbm_global_regex'
    prefix:           'nonempty.text'
    name_re:          'regex'
    _bare_name_re:    'regex'
    _name_paren_re:   'regex'
    _global_name_re:  'regex'
    # brackets:         'dbm_brackets'
  default:
    ### TAINT see TAINT ^hardwired-sigil^ in main.coffee ###
    ### TAINT should accept sigil, name_re as distinct `cfg` settings ###
    prefix:           '@'
    name_re:          /[\p{Letter}_][\p{Letter}_\d]*/u
    _bare_name_re:    null
    _name_paren_re:   null
    _global_name_re:  null
    # brackets:         [ '(', ')', ]
  create: ( cfg ) ->
    R = { @registry.dbm_constructor_cfg.default..., cfg..., }
    return R unless @isa.nonempty.text R.prefix
    return R unless @isa.regex R.name_re
    prefix              = escape_for_regex R.prefix
    name_re             = R.name_re.source
    R._bare_name_re     = /// #{prefix} #{name_re} \b (?! [(] ) ///ysu
    R._name_paren_re    = /// #{prefix} #{name_re} \( ///ysu
    R._global_name_re   = copy_regex R._bare_name_re, { global: true, dotAll: true, sticky: false, }
    # R._global_name_re = copy_regex R.name_re, { global: true, }
    return R

