

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

#-----------------------------------------------------------------------------------------------------------
module.exports = ->
  types       = new ( require 'intertype' ).Intertype()
  { declare } = types

  #-----------------------------------------------------------------------------------------------------------
  declare.dbm_global_regex ( x ) ->
    return false unless @isa.regex x
    return false unless x.global
    return false if x.sticky
    return true

  #-----------------------------------------------------------------------------------------------------------
  declare.dbm_anchored_regex ( x ) ->
    return false unless @isa.regex x
    return false if x.global
    return false if x.sticky
    return true

  #-----------------------------------------------------------------------------------------------------------
  declare.dbm_constructor_cfg
    fields:
      prefix:               'nonempty.text'
      name_re:              'regex'
      _bare_name_re:        'dbm_global_regex'
      _paren_name_re:       'dbm_global_regex'
      _start_paren_name_re: 'dbm_anchored_regex'
      # _global_name_re:  'regex'
    default:
      prefix:               '@'
      name_re:              /[\p{Letter}_][\p{Letter}_\d]*/u
      _bare_name_re:        null
      _paren_name_re:       null
      _start_paren_name_re: null
      # _global_name_re:  null
    create: ( cfg ) ->
      R = { @registry.dbm_constructor_cfg.default..., cfg..., }
      return R unless @isa.nonempty.text R.prefix
      return R unless @isa.regex R.name_re
      #.......................................................................................................
      prefix                  = escape_for_regex R.prefix
      name_re                 = R.name_re.source
      R._lone_name_re         = /// ^ #{prefix} #{name_re}             $ ///u
      R._bare_name_re         = ///   #{prefix} #{name_re} \b (?! [(] )  ///sgu
      R._paren_name_re        = ///   #{prefix} #{name_re} \b (?= [(] )  ///sgu
      R._start_paren_name_re  = /// ^ #{prefix} #{name_re} \b (?= [(] )  ///u
      #.......................................................................................................
      declare.dbm_parameter_list ( x ) ->
        return false unless @isa.list.of.nonempty.text x
        return false unless x.every ( p ) -> ( p.match R._lone_name_re )?
        return true
      return R

  #-----------------------------------------------------------------------------------------------------------
  return types
