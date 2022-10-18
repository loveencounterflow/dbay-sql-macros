(function() {
  'use strict';
  var DBay_sqlm_TOBESPECIFIED_error, DBay_sqlm_error, DBay_sqlx, GUY, alert, debug, echo, equals, help, info, inspect, log, new_xregex, plain, praise, rpr, sql_lexer, types, urge, warn, whisper,
    splice = [].splice;

  //###########################################################################################################
  GUY = require('guy');

  ({alert, debug, help, info, plain, praise, urge, warn, whisper} = GUY.trm.get_loggers('DBAY/sqlx'));

  ({rpr, inspect, echo, log} = GUY.trm);

  //...........................................................................................................
  types = new (require('intertype')).Intertype();

  ({equals} = types);

  new_xregex = require('xregexp');

  // E                         = require '../../../apps/dbay/lib/errors'
  sql_lexer = require('dbay-sql-lexer');

  //-----------------------------------------------------------------------------------------------------------

  //===========================================================================================================
  DBay_sqlm_error = class DBay_sqlm_error extends Error {
    constructor(ref, message) {
      super();
      this.message = `${ref} (${this.constructor.name}) ${message}`;
      this.ref = ref;
      return void 0/* always return `undefined` from constructor */;
    }

  };

  //===========================================================================================================
  DBay_sqlm_TOBESPECIFIED_error = class DBay_sqlm_TOBESPECIFIED_error extends DBay_sqlm_error {
    constructor(ref, message) {
      super(ref, message);
    }

  };

  //-----------------------------------------------------------------------------------------------------------

  //===========================================================================================================
  DBay_sqlx = class DBay_sqlx { // extends ( require H.dbay_path ).DBay
    
      //---------------------------------------------------------------------------------------------------------
    constructor() {
      //---------------------------------------------------------------------------------------------------------
      this.declare = this.declare.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this.resolve = this.resolve.bind(this);
      // super P...
      GUY.props.hide(this, '_sqlx_declarations', {});
      GUY.props.hide(this, '_sqlx_cmd_re', null);
      GUY.props.hide(this, 'types', types);
      return void 0;
    }

    declare(sqlx) {
      var arity, body, current_idx, match, name, name_re, parameters, parameters_re, ref1;
      this.types.validate.nonempty.text(sqlx);
      parameters_re = null;
      //.......................................................................................................
      name_re = /^(?<name>@[^\s^(]+)/y;
      if ((match = sqlx.match(name_re)) == null) {
        throw new DBay_sqlm_TOBESPECIFIED_error('^dbay/sqlx@1^', `syntax error in ${rpr(sqlx)}`);
      }
      ({name} = match.groups);
      //.......................................................................................................
      if (sqlx[name_re.lastIndex] === '(') {
        parameters_re = /\(\s*(?<parameters>[^)]*?)\s*\)\s*=\s*/y;
        parameters_re.lastIndex = name_re.lastIndex;
        if ((match = sqlx.match(parameters_re)) == null) {
          throw new DBay_sqlm_TOBESPECIFIED_error('^dbay/sqlx@2^', `syntax error in ${rpr(sqlx)}`);
        }
        ({parameters} = match.groups);
        parameters = parameters.split(/\s*,\s*/);
        if (equals(parameters, [''])) {
          parameters = [];
        }
      } else {
        /* extension for declaration, call w/out parentheses left for later */
        // throw new DBay_sqlm_TOBESPECIFIED_error '^dbay/sqlx@3^', "syntax error: parentheses are obligatory but missing in #{rpr sqlx}"
        parameters = [];
      }
      //.......................................................................................................
      current_idx = (ref1 = parameters_re != null ? parameters_re.lastIndex : void 0) != null ? ref1 : name_re.lastIndex;
      body = sqlx.slice(current_idx).replace(/\s*;\s*$/, '');
      arity = parameters.length;
      this._declare({name, parameters, arity, body});
      //.......................................................................................................
      return null;
    }

    //---------------------------------------------------------------------------------------------------------
    _get_cmd_re() {
      var R, name, names;
      if ((R = this._sqlx_cmd_re) != null) {
        return R;
      }
      names = (Object.keys(this._sqlx_declarations)).sort(function(a, b) {
        a = (Array.from(a)).length;
        b = (Array.from(b)).length;
        if (a > b) {
          return +1;
        }
        if (a < b) {
          return -1;
        }
        return 0;
      });
      names = ((function() {
        var i, len, results;
        results = [];
        for (i = 0, len = names.length; i < len; i++) {
          name = names[i];
          results.push(GUY.str.escape_for_regex(name));
        }
        return results;
      })()).join('|');
      return this._sqlx_cmd_re = RegExp(`(?<=\\W|^)(?<name>${names})(?=\\W|$)(?<tail>.*)$`, "g");
    }

    //---------------------------------------------------------------------------------------------------------
    _declare(cfg) {
      if (this._sqlx_declarations[cfg.name] != null) {
        throw new DBay_sqlm_TOBESPECIFIED_error('^dbay/sqlx@2^', `can not re-declare ${rpr(cfg.name)}`);
      }
      this._sqlx_cmd_re = null;
      this._sqlx_declarations[cfg.name] = cfg;
      return null;
    }

    resolve(sqlx) {
      var count, sql_after, sql_before;
      this.types.validate.nonempty.text(sqlx);
      sql_before = sqlx;
      count = 0;
      while (true) {
        if (count++ > 10_000/* NOTE to avoid deadlock, just in case */) {
          //.......................................................................................................
          break;
        }
        sql_after = sql_before.replace(this._get_cmd_re(), (..._matches) => {
          var R, _sqlx, call_arity, center, declaration, groups, i, idx, left, len, matches, name, parameter, ref1, ref2, right, tail, value, values;
          ref1 = _matches, [..._matches] = ref1, [idx, _sqlx, groups] = splice.call(_matches, -3);
          // debug '^546^', rpr sqlx[ idx ... idx + groups.name.length ]
          ({name, tail} = groups);
          //...................................................................................................
          if ((declaration = this._sqlx_declarations[name]) == null) {
            /* NOTE should never happen as we always re-compile pattern from declaration keys */
            throw new DBay_sqlm_TOBESPECIFIED_error('^dbay/sqlx@4^', `unknown name ${rpr(name)}`);
          }
          //...................................................................................................
          if (tail.startsWith('(')) {
            matches = new_xregex.matchRecursive(tail, '\\(', '\\)', '', {
              escapeChar: '\\',
              unbalanced: 'skip-lazy',
              valueNames: ['ignore', 'left', 'center', 'right']
            });
            [left, center, right] = matches;
            tail = tail.slice(right.end);
            values = this._find_arguments(center.value);
            call_arity = values.length;
          } else {
            call_arity = 0;
          }
          //...................................................................................................
          if (call_arity !== declaration.arity) {
            throw new DBay_sqlm_TOBESPECIFIED_error('^dbay/sqlx@5^', `expected ${declaration.arity} argument(s), got ${call_arity}`);
          }
          //...................................................................................................
          R = declaration.body;
          ref2 = declaration.parameters;
          for (idx = i = 0, len = ref2.length; i < len; idx = ++i) {
            parameter = ref2[idx];
            value = values[idx];
            R = R.replace(RegExp(`${parameter}`, "g"), value);
          }
          return R + tail;
        });
        if (sql_after === sql_before) {
          break;
        }
        sql_before = sql_after;
      }
      //.......................................................................................................
      return sql_after;
    }

    //---------------------------------------------------------------------------------------------------------
    _find_arguments(sqlx) {
      var R, comma_idxs, i, idx, j, len, level, ref1, ref2, start, stop, token;
      sqlx = sqlx.trim();
      R = [];
      //.......................................................................................................
      level = 0;
      comma_idxs = [
        {
          start: null,
          stop: 0
        }
      ];
      ref1 = sql_lexer.tokenize(sqlx);
      for (i = 0, len = ref1.length; i < len; i++) {
        token = ref1[i];
        switch (token.type) {
          case 'left_paren':
            level++;
            break;
          case 'right_paren':
            level--;
            break;
          case 'comma':
            if (level === 0) {
              comma_idxs.push({
                start: token.idx,
                stop: token.idx + token.text.length
              });
            }
            break;
          default:
            null;
        }
      }
      comma_idxs.push({
        start: sqlx.length,
        stop: null
      });
//.......................................................................................................
      for (idx = j = 1, ref2 = comma_idxs.length; (1 <= ref2 ? j < ref2 : j > ref2); idx = 1 <= ref2 ? ++j : --j) {
        start = comma_idxs[idx - 1].stop;
        stop = comma_idxs[idx].start;
        R.push(sqlx.slice(start, stop).trim());
      }
      if (equals(R, [''])) {
        //.......................................................................................................
        R = [];
      }
      return R;
    }

  };

  //###########################################################################################################
  module.exports = {DBay_sqlx, DBay_sqlm_error, DBay_sqlm_TOBESPECIFIED_error};

}).call(this);

//# sourceMappingURL=main.js.map