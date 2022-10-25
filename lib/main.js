(function() {
  'use strict';
  var DBay_sqlm_TOBESPECIFIED_error, DBay_sqlm_error, DBay_sqlm_internal_error, DBay_sqlx, GUY, alert, debug, echo, equals, help, info, inspect, log, plain, praise, rpr, sql_lexer, urge, warn, whisper;

  //###########################################################################################################
  GUY = require('guy');

  ({alert, debug, help, info, plain, praise, urge, warn, whisper} = GUY.trm.get_loggers('DBAY-SQL-MACROS'));

  ({rpr, inspect, echo, log} = GUY.trm);

  //...........................................................................................................
  ({equals} = GUY.samesame);

  // new_xregex                = require 'xregexp'
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
  DBay_sqlm_internal_error = class DBay_sqlm_internal_error extends DBay_sqlm_error {
    constructor(ref, message) {
      super(ref, message);
    }

  };

  DBay_sqlm_TOBESPECIFIED_error = class DBay_sqlm_TOBESPECIFIED_error extends DBay_sqlm_error {
    constructor(ref, message) {
      super(ref, message);
    }

  };

  //-----------------------------------------------------------------------------------------------------------

  //===========================================================================================================
  DBay_sqlx = class DBay_sqlx { // extends ( require H.dbay_path ).DBay
    
      //---------------------------------------------------------------------------------------------------------
    constructor(cfg) {
      //---------------------------------------------------------------------------------------------------------
      this.declare = this.declare.bind(this);
      //---------------------------------------------------------------------------------------------------------
      this.resolve = this.resolve.bind(this);
      GUY.props.hide(this, 'types', (require('./types'))());
      GUY.props.hide(this, '_declarations', {});
      this.cfg = this.types.create.dbm_constructor_cfg(cfg);
      return void 0;
    }

    declare(sqlx) {
      var arity, body, current_idx, match, name, parameters, parameters_re, position, ref1;
      this.types.validate.nonempty.text(sqlx);
      parameters_re = null;
      this.cfg.name_re.lastIndex = 0;
      //.......................................................................................................
      if ((match = sqlx.match(this.cfg._start_paren_name_re)) == null) {
        throw new DBay_sqlm_TOBESPECIFIED_error('^dbay/sqlx@1^', `syntax error in ${rpr(sqlx)}`);
      }
      name = match[0];
      position = match.index + name.length;
      //.......................................................................................................
      parameters_re = /\(\s*(?<parameters>[^)]*?)\s*\)\s*=\s*/yu;
      parameters_re.lastIndex = position;
      if ((match = sqlx.match(parameters_re)) == null) {
        throw new DBay_sqlm_TOBESPECIFIED_error('^dbay/sqlx@2^', `syntax error in ${rpr(sqlx)}`);
      }
      ({parameters} = match.groups);
      parameters = parameters.split(/\s*,\s*/u);
      if (equals(parameters, [''])) {
        parameters = [];
      }
      this.types.validate.dbm_parameter_list(parameters);
      //.......................................................................................................
      current_idx = (ref1 = parameters_re != null ? parameters_re.lastIndex : void 0) != null ? ref1 : this.cfg.name_re.lastIndex;
      body = sqlx.slice(current_idx).replace(/\s*;\s*$/u, '');
      arity = parameters.length;
      this._declare({name, parameters, arity, body});
      //.......................................................................................................
      return null;
    }

    //---------------------------------------------------------------------------------------------------------
    _declare(cfg) {
      var p;
      if (this._declarations[cfg.name] != null) {
        throw new DBay_sqlm_TOBESPECIFIED_error('^dbay/sqlx@2^', `can not re-declare ${rpr(cfg.name)}`);
      }
      cfg.parameter_res = (function() {
        var i, len, ref1, results;
        ref1 = cfg.parameters;
        results = [];
        for (i = 0, len = ref1.length; i < len; i++) {
          p = ref1[i];
          results.push(this._get_parameter_re(p));
        }
        return results;
      }).call(this);
      this._declarations[cfg.name] = cfg;
      return null;
    }

    //---------------------------------------------------------------------------------------------------------
    /* TAINT see https://shiba1014.medium.com/regex-word-boundaries-with-unicode-207794f6e7ed
     for Unicode-compliant alternatives to the trailing `\b`; OTOH we're dealing w/ mostly-ASCII SQL here */
    _get_parameter_re(parameter) {
      return RegExp(`(?<!\\\\)${GUY.str.escape_for_regex(parameter)}\\b`, "gu");
    }

    resolve(sqlx) {
      var R, body, call_arity, declaration, i, last_idx, len, match, name, parameter_idx, parameter_re, position, ref1, ref2, sql_before, stop_idx, tail, values;
      this.types.validate.nonempty.text(sqlx);
      sql_before = sqlx;
      position = 0;
      R = [];
      ref1 = sqlx.matchAll(this.cfg._paren_name_re);
      for (match of ref1) {
        name = match[0];
        last_idx = match.index + name.length;
        R.push(sqlx.slice(position, match.index));
        if (sqlx[last_idx] !== '(') {
          continue;
        }
        debug('^56-8^', this._declarations);
        debug('^56-8^', {name, last_idx}, R);
        //.....................................................................................................
        if ((declaration = this._declarations[name]) == null) {
          throw new DBay_sqlm_TOBESPECIFIED_error('^dbay/sqlx@4^', `unknown macro ${rpr(name)}`);
        }
        //.....................................................................................................
        tail = sqlx.slice(last_idx);
        ({values, stop_idx} = this._find_arguments(tail));
        call_arity = values.length;
        //.....................................................................................................
        if (call_arity !== declaration.arity) {
          throw new DBay_sqlm_TOBESPECIFIED_error('^dbay/sqlx@5^', `expected ${declaration.arity} argument(s), got ${call_arity}`);
        }
        //.....................................................................................................
        /* NOTE recursion must happen here */
        ({body} = declaration);
        ref2 = declaration.parameter_res;
        for (parameter_idx = i = 0, len = ref2.length; i < len; parameter_idx = ++i) {
          parameter_re = ref2[parameter_idx];
          /* TAINT must use lexer to make replacements */
          urge('^56-1^', rpr(values[parameter_idx]), '->', rpr(this.resolve(values[parameter_idx])));
          body = body.replace(parameter_re, this.resolve(values[parameter_idx]));
          info('^56-2^', rpr(R));
          info('^56-2^', rpr(body));
        }
        // body = body.replace parameter_re, values[ parameter_idx ]
        //.....................................................................................................
        /* TAINT ^hardwired-sigil^ this hardwires `@` as sigil */
        body = body.replace(/\\@/gu, '@');
        R.push(body);
        R.push(tail.slice(stop_idx));
      }
      if (R.length === 0) {
        return sqlx;
      } else {
        return R.join('');
      }
    }

    //---------------------------------------------------------------------------------------------------------
    _find_arguments(sqlx) {
      var R, comma_idxs, i, idx, j, len, level, ref1, ref2, start, stop, token, values;
      if (sqlx[0] !== '(') {
        throw new DBay_sqlm_internal_error('^dbay/sqlx@6^', `source must start with left bracket, got ${rpr(sqlx)}`);
      }
      sqlx = sqlx.trim();
      values = [];
      R = {
        values,
        stop_idx: null
      };
      //.......................................................................................................
      level = 0;
      comma_idxs = [
        {
          start: null,
          stop: 1
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
            if (level < 1) {
              comma_idxs.push({
                start: token.idx,
                stop: null
              });
              break;
            }
            break;
          case 'comma':
            if (level === 1) {
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
      R.stop_idx = (comma_idxs.at(-1)).start + 1/* NOTE should be Unicode-safe b/c we know it's `)` */
//.......................................................................................................
      for (idx = j = 1, ref2 = comma_idxs.length; (1 <= ref2 ? j < ref2 : j > ref2); idx = 1 <= ref2 ? ++j : --j) {
        start = comma_idxs[idx - 1].stop;
        stop = comma_idxs[idx].start;
        values.push(sqlx.slice(start, stop).trim());
      }
      if (equals(values, [''])) {
        //.......................................................................................................
        values.pop();
      }
      return R;
    }

  };

  //###########################################################################################################
  module.exports = {DBay_sqlx, DBay_sqlm_error, DBay_sqlm_TOBESPECIFIED_error};

}).call(this);

//# sourceMappingURL=main.js.map