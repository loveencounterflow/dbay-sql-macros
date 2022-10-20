(function() {
  'use strict';
  var GUY, debug, declare, echo, help, info, rpr, types, urge, warn, whisper;

  //###########################################################################################################
  GUY = require('guy');

  ({debug, info, whisper, warn, urge, help} = GUY.trm.get_loggers('DBAY-SQL-MACROS/types'));

  ({rpr, echo} = GUY.trm);

  module.exports = types = new (require('intertype')).Intertype();

  ({declare} = types);

  //-----------------------------------------------------------------------------------------------------------
  declare.dbm_constructor_cfg({
    fields: {
      name_re: 'text.or.regex'
    },
    /* TAINT use `create()` to convert, checks flags of `name_re` */
    default: {
      name_re: /^(?<name>@[^\s^(]+)/y
    }
  });

}).call(this);

//# sourceMappingURL=types.js.map