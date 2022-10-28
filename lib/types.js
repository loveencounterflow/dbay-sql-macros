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
        name_re: 'regex',
        _bare_name_re: 'dbm_global_regex',
        _paren_name_re: 'dbm_global_regex',
        _start_paren_name_re: 'dbm_anchored_regex'
      },
      // _global_name_re:  'regex'
      default: {
        prefix: '@',
        // name_re:              /[\p{Letter}_][\p{Letter}_\d]*/u
        /* this regex lifted from Intertype@0.105.1/declarations */
        name_re: /(?:[_]|\p{ID_Start})(?:[_\u{200c}\u{200d}]|\p{ID_Continue})*/u,
        _bare_name_re: null,
        _paren_name_re: null,
        _start_paren_name_re: null
      },
      // _global_name_re:  null
      create: function(cfg) {
        var R, name_re, prefix;
        R = {...this.registry.dbm_constructor_cfg.default, ...cfg};
        if (!this.isa.nonempty.text(R.prefix)) {
          return R;
        }
        if (!this.isa.regex(R.name_re)) {
          return R;
        }
        //.....................................................................................................
        prefix = escape_for_regex(R.prefix);
        name_re = R.name_re.source;
        R._escaped_prefix_re = RegExp(`\\\\${prefix}`, "gu");
        // R._prefix_replacement   = escape_for_replacement R.prefix
        R._lone_name_re = RegExp(`^${prefix}${name_re}$`, "u");
        /* TAINT as an expedient, we're using an explicit listing of 'likely' characters to compensate for
             `\b` not working in `u`nicode regexes when a word is e.g. a kanji: */
        R._bare_name_re = RegExp(`${prefix}${name_re}(?![^(])`, "sgu");
        R._paren_name_re = RegExp(`${prefix}${name_re}(?=[(])`, "sgu");
        R._start_paren_name_re = RegExp(`^${prefix}${name_re}(?=[(])`, "u");
        //.....................................................................................................
        declare.dbm_parameter_list(function(x) {
          if (!this.isa.list.of.nonempty.text(x)) {
            return false;
          }
          if (!x.every(function(p) {
            return (p.match(R._lone_name_re)) != null;
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

  /*
0x0000..0x0023
0x0025..0x002f
0x003a..0x0040
0x005b..0x005e
0x0060
0x007b..0x007f

0x0024 /[$]/
0x030..0x039 /[0-9]/

*/

}).call(this);

//# sourceMappingURL=types.js.map