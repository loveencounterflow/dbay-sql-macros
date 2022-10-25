(function() {
  'use strict';
  var GUY, debug, echo, escape_for_regex, help, info, rpr, urge, warn, whisper;

  //###########################################################################################################
  GUY = require('guy');

  ({debug, info, whisper, warn, urge, help} = GUY.trm.get_loggers('DBAY-SQL-MACROS/types'));

  ({rpr, echo} = GUY.trm);

  ({escape_for_regex} = GUY.str);

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
        name_re: /[\p{Letter}_][\p{Letter}_\d]*/u,
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
        R._lone_name_re = RegExp(`^${prefix}${name_re}$`, "u");
        R._bare_name_re = RegExp(`${prefix}${name_re}\\b(?![(])`, "sgu");
        R._paren_name_re = RegExp(`${prefix}${name_re}\\b(?=[(])`, "sgu");
        R._start_paren_name_re = RegExp(`^${prefix}${name_re}\\b(?=[(])`, "u");
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

}).call(this);

//# sourceMappingURL=types.js.map