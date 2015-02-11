var fieldtest;
(function (fieldtest) {
  'use strict';
  class A {
    constructor() {
      this.x = 42;
      super();
    }
  }

  // Function foo: (A) → int
  function foo(a) {
    core.print(a.x);
    return a.x;
  }

  // Function bar: (dynamic) → int
  function bar(a) {
    core.print(dart.dload(a, "x"));
    return dart.as(dart.dload(a, "x"), core.int);
  }

  // Function baz: (A) → dynamic
  function baz(a) { return a.x; }

  // Function compute: () → int
  function compute() { return 123; }

  dart.defineLazyProperties(fieldtest, {
    get y() { return compute() + 444 },
    set y(x) {},
  });

  dart.copyProperties(fieldtest, {
    get q() { return core.String['+'](core.String['+']("life, ", "the universe "), "and everything"); },
    get z() { return 42; },
    set z(value) {
      fieldtest.y = dart.as(value, core.int);
    },
  });

  // Function main: () → void
  function main() {
    let a = new A();
    foo(a);
    bar(a);
    core.print(baz(a));
  }

  // Exports:
  fieldtest.A = A;
  fieldtest.foo = foo;
  fieldtest.bar = bar;
  fieldtest.baz = baz;
  fieldtest.compute = compute;
  fieldtest.main = main;
})(fieldtest || (fieldtest = {}));