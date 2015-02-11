var dart;
(function (dart) {
  var defineProperty = Object.defineProperty;
  var getOwnPropertyDescriptor = Object.getOwnPropertyDescriptor;
  var getOwnPropertyNames = Object.getOwnPropertyNames;

  // Adapted from Angular.js
  var FN_ARGS = /^function\s*[^\(]*\(\s*([^\)]*)\)/m;
  var FN_ARG_SPLIT = /,/;
  var FN_ARG = /^\s*(_?)(\S+?)\1\s*$/;
  var STRIP_COMMENTS = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg;

  function formalParameterList(fn) {
    var fnText,argDecl;
    var args=[];
    fnText = fn.toString().replace(STRIP_COMMENTS, '');
    argDecl = fnText.match(FN_ARGS);

    var r = argDecl[1].split(FN_ARG_SPLIT);
    for(var a in r){
      var arg = r[a];
      arg.replace(FN_ARG, function(all, underscore, name){
        args.push(name);
      });
    }
    return args;
  }

  function dload(obj, field) {
    if (!(field in obj)) {
      throw new core.NoSuchMethodError(obj, field);
    }
    return obj[field];
  }
  dart.dload = dload;

  function throwNoSuchMethod(obj, name, args, opt_func) {
    if (obj === void 0) obj = opt_func;
    throw new core.NoSuchMethodError(obj, name, args);
  }

  function checkAndCall(f, obj, args, name) {
    if (!(f instanceof Function)) {
      // Grab the `call` method if it's not a function.
      if (f !== null) f = f.call;
      if (!(f instanceof Function)) {
        throwNoSuchMethod(obj, method, args);
      }
    }
    var formals = formalParameterList(f);
    // TODO(vsm): Type check args!  We need to encode sufficient type info on f.
    if (formals.length < args.length) {
      throwNoSuchMethod(obj, name, args, f);
    } else if (formals.length > args.length) {
      for (var i = args.length; i < formals.length; ++i) {
        if (formals[i].indexOf("opt$") != 0) {
          throwNoSuchMethod(obj, name, args, f);
        }
      }
    }
    return f.apply(obj, args);
  }

  function dinvokef(f/*, ...args*/) {
    var args = Array.prototype.slice.call(arguments, 1);
    return checkAndCall(f, void 0, args, 'call');
  }
  dart.dinvokef = dinvokef;

  function dinvoke(obj, method/*, ...args*/) {
    var args = Array.prototype.slice.call(arguments, 2);
    return checkAndCall(obj[method], obj, args, method);
  }
  dart.dinvoke = dinvoke;

  function dindex(obj, index) {
    return checkAndCall(obj.get, obj, [index], '[]');
  }
  dart.dindex = dindex;

  function dsetindex(obj, index, value) {
    return checkAndCall(obj.set, obj, [index, value], '[]=');
  }
  dart.dsetindex = dindex;

  function dbinary(left, op, right) {
    return checkAndCall(left[op], left, [right], op);
  }
  dart.dbinary = dbinary;

  function as(obj, type) {
    // TODO(vsm): Implement.
    // if (obj == null || is(obj, type)) return obj;
    // throw new core.CastError();
    return obj;
  }
  dart.as = as;

  function is(obj, type) {
    // TODO(vsm): Implement.
    throw new core.UnimplementedError();
  }
  dart.is = is;

  function isGroundType(type) {
    // TODO(vsm): Implement.
    throw new core.UnimplementedError();
  }
  dart.isGroundType = isGroundType;

  function arity(f) {
    // TODO(vsm): Implement.
    throw new core.UnimplementedError();
  }
  dart.arity = arity;

  function equals(x, y) {
    if (x === null || y === null) return x === y;
    var eq = x['=='];
    return eq ? eq.call(x, y) : x === y;
  }
  dart.equals = equals;

  /** Checks that `x` is not null or undefined. */
  function notNull(x) {
    if (x == null) throw 'expected not-null value';
    return x;
  }
  dart.notNull = notNull;

  /**
   * Defines a lazy property.
   * After initial get or set, it will replace itself with a value property.
   */
  // TODO(jmesserly): is this the best implementation for JS engines?
  // TODO(jmesserly): reusing descriptor objects has been shown to improve
  // performance in other projects (e.g. webcomponents.js ShadowDOM polyfill).
  function defineLazyProperty(to, name, desc) {
    var init = desc.get;
    var writable = !!desc.set;
    function lazySetter(value) {
      defineProperty(to, name, { value: value, writable: writable });
    }
    function lazyGetter() {
      // Clear the init function to detect circular initialization.
      var f = init;
      if (f === null) throw 'circular initialization for field ' + name;
      init = null;

      // Compute and store the value.
      var value = f();
      lazySetter(value);
      return value;
    }
    desc.get = lazyGetter;
    desc.configurable = true;
    if (writable) desc.set = lazySetter;
    defineProperty(to, name, desc);
  }

  function defineLazyProperties(to, from) {
    var names = getOwnPropertyNames(from);
    for (var i = 0; i < names.length; i++) {
      var name = names[i];
      defineLazyProperty(to, name, getOwnPropertyDescriptor(from, name));
    }
  }
  dart.defineLazyProperties = defineLazyProperties;

  /**
   * Copy properties from source to destination object.
   * This operation is commonly called `mixin` in JS.
   */
  function copyProperties(to, from) {
    var names = getOwnPropertyNames(from);
    for (var i = 0; i < names.length; i++) {
      var name = names[i];
      defineProperty(to, name, getOwnPropertyDescriptor(from, name));
    }
    return to;
  }
  dart.copyProperties = copyProperties;

  /**
   * Returns a new type that mixes members from base and all mixins.
   *
   * Each mixin applies in sequence, with further to the right ones overriding
   * previous entries.
   *
   * For each mixin, we only take its own properties, not anything from its
   * superclass (prototype).
   */
  function mixin(base/*, ...mixins*/) {
    // Build the mixin constructor. This runs the superclass as well as each
    // of the mixins' constructors.
    var mixins = Array.prototype.slice.call(arguments, 1);
    function Mixin() {
      base.apply(this, arguments);
      // Run mixin constructors. They cannot have arguments.
      for (var i = 0; i< mixins.length; i++) mixins[i].call(this);
    }
    // Inherit statics from Base to simulate ES6 class inheritance
    // Conceptually this is: `class Mixin extends base {}`
    Mixin.__proto__ = base;
    Mixin.prototype = Object.create(base.prototype);
    // Copy each mixin, with later ones overwriting earlier entries.
    for (var i = 0; i< mixins.length; i++) {
      copyProperties(Mixin.prototype, mixins[i].prototype);
    }
    return Mixin;
  }
  dart.mixin = mixin;

  /**
   * Creates a dart:collection LinkedHashMap.
   *
   * For a map with string keys an object literal can be used, for example
   * `map({'hi': 1, 'there': 2})`.
   *
   * Otherwise an array should be used, for example `map([1, 2, 3, 4])` will
   * create a map with keys [1, 3] and values [2, 4]. Each key-value pair
   * should be adjacent entries in the array.
   *
   * For a map with no keys the function can be called with no arguments, for
   * example `map()`.
   */
  // TODO(jmesserly): this could be faster
  function map(values) {
    var map = new collection.LinkedHashMap();
    if (Array.isArray(values)) {
      for (var i = 0, end = values.length - 1; i < end; i += 2) {
        var key = values[i];
        var value = values[i + 1];
        map.set(key, value);
      }
    } else if (typeof values === 'object') {
      var keys = Object.getOwnPropertyNames(values);
      for (var i = 0; i < keys.length; i++) {
        var key = keys[i];
        var value = values[key];
        map.set(key, value);
      }
    }
    return map;
  }

  function assert(condition) {
    // TODO(jmesserly): throw assertion error.
    if (!condition) throw 'assertion failed';
  }
  dart.assert = assert;

  /**
   * Given a class and an initializer method name, creates a constructor
   * function with the same name. For example `new SomeClass.name(args)`.
   */
  function defineNamedConstructor(clazz, name) {
    var proto = clazz.prototype;
    var initMethod = proto[name];
    var ctor = function() { return initMethod.apply(this, arguments); }
    ctor.prototype = proto;
    clazz[name] = ctor;
  }
  dart.defineNamedConstructor = defineNamedConstructor;

  function stackTrace(exception) {
    throw new core.UnimplementedError();
  }
  dart.stackTrace = stackTrace;

  /** Memoize a generic type constructor function. */
  function generic(typeConstructor) {
    // TODO(jmesserly): implement this. Memoize so we return the same instance
    // for the same type, and save the type arguments for easy reflection.
    return typeConstructor;
  }
  dart.generic = generic;

})(dart || (dart = {}));