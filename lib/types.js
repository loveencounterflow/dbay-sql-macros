(function() {
  'use strict';
  var GUY, debug, echo, escape_for_regex, help, info, rpr, rx, urge, warn, whisper;

  //###########################################################################################################
  GUY = require('guy');

  ({debug, info, whisper, warn, urge, help} = GUY.trm.get_loggers('DBAY-SQL-MACROS/types'));

  ({rpr, echo} = GUY.trm);

  ({escape_for_regex} = GUY.str);

  rx = require('./regexes');

  // #-----------------------------------------------------------------------------------------------------------
  // escape_for_replacement = ( text ) ->
  //   R = text
  //   R = R.replace /[$]/g,

  //-----------------------------------------------------------------------------------------------------------
  module.exports = function() {
    var declare, types;
    types = new (require('intertype')).Intertype();
    ({declare} = types);
    //---------------------------------------------------------------------------------------------------------
    declare.dbm_global_regex(function(x) {
      if (!this.isa.regex(x)) {
        return false;
      }
      if (!x.global) {
        return false;
      }
      if (x.sticky) {
        return false;
      }
      return true;
    });
    //---------------------------------------------------------------------------------------------------------
    declare.dbm_anchored_regex(function(x) {
      if (!this.isa.regex(x)) {
        return false;
      }
      if (x.global) {
        return false;
      }
      if (x.sticky) {
        return false;
      }
      return true;
    });
    //---------------------------------------------------------------------------------------------------------
    declare.dbm_constructor_cfg({
      fields: {
        prefix: 'nonempty.text',
        _any_name_re: 'regex',
        _bare_name_re: 'dbm_global_regex',
        _paren_name_re: 'dbm_global_regex',
        _start_paren_name_re: 'dbm_anchored_regex',
        _escaped_prefix_re: 'dbm_global_regex'
      },
      // _global_name_re:  'regex'
      default: {
        prefix: '@',
        // _any_name_re:              /[\p{Letter}_][\p{Letter}_\d]*/u
        /* this regex lifted from Intertype@0.105.1/declarations */
        _any_name_re: null,
        _bare_name_re: null,
        _paren_name_re: null,
        _start_paren_name_re: null,
        _escaped_prefix_re: null
      },
      // _global_name_re:  null
      create: function(cfg) {
        var R, prefix;
        R = {...this.registry.dbm_constructor_cfg.default, ...cfg};
        if (!this.isa.nonempty.text(R.prefix)) {
          return R;
        }
        if (R._any_name_re != null) {
          //.....................................................................................................
          return R;
        }
        if (R._bare_name_re != null) {
          return R;
        }
        if (R._paren_name_re != null) {
          return R;
        }
        if (R._start_paren_name_re != null) {
          return R;
        }
        if (R._escaped_prefix_re != null) {
          return R;
        }
        //.....................................................................................................
        /* TAINT harmonize naming, use either `re` or `rx` */
        prefix = escape_for_regex(R.prefix);
        R._any_name_re = rx.get_rx_for_any_name(prefix, 'practical');
        R._bare_name_re = rx.get_rx_for_bare_name(prefix, 'practical');
        R._paren_name_re = rx.get_rx_for_paren_name(prefix, 'practical');
        R._start_paren_name_re = rx.get_rx_for_start_paren_name(prefix, 'practical');
        R._escaped_prefix_re = RegExp(`\\\\${prefix}`, "gu");
        //.....................................................................................................
        declare.dbm_parameter_list(function(x) {
          if (!this.isa.list.of.nonempty.text(x)) {
            return false;
          }
          if (!x.every(function(p) {
            return (p.match(R._bare_name_re)) != null;
          })) {
            return false;
          }
          return true;
        });
        return R;
      }
    });
    //---------------------------------------------------------------------------------------------------------
    return types;
  };

}).call(this);

//# sourceMappingURL=types.js.map