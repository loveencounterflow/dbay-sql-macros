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
    declare.dbm_mode(function(x) {
      return x === 'strict' || x === 'practical';
    });
    //---------------------------------------------------------------------------------------------------------
    declare.dbm_constructor_cfg({
      fields: {
        prefix: 'nonempty.text',
        escape: 'nonempty.text',
        mode: 'dbm_mode',
        _any_name_re: 'regex',
        _bare_name_re: 'dbm_global_regex',
        _paren_name_re: 'dbm_global_regex',
        _start_paren_name_re: 'dbm_anchored_regex',
        _escaped_prefix_re: 'dbm_global_regex',
        _prefix_esc: 'nonempty.text',
        _escape_esc: 'nonempty.text'
      },
      default: {
        prefix: '@',
        // escape:               '\\'
        escape: '%',
        mode: 'practical',
        // _any_name_re:              /[\p{Letter}_][\p{Letter}_\d]*/u
        /* this regex lifted from Intertype@0.105.1/declarations */
        _prefix_esc: null,
        _escape_esc: null,
        _any_name_re: null,
        _bare_name_re: null,
        _paren_name_re: null,
        _start_paren_name_re: null,
        _escaped_prefix_re: null
      },
      // _global_name_re:  null
      create: function(cfg) {
        var R;
        R = {...this.registry.dbm_constructor_cfg.default, ...cfg};
        if (!this.isa.nonempty.text(R.prefix)) {
          return R;
        }
        if (R._prefix_esc != null) {
          //.....................................................................................................
          return R;
        }
        if (R._escape_esc != null) {
          return R;
        }
        if (R._any_name_re != null) {
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
        R._prefix_esc = escape_for_regex(R.prefix);
        R._escape_esc = escape_for_regex(R.escape);
        R._any_name_re = rx.get_rx_for_any_name(R);
        R._bare_name_re = rx.get_rx_for_bare_name(R);
        R._paren_name_re = rx.get_rx_for_paren_name(R);
        R._start_paren_name_re = rx.get_rx_for_start_paren_name(R);
        R._escaped_prefix_re = rx.get_rx_for_escaped_prefix(R);
        R._escaped_escape_re = rx.get_rx_for_escaped_escape(R);
        // R._escaped_prefix_re    = /// #{R._escape_esc} #{R._prefix_esc} ///gu
        /* prefix, escape must not match chrs.*.forbidden.tail */
        /* prefix, escape must be different from each other (can be substrings???) */
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