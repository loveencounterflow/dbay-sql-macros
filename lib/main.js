(function() {
  'use strict';
  var DBay_sqlm_TOBESPECIFIED_error, DBay_sqlm_arity_error, DBay_sqlm_circular_references_error, DBay_sqlm_duplicate_parameters_error, DBay_sqlm_error, DBay_sqlm_internal_error, DBay_sqlm_recursion_level_error, DBay_sqlm_unknown_macro_error, DBay_sqlm_unknown_parameters_error, DBay_sqlx, GUY, LTSORT, alert, debug, echo, equals, help, info, inspect, log, plain, praise, rpr, rx, sql_lexer, urge, warn, whisper,
    indexOf = [].indexOf;

  //###########################################################################################################
  GUY = require('guy');

  ({alert, debug, help, info, plain, praise, urge, warn, whisper} = GUY.trm.get_loggers('DBAY-SQL-MACROS'));

  ({rpr, inspect, echo, log} = GUY.trm);

  //...........................................................................................................
  ({equals} = GUY.samesame);

  // new_xregex                = require 'xregexp'
  // E                         = require '../../../apps/dbay/lib/errors'
  sql_lexer = require('dbay-sql-lexer');

  rx = require('./regexes');

  LTSORT = require('ltsort');

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

  DBay_sqlm_unknown_macro_error = class DBay_sqlm_unknown_macro_error extends DBay_sqlm_error {
    constructor(ref, name) {
      super(ref, `unknown macro ${rpr(name)}`);
    }

  };

  DBay_sqlm_recursion_level_error = class DBay_sqlm_recursion_level_error extends DBay_sqlm_error {
    constructor(ref, max_level) {
      super(ref, `maximum recursion depth of ${max_level} reached`);
    }

  };

  DBay_sqlm_circular_references_error = class DBay_sqlm_circular_references_error extends DBay_sqlm_error {
    constructor(ref, name, ref_name) {
      super(ref, `detected circular references in macro ${rpr(name)}() referencing ${rpr(ref_name)}()`);
    }

  };

  DBay_sqlm_unknown_parameters_error = class DBay_sqlm_unknown_parameters_error extends DBay_sqlm_error {
    constructor(ref, names) {
      var n;
      super(ref, `unknown parameters ${((function() {
        var results;
        results = [];
        for (n of names) {
          results.push(rpr(n));
        }
        return results;
      })()).join(', ')}`);
    }

  };

  DBay_sqlm_duplicate_parameters_error = class DBay_sqlm_duplicate_parameters_error extends DBay_sqlm_error {
    constructor(ref, names) {
      var n;
      super(ref, `duplicate parameters ${((function() {
        var results;
        results = [];
        for (n of names) {
          results.push(rpr(n));
        }
        return results;
      })()).join(', ')}`);
    }

  };

  DBay_sqlm_arity_error = class DBay_sqlm_arity_error extends DBay_sqlm_error {
    constructor(ref, name, declaration_arity, call_arity, source, values) {
      super(ref, `expected ${declaration_arity} arguments in call to macro ${rpr(name)}, got ${call_arity};
source: ${rpr(source)},
values: ${rpr(values)}`);
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
      //---------------------------------------------------------------------------------------------------------
      this._resolve = this._resolve.bind(this);
      GUY.props.hide(this, 'types', (require('./types'))());
      GUY.props.hide(this, '_declarations', {});
      GUY.props.hide(this, '_topograph', LTSORT.new_graph({
        loners: true
      }));
      this.cfg = this.types.create.dbm_constructor_cfg(cfg);
      return void 0;
    }

    declare(sqlx) {
      var arity, body, current_idx, match, name, parameters, parameters_re, position;
      this.types.validate.nonempty.text(sqlx);
      parameters_re = null;
      //.......................................................................................................
      if ((match = sqlx.match(this.cfg._start_paren_name_re)) == null) {
        throw new DBay_sqlm_TOBESPECIFIED_error('^dbay/dbm@1^', `syntax error in ${rpr(sqlx)}`);
      }
      name = match[0];
      position = match.index + name.length;
      //.......................................................................................................
      parameters_re = /\(\s*(?<parameters>[^)]*?)\s*\)\s*=\s*/yu;
      parameters_re.lastIndex = position;
      if ((match = sqlx.match(parameters_re)) == null) {
        throw new DBay_sqlm_TOBESPECIFIED_error('^dbay/dbm@2^', `syntax error in ${rpr(sqlx)}`);
      }
      ({parameters} = match.groups);
      parameters = parameters.split(/\s*,\s*/u);
      if (equals(parameters, [''])) {
        parameters = [];
      }
      if (!this.types.isa.dbm_parameter_list(parameters)) {
        throw new DBay_sqlm_TOBESPECIFIED_error('^dbay/dbm@2^', `syntax error in parameters of declaration ${rpr(sqlx)}`);
      }
      //.......................................................................................................
      current_idx = parameters_re != null ? parameters_re.lastIndex : void 0;
      if (current_idx == null) {
        throw new DBay_sqlm_internal_error('^dbay/dbm@3^', "current_idx has not been set");
      }
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
        throw new DBay_sqlm_TOBESPECIFIED_error('^dbay/dbm@4^', `can not re-declare ${rpr(cfg.name)}`);
      }
      this._validate_parameters(cfg.parameters, cfg.body);
      this._validate_cycles(cfg.name, cfg.body);
      /* TAINT use `@cfg.vanisher` instead of `|` */
      cfg.parameter_res = (function() {
        var i, len, ref1, results;
        ref1 = cfg.parameters;
        results = [];
        for (i = 0, len = ref1.length; i < len; i++) {
          p = ref1[i];
          results.push(rx.get_rx_for_parameter('practical', '|', p));
        }
        return results;
      })();
      this._declarations[cfg.name] = cfg;
      return null;
    }

    //---------------------------------------------------------------------------------------------------------
    _validate_parameters(declared_parameters, body) {
      var count, counts, duplicate_parameters, i, len, p, ref1, unknown_parameters, used_parameters;
      //.......................................................................................................
      counts = {};
      for (i = 0, len = declared_parameters.length; i < len; i++) {
        p = declared_parameters[i];
        counts[p] = (counts[p] != null ? counts[p] : counts[p] = 0) + 1;
      }
      duplicate_parameters = (function() {
        var results;
        results = [];
        for (p in counts) {
          count = counts[p];
          if (count > 1) {
            results.push(p);
          }
        }
        return results;
      })();
      if (duplicate_parameters.length !== 0) {
        throw new DBay_sqlm_duplicate_parameters_error('^dbay/dbm@4^', duplicate_parameters);
      }
      //.......................................................................................................
      used_parameters = (ref1 = body.match(this.cfg._bare_name_re)) != null ? ref1 : [];
      unknown_parameters = (function() {
        var j, len1, results;
        results = [];
        for (j = 0, len1 = used_parameters.length; j < len1; j++) {
          p = used_parameters[j];
          if (indexOf.call(declared_parameters, p) < 0) {
            results.push(p);
          }
        }
        return results;
      })();
      if (unknown_parameters.length !== 0) {
        throw new DBay_sqlm_unknown_parameters_error('^dbay/dbm@4^', unknown_parameters);
      }
      //.......................................................................................................
      return null;
    }

    //---------------------------------------------------------------------------------------------------------
    _validate_cycles(name, body) {
      var dependencies, error, i, len, ref1, ref_name, ref_names;
      ref_names = (ref1 = body.match(this.cfg._paren_name_re)) != null ? ref1 : [];
      LTSORT.add(this._topograph, name);
      for (i = 0, len = ref_names.length; i < len; i++) {
        ref_name = ref_names[i];
        LTSORT.add(this._topograph, name, ref_name);
        try {
          dependencies = LTSORT.group(this._topograph);
        } catch (error1) {
          error = error1;
          if ((error.message.match(/detected cycle involving node/)) == null) {
            throw error;
          }
          throw new DBay_sqlm_circular_references_error('^dbay/dbm@4^', name, ref_name);
        }
      }
      return null;
    }

    resolve(sqlx) {
      return this._resolve(sqlx, 0, new Set());
    }

    _resolve(sqlx, level) {
      /* NOTE using a function to avoid accidental replacement semantics */
      var R, body, call_arity, count, declaration, i, len, match, max_level, name, pnre, position, source, stop_idx, tail, value, value_idx, values;
      this.types.validate.nonempty.text(sqlx);
      R = [];
      position = 0;
      pnre = this.cfg._paren_name_re;
      count = 0;
      max_level = 50;
      //.......................................................................................................
      if (level > max_level) {
        throw new DBay_sqlm_recursion_level_error('^dbay/dbm@4^', max_level);
      }
      while (true) {
        //.......................................................................................................
        pnre.lastIndex = position;
        match = pnre.exec(sqlx);
        if (match == null) {
          // debug '^57-1^', match
          break;
        }
        R.push(sqlx.slice(position, match.index));
        name = match[0];
        //.....................................................................................................
        if ((declaration = this._declarations[name]) == null) {
          throw new DBay_sqlm_unknown_macro_error('^dbay/dbm@5^', name);
        }
        //.....................................................................................................
        position = match.index + name.length;
        tail = sqlx.slice(position);
        // urge '^57-1^', { name, position, tail, }, R
        //.....................................................................................................
        ({body} = declaration);
        ({values, stop_idx} = this._find_arguments(tail));
        call_arity = values.length;
        //.....................................................................................................
        if (call_arity !== declaration.arity) {
          source = sqlx.slice(match.index, position + stop_idx);
          throw new DBay_sqlm_arity_error('^dbay/dbm@6^', name, declaration.arity, call_arity, source, values);
        }
//.....................................................................................................
// help '^56-2^', ( rpr tail ), '->', GUY.trm.reverse GUY.trm.steel values
        for (value_idx = i = 0, len = values.length; i < len; value_idx = ++i) {
          value = values[value_idx];
          if ((value.match(pnre)) != null) {
            value = this._resolve(value, level + 1);
          }
          body = body.replace(declaration.parameter_res[value_idx], () => {
            return value;
          });
        }
        if ((body.match(pnre)) != null) {
          //.....................................................................................................
          body = this._resolve(body, level + 1);
        }
        R.push(body);
        position += stop_idx;
        count++;
      }
      if ((0 < position && position <= sqlx.length)) {
        //.......................................................................................................
        R.push(sqlx.slice(position));
      }
      // R = R.join '█'
      R = R.join('');
      if (count === 0) {
        //.....................................................................................................
        /* NOTE using a function to avoid accidental replacement semantics */
        R = sqlx;
      }
      R = R.replace(this.cfg._escaped_prefix_re, () => {
        if (level === 0) {
          return this.cfg.prefix;
        }
      });
      return R;
    }

    //---------------------------------------------------------------------------------------------------------
    _find_arguments(sqlx) {
      var R, comma_idxs, do_break, i, idx, j, len, level, ref1, ref2, start, stop, token, values;
      if (sqlx[0] !== '(') {
        throw new DBay_sqlm_internal_error('^dbay/dbm@7^', `source must start with left bracket, got ${rpr(sqlx)}`);
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
      do_break = false;
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
              do_break = true;
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
        if (do_break) {
          break;
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