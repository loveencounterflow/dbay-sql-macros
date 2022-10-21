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
    /* TAINT use `create()` to convert, checks flags of `name_re` */
    fields: {
      // name_re:      'text.or.regex'
      name_re: 'regex'
    },
    default: {
      name_re: /^(?<name>@[\p{Letter}_][\p{Letter}_\d]*)/yu
    }
  });

}).call(this);

//# sourceMappingURL=types.js.map