library ddc.src.codegen.js_codegen;

import 'dart:io' show Directory;

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart' hide ConstantEvaluator;
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/scanner.dart'
    show StringToken, Token, TokenType;
import 'package:analyzer/src/generated/constant.dart';
import 'package:path/path.dart' as path;

import 'package:ddc/src/checker/rules.dart';
import 'package:ddc/src/info.dart';
import 'package:ddc/src/report.dart';
import 'package:ddc/src/utils.dart';
import 'code_generator.dart';

// This must match the optional parameter name used in runtime.js
const String optionalParameters = r'opt$';

class JSCodegenVisitor extends GeneralizingAstVisitor with ConversionVisitor {
  final LibraryInfo libraryInfo;
  final TypeRules rules;
  final OutWriter out;
  final String _libraryName;

  /// The variable for the target of the current `..` cascade expression.
  SimpleIdentifier _cascadeTarget;

  ClassDeclaration currentClass;

  final ConstantVisitor _constVisitor;
  final _exports = <String>[];
  final _lazyFields = <VariableDeclaration>[];
  final _properties = <FunctionDeclaration>[];

  JSCodegenVisitor(LibraryInfo libraryInfo, TypeRules rules, this.out)
      : libraryInfo = libraryInfo,
        rules = rules,
        _constVisitor = new ConstantVisitor.con1(rules.provider),
        _libraryName = _jsLibraryName(libraryInfo.library);

  Element get currentLibrary => libraryInfo.library;

  void generateLibrary(
      Iterable<CompilationUnit> units, CheckerReporter reporter) {
    out.write("""
var $_libraryName;
(function ($_libraryName) {
  'use strict';
""", 2);

    for (var unit in units) {
      // TODO(jmesserly): this is needed because RestrictedTypeRules can send
      // messages to CheckerReporter, for things like missing types.
      // We should probably refactor so this can't happen.
      reporter.enterSource(unit.element.source);
      unit.accept(this);
      reporter.leaveSource();
    }

    if (_exports.isNotEmpty) out.write('// Exports:\n');

    // TODO(jmesserly): make these immutable in JS?
    for (var name in _exports) {
      out.write('${_libraryName}.$name = $name;\n');
    }

    out.write("""
})($_libraryName || ($_libraryName = {}));
""", -2);
  }

  @override
  void visitCompilationUnit(CompilationUnit node) {
    _visitNode(node.scriptTag);
    _visitNodeList(node.directives);
    for (var child in node.declarations) {
      // Attempt to group adjacent fields/properties.
      if (child is! TopLevelVariableDeclaration) _flushLazyFields();
      if (child is! FunctionDeclaration) _flushLibraryProperties();

      child.accept(this);
    }
    // Flush any unwritten fields/properties.
    _flushLazyFields();
    _flushLibraryProperties();
  }

  bool isPublic(String name) => !name.startsWith('_');

  /// Conversions that we don't handle end up here.
  @override
  void visitConversion(Conversion node) {
    var from = node.baseType;
    var to = node.convertedType;

    // num to int or num to double is just a null check.
    if (rules.isNumType(from) &&
        (rules.isIntType(to) || rules.isDoubleType(to))) {
      // TODO(jmesserly): a lot of these checks are meaningless, as people use
      // `num` to mean "any kind of number" rather than "could be null".
      // The core libraries especially suffer from this problem, with many of
      // the `num` methods returning `num`.
      out.write('dart.notNull(');
      node.expression.accept(this);
      out.write(')');
      return;
    }

    out.write('/* Unimplemented: ');
    out.write('${node.description}');
    out.write(' */ ');
    node.expression.accept(this);
  }

  @override
  void visitAsExpression(AsExpression node) {
    out.write('/* Unimplemented: as ${node.type.name.name}. */');
    node.expression.accept(this);
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    // TODO(vsm): Do we need to record type info the generated code for a
    // typedef?
  }

  @override
  void visitTypeName(TypeName node) {
    _visitNode(node.name);
    _visitNode(node.typeArguments);
  }

  @override
  void visitTypeParameterList(TypeParameterList node) {
    out.write('/* Unimplemented $node */');
  }

  @override
  void visitTypeArgumentList(TypeArgumentList node) {
    out.write('/* Unimplemented $node */');
  }

  @override
  void visitClassTypeAlias(ClassTypeAlias node) {
    var name = node.name.name;
    out.write('class $name extends dart.mixin(');
    _visitNodeList(node.withClause.mixinTypes, separator: ', ');
    out.write(') {}\n\n');
    if (isPublic(name)) _exports.add(name);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    currentClass = node;

    var name = node.name.name;
    out.write('class $name');
    _visitNode(node.typeParameters);

    if (node.withClause != null) {
      out.write(' extends dart.mixin(');
      if (node.extendsClause != null) {
        _visitNode(node.extendsClause.superclass);
      } else {
        out.write('Object');
      }
      _visitNodeList(node.withClause.mixinTypes, prefix: ', ', separator: ', ');
      out.write(')');
    } else if (node.extendsClause != null) {
      out.write(' extends ');
      _visitNode(node.extendsClause.superclass);
    }

    out.write(' {\n', 2);

    var ctors = new List<ConstructorDeclaration>();
    var fields = new List<FieldDeclaration>();
    var staticFields = new List<FieldDeclaration>();
    for (var member in node.members) {
      if (member is ConstructorDeclaration) {
        ctors.add(member);
      } else if (member is FieldDeclaration) {
        (member.isStatic ? staticFields : fields).add(member);
      }
    }

    // Iff no constructor is specified for a class C, it implicitly has a
    // default constructor `C() : super() {}`, unless C is class Object.
    if (ctors.isEmpty && !node.element.type.isObject) {
      _generateImplicitConstructor(node, fields);
    }

    for (var member in node.members) {
      if (member is ConstructorDeclaration) {
        _generateConstructor(member, name, fields);
      } else if (member is MethodDeclaration) {
        member.accept(this);
      }
    }

    out.write('}\n', -2);

    if (isPublic(name)) _exports.add(name);

    // Named constructors
    for (ConstructorDeclaration member in ctors) {
      if (member.name != null) {
        var ctorName = member.name.name;

        out.write('$name.$ctorName = function(');
        _visitNode(member.parameters);
        out.write(') { this.__init_$ctorName(');
        _visitNode(member.parameters);
        out.write(') };\n');
        out.write('$name.$ctorName.prototype = $name.prototype;\n');
      }
    }

    // Static fields
    var lazyStatics = <VariableDeclaration>[];
    for (FieldDeclaration member in staticFields) {
      for (VariableDeclaration field in member.fields.variables) {
        var prefix = '$name.${field.name.name}';
        if (field.initializer == null) {
          out.write('$prefix = null;\n');
        } else if (field.isConst || _isFieldInitConstant(field)) {
          out.write('$prefix = ');
          field.initializer.accept(this);
          out.write(';\n');
        } else {
          lazyStatics.add(field);
        }
      }
    }
    _writeLazyFields(name, lazyStatics);

    out.write('\n');
    currentClass = null;
  }

  /// Generates the implicit default constructor for class C of the form
  /// `C() : super() {}`.
  void _generateImplicitConstructor(
      ClassDeclaration node, List<FieldDeclaration> fields) {
    // If we don't have a method body, use the implicit JS ctor.
    if (fields.isEmpty) return;
    out.write('constructor() {\n', 2);
    _initializeFields(fields);
    out.write('super();\n');
    out.write('}\n', -2);
  }

  void _generateConstructor(ConstructorDeclaration node, String className,
      List<FieldDeclaration> fields) {
    if (node.name != null) {
      // We generate named constructors as initializer methods in the class;
      // this allows use of `super` for instance methods/properties.
      out.write('__init_${node.name.name}(');
    } else {
      out.write('constructor(');
    }
    _visitNode(node.parameters);
    out.write(') {\n', 2);
    _generateConstructorBody(node, fields);
    out.write('}\n', -2);
  }

  void _generateConstructorBody(
      ConstructorDeclaration node, List<FieldDeclaration> fields) {
    // Wacky factory redirecting constructors: factory Foo.q(x, y) = Bar.baz;
    if (node.redirectedConstructor != null) {
      out.write('return new ');
      node.redirectedConstructor.accept(this);
      out.write('(');
      _visitNode(node.parameters);
      out.write(');\n');
      return;
    }

    // Generate optional/named argument value assignment. These can not have
    // side effects, and may be used by the constructor's initializers, so it's
    // nice to do them first.
    _generateArgumentInitializers(node.parameters);

    // Redirecting constructors: these are not allowed to have initializers,
    // and the redirecting ctor invocation runs before field initializers.
    var redirectCall = node.initializers.firstWhere(
        (i) => i is RedirectingConstructorInvocation, orElse: () => null);

    if (redirectCall != null) {
      redirectCall.accept(this);
      return;
    }

    // Initializers only run for non-factory constructors.
    if (node.factoryKeyword == null) {
      // Generate field initializers.
      // These are expanded into each non-redirecting constructor.
      // In the future we may want to create an initializer function if we have
      // multiple constructors, but it needs to be balanced against readability.
      _initializeFields(fields, node.parameters, node.initializers);

      var superCall = node.initializers.firstWhere(
          (i) => i is SuperConstructorInvocation, orElse: () => null);

      // If no superinitializer is provided, an implicit superinitializer of the
      // form `super()` is added at the end of the initializer list, unless the
      // enclosing class is class Object.
      ClassElement element = (node.parent as ClassDeclaration).element;
      if (superCall == null) {
        if (!element.type.isObject && !element.supertype.isObject) {
          _superConstructorCall(node);
        }
      } else {
        _superConstructorCall(
            node, superCall.constructorName, superCall.argumentList);
      }
    }

    var body = node.body;
    if (body is BlockFunctionBody) {
      body.block.statements.accept(this);
    } else if (body is ExpressionFunctionBody) {
      _visitNode(body.expression, prefix: 'return ', suffix: ';\n');
    } else {
      assert(body is EmptyFunctionBody);
    }
  }

  @override
  void visitRedirectingConstructorInvocation(
      RedirectingConstructorInvocation node) {
    var parent = node.parent as ConstructorDeclaration;
    String name;
    if (parent.name != null) {
      name = parent.name.name;
    } else {
      name = _typeName((parent.parent as ClassDeclaration).element.type);
    }
    out.write('$name.call(this');
    var args = node.argumentList;
    if (args != null) {
      _visitNodeList(args.arguments, prefix: ', ', separator: ', ');
    }
    out.write(');\n');
  }

  void _superConstructorCall(ConstructorDeclaration ctor,
      [SimpleIdentifier superName, ArgumentList args]) {

    // If we're calling default super from a named initializer method, we need
    // to do ES5 style `TypeName.call(this, <args>)`, otherwise we use `super`.
    if (ctor.name != null && superName == null) {
      var supertype = (ctor.parent as ClassDeclaration).element.supertype;
      out.write('${_typeName(supertype)}.call(this');
      if (args != null) {
        _visitNodeList(args.arguments, prefix: ', ', separator: ', ');
      }
    } else {
      out.write('super');
      if (superName != null) out.write('.__init_${superName.name}');
      out.write('(');
      if (args != null) {
        _visitNodeList(args.arguments, separator: ', ');
      }
    }
    out.write(');\n');
  }

  /// Initialize fields. They follow the sequence:
  ///
  ///   1. field declaration initializer if non-const,
  ///   2. field initializing parameters,
  ///   3. constructor field initializers,
  ///   4. initialize fields not covered in 1-3
  void _initializeFields(List<FieldDeclaration> fields,
      [FormalParameterList parameters,
      NodeList<ConstructorInitializer> initializers]) {

    // Run field initializers if they can have side-effects.
    var unsetFields = new Map<String, Expression>();
    for (var declaration in fields) {
      for (var field in declaration.fields.variables) {
        if (_isFieldInitConstant(field)) {
          unsetFields[field.name.name] = field.initializer;
        } else {
          _visitNode(field, suffix: ';\n');
        }
      }
    }

    // Initialize fields from `this.fieldName` parameters.
    if (parameters != null) {
      for (var p in parameters.parameters) {
        if (p is DefaultFormalParameter) p = p.parameter;
        if (p is FieldFormalParameter) {
          var name = p.identifier.name;
          out.write('this.$name = $name;\n');
          unsetFields.remove(name);
        }
      }
    }

    // Run constructor field initializers such as `: foo = bar.baz`
    if (initializers != null) {
      for (var init in initializers) {
        if (init is ConstructorFieldInitializer) {
          init.fieldName.accept(this);
          out.write(' = ');
          init.expression.accept(this);
          out.write(';\n');
          unsetFields.remove(init.fieldName.name);
        }
      }
    }

    // Initialize all remaining fields
    unsetFields.forEach((name, expression) {
      out.write('this.$name = ');
      if (expression != null) {
        expression.accept(this);
      } else {
        out.write('null');
      }
      out.write(';\n');
    });
  }

  FormalParameterList _parametersOf(node) {
    if (node is MethodDeclaration) return node.parameters;
    if (node is FunctionDeclaration) node = node.functionExpression;
    if (node is FunctionExpression) return node.parameters;
    return null;
  }

  bool _hasArgumentInitializers(FormalParameterList parameters) {
    if (parameters == null) return false;
    return parameters.parameters.any((p) => p.kind != ParameterKind.REQUIRED);
  }

  void _generateArgumentInitializers(FormalParameterList parameters) {
    if (parameters == null) return;
    for (var param in parameters.parameters) {
      // TODO(justinfagnani): rename identifier if necessary
      var name = param.identifier.name;

      if (param.kind == ParameterKind.NAMED) {
        out.write('let $name = opt\$.$name === undefined ? ');
        if (param is DefaultFormalParameter && param.defaultValue != null) {
          param.defaultValue.accept(this);
        } else {
          out.write('null');
        }
        out.write(' : opt\$.$name;\n');
      } else if (param.kind == ParameterKind.POSITIONAL) {
        out.write('if ($name === undefined) $name = ');
        if (param is DefaultFormalParameter && param.defaultValue != null) {
          param.defaultValue.accept(this);
        } else {
          out.write('null');
        }
        out.write(';\n');
      }
    }
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.isAbstract) return;

    if (node.isStatic) {
      out.write('static ');
    }
    if (node.isGetter) {
      out.write('get ');
    } else if (node.isSetter) {
      out.write('set ');
    }

    var name = node.name;
    out.write('$name(');
    _visitNode(node.parameters);
    out.write(') ');
    _visitNode(node.body);
    out.write('\n');
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    assert(node.parent is CompilationUnit);

    if (node.isGetter || node.isSetter) {
      // Add these later so we can use getter/setter syntax.
      _properties.add(node);
    } else {
      _flushLibraryProperties();
      _writeFunctionDeclaration(node);
    }
  }

  void _writeFunctionDeclaration(FunctionDeclaration node) {
    var name = node.name.name;

    if (node.isGetter) {
      out.write('get ');
    } else if (node.isSetter) {
      out.write('set ');
    } else {
      out.write("// Function $name: ${node.element.type}\n");
      out.write('function ');
    }

    out.write('$name');
    node.functionExpression.accept(this);

    if (!node.isGetter && !node.isSetter) {
      out.write('\n');
      if (isPublic(name)) _exports.add(name);
      out.write('\n');
    }
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node.parent is FunctionDeclaration) {
      out.write('(');
      _visitNode(node.parameters);
      out.write(') ');
      node.body.accept(this);
    } else {
      out.write("(");
      _visitNode(node.parameters);
      out.write(") => ");
      var body = node.body;
      if (body is ExpressionFunctionBody) body = body.expression;
      body.accept(this);
    }
  }

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    var func = node.functionDeclaration;
    if (func.isGetter || func.isSetter) {
      out.write('/* Unimplemented function get/set statement: $node */');
      return;
    }

    var name = func.name.name;
    out.write("// Function $name: ${func.element.type}\n");
    out.write('function $name');
    func.functionExpression.accept(this);
    out.write('\n');
  }

  /// Writes a simple identifier. This can handle implicit `this` as well as
  /// going through the qualified library name if necessary.
  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    var e = node.staticElement;
    if (e.enclosingElement is CompilationUnitElement &&
        (e.library != libraryInfo.library || _needsModuleGetter(e))) {
      out.write('${getLibraryId(e.library)}.');
    } else if (currentClass != null &&
        e.enclosingElement == currentClass.element) {
      if (e is PropertyAccessorElement && !e.variable.isStatic ||
          e is ClassMemberElement && !e.isStatic) {
        out.write('this.');
      }
    }
    out.write(node.name);
  }

  String _typeName(InterfaceType type) {
    var name = type.name;
    var library = type.element.library;
    return library == currentLibrary ? name : '${getLibraryId(library)}.$name';
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    node.leftHandSide.accept(this);
    out.write(' = ');
    node.rightHandSide.accept(this);
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    var parameters = _parametersOf(node.parent);
    var initArgs = parameters != null && _hasArgumentInitializers(parameters);
    if (initArgs) {
      out.write('{\n', 2);
      _generateArgumentInitializers(parameters);
    } else {
      out.write('{ ');
    }
    out.write('return ');
    node.expression.accept(this);
    if (initArgs) {
      out.write('\n}', -2);
    } else {
      out.write('; }');
    }
  }

  @override
  void visitEmptyFunctionBody(EmptyFunctionBody node) {
    out.write('{}');
  }

  @override
  void visitBlockFunctionBody(BlockFunctionBody node) {
    out.write('{\n', 2);
    _generateArgumentInitializers(_parametersOf(node.parent));
    _visitNodeList(node.block.statements);
    out.write('}', -2);
  }

  @override
  void visitBlock(Block node) {
    out.write("{\n", 2);
    node.statements.accept(this);
    out.write("}\n", -2);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (rules.isDynamicCall(node.methodName)) {
      out.write('/* Unimplemented dynamic method call: $node */');
      return;
    }

    var target = node.isCascaded ? _cascadeTarget : node.target;
    _visitNode(target, suffix: '.');
    node.methodName.accept(this);
    node.argumentList.accept(this);
  }

  @override
  void visitArgumentList(ArgumentList node) {
    out.write('(');
    _visitNodeList(node.arguments, separator: ', ');
    out.write(')');
  }

  @override
  void visitFormalParameterList(FormalParameterList node) {
    int length = node.parameters.length;
    bool hasOptionalParameters = false;
    bool hasPositionalParameters = false;

    for (int i = 0; i < length; i++) {
      var param = node.parameters[i];
      if (param.kind == ParameterKind.NAMED) {
        hasOptionalParameters = true;
      } else {
        if (hasPositionalParameters) out.write(', ');
        hasPositionalParameters = true;
        param.accept(this);
      }
    }
    if (hasOptionalParameters) {
      if (hasPositionalParameters) out.write(', ');
      out.write(optionalParameters);
    }
  }

  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    // Named parameters are handled as a single object, so we skip individual
    // parameters
    if (node.kind != ParameterKind.NAMED) {
      out.write(node.identifier.name);
    }
  }

  @override
  void visitDefaultFormalParameter(DefaultFormalParameter node) {
    // Named parameters are handled as a single object, so we skip individual
    // parameters
    if (node.kind != ParameterKind.NAMED) {
      out.write(node.identifier.name);
    }
  }

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    node.expression.accept(this);
    out.write(';\n');
  }

  @override
  void visitEmptyStatement(EmptyStatement node) {
    out.write(';\n');
  }

  @override
  void visitAssertStatement(AssertStatement node) {
    // TODO(jmesserly): only emit in checked mode.
    _visitNode(node.condition, prefix: 'dart.assert(', suffix: ');\n');
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    out.write('return');
    _visitNode(node.expression, prefix: ' ');
    out.write(';\n');
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (var field in node.variables.variables) {
      var name = field.name.name;
      if (field.isConst) {
        // constant fields don't change, so we can generate them as `let`
        // but add them to the module's exports
        _visitNode(field, prefix: 'let ', suffix: ';\n');
        if (isPublic(name)) _exports.add(name);
      } else if (_isFieldInitConstant(field)) {
        _visitNode(field, suffix: ';\n');
      } else {
        _lazyFields.add(field);
      }
    }
  }

  @override
  void visitVariableDeclarationList(VariableDeclarationList node) {
    _visitNodeList(node.variables, prefix: 'let ', separator: ', ');
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    node.name.accept(this);
    out.write(' = ');
    if (node.initializer != null) {
      node.initializer.accept(this);
    } else {
      // explicitly initialize to null, so we don't need to worry about
      // `undefined`.
      // TODO(jmesserly): do this only for vars that aren't definitely assigned.
      out.write('null');
    }
  }

  void _flushLazyFields() {
    if (_lazyFields.isEmpty) return;

    _writeLazyFields(_libraryName, _lazyFields);
    out.write('\n');

    _lazyFields.clear();
  }

  void _writeLazyFields(String objExpr, List<VariableDeclaration> fields) {
    if (fields.isEmpty) return;

    out.write('dart.defineLazyProperties($objExpr, {\n', 2);
    for (var node in fields) {
      var name = node.name.name;
      out.write('get $name() { return ');
      node.initializer.accept(this);
      out.write(' },\n');
      // TODO(jmesserly): we're using a dummy setter to indicate writable.
      if (!node.isFinal) out.write('set $name(x) {},\n');
    }
    out.write('});\n', -2);
  }

  void _flushLibraryProperties() {
    if (_properties.isEmpty) return;

    out.write('dart.copyProperties($_libraryName, {\n', 2);
    for (var node in _properties) {
      _writeFunctionDeclaration(node);
      out.write(',\n');
    }
    out.write('});\n\n', -2);

    _properties.clear();
  }

  @override
  void visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    _visitNode(node.variables);
    out.write(';\n');
  }

  @override
  void visitConstructorName(ConstructorName node) {
    node.type.name.accept(this);
    if (node.name != null) {
      out.write('.');
      node.name.accept(this);
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    out.write('new ');
    node.constructorName.accept(this);
    node.argumentList.accept(this);
  }

  bool typeIsPrimitiveInJS(DartType t) => rules.isIntType(t) ||
      rules.isDoubleType(t) ||
      rules.isBoolType(t) ||
      rules.isNumType(t);

  bool binaryOperationIsPrimitive(DartType leftT, DartType rightT) =>
      typeIsPrimitiveInJS(leftT) && typeIsPrimitiveInJS(rightT);

  bool unaryOperationIsPrimitive(DartType t) => typeIsPrimitiveInJS(t);

  @override
  void visitBinaryExpression(BinaryExpression node) {
    var op = node.operator;
    var lhs = node.leftOperand;
    var rhs = node.rightOperand;

    var dispatchType = rules.getStaticType(lhs);
    var otherType = rules.getStaticType(rhs);

    if (op.type.isEqualityOperator) {
      // If we statically know LHS or RHS is null we can generate a clean check.
      // We can also do this if the left hand side is a primitive type, because
      // we know then it doesn't have an overridden.
      if (_isNull(lhs) || _isNull(rhs) || typeIsPrimitiveInJS(dispatchType)) {
        lhs.accept(this);
        // https://people.mozilla.org/~jorendorff/es6-draft.html#sec-strict-equality-comparison
        out.write(op.type == TokenType.EQ_EQ ? ' === ' : ' !== ');
        rhs.accept(this);
      } else {
        // TODO(jmesserly): it would be nice to use just "equals", perhaps
        // by importing this name.
        if (op.type == TokenType.BANG_EQ) out.write('!');
        out.write('dart.equals(');
        lhs.accept(this);
        out.write(', ');
        rhs.accept(this);
        out.write(')');
      }
    } else if (binaryOperationIsPrimitive(dispatchType, otherType)) {
      if (op.type == TokenType.TILDE_SLASH) {
        // `a ~/ b` is equivalent to `(a / b).truncate()`
        out.write('(');
        lhs.accept(this);
        out.write(' / ');
        rhs.accept(this);
        out.write(').truncate()');
      } else {
        // TODO(vsm): When do Dart ops not map to JS?
        lhs.accept(this);
        out.write(' $op ');
        rhs.accept(this);
      }
    } else {
      // TODO(vsm): Figure out operator calling convention / dispatch.
      out.write('/* Unimplemented binary operator: $node */');
    }
  }

  bool _isNull(Expression expr) => expr is NullLiteral;

  @override
  void visitPostfixExpression(PostfixExpression node) {
    var op = node.operator;
    var expr = node.operand;

    var dispatchType = rules.getStaticType(expr);
    if (unaryOperationIsPrimitive(dispatchType)) {
      // TODO(vsm): When do Dart ops not map to JS?
      expr.accept(this);
      out.write('$op');
    } else {
      // TODO(vsm): Figure out operator calling convention / dispatch.
      out.write('/* Unimplemented postfix operator: $node */');
    }
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    var op = node.operator;
    var expr = node.operand;

    var dispatchType = rules.getStaticType(expr);
    if (unaryOperationIsPrimitive(dispatchType)) {
      // TODO(vsm): When do Dart ops not map to JS?
      out.write('$op');
      expr.accept(this);
    } else {
      // TODO(vsm): Figure out operator calling convention / dispatch.
      out.write('/* Unimplemented postfix operator: $node */');
    }
  }

  // Cascades can contain [IndexExpression], [MethodInvocation] and
  // [PropertyAccess]. The code generation for those is handled in their
  // respective visit methods.
  @override
  void visitCascadeExpression(CascadeExpression node) {
    // TODO(jmesserly): we need to handle the cascade target better. Ideally
    // it should be assigned to a temp. Note that even simple identifier isn't
    // safe in the face of getters.
    if (node.target is! SimpleIdentifier) {
      out.write('/* Unimplemented cascade on non-simple identifier: $node */');
      return;
    }

    var savedCascadeTemp = _cascadeTarget;
    _cascadeTarget = node.target;
    out.write('(', 2);
    _visitNodeList(node.cascadeSections, separator: ',\n');
    if (node.parent is! ExpressionStatement) {
      if (node.cascadeSections.isNotEmpty) out.write(',\n');
      _cascadeTarget.accept(this);
    }
    out.write(')', -2);
    _cascadeTarget = savedCascadeTemp;
  }

  @override
  void visitParenthesizedExpression(ParenthesizedExpression node) {
    out.write('(');
    node.expression.accept(this);
    out.write(')');
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    node.identifier.accept(this);
  }

  @override
  void visitThisExpression(ThisExpression node) {
    out.write('this');
  }

  @override
  void visitSuperExpression(SuperExpression node) {
    out.write('super');
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.staticElement is PrefixElement) {
      node.identifier.accept(this);
    } else {
      _visitGet(node.prefix, node.identifier);
    }
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    var target = node.isCascaded ? _cascadeTarget : node.target;
    _visitGet(target, node.propertyName);
  }

  /// Shared code for [PrefixedIdentifier] and [PropertyAccess].
  void _visitGet(Expression target, SimpleIdentifier name) {
    if (rules.isDynamicGet(target)) {
      // TODO(jmesserly): this won't work if we're left hand side of assignment.
      out.write('dart.dload(');
      target.accept(this);
      out.write(', "${name.name}")');
    } else {
      target.accept(this);
      out.write('.${name.name}');
    }
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    var target = node.isCascaded ? _cascadeTarget : node.target;
    if (rules.isDynamicGet(target)) {
      out.write('/* Unimplemented dynamic IndexExpression: $node */');
    } else {
      target.accept(this);
      out.write('[');
      node.index.accept(this);
      out.write(']');
    }
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    node.condition.accept(this);
    out.write(' ? ');
    node.thenExpression.accept(this);
    out.write(' : ');
    node.elseExpression.accept(this);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    if (node.parent is ExpressionStatement) {
      out.write('throw ');
      node.expression.accept(this);
    } else {
      // TODO(jmesserly): move this into runtime helper?
      out.write('(function(e) { throw e }(');
      node.expression.accept(this);
      out.write(')');
    }
  }

  @override
  void visitIfStatement(IfStatement node) {
    out.write('if (');
    node.condition.accept(this);
    out.write(') ');
    node.thenStatement.accept(this);
    var elseClause = node.elseStatement;
    if (elseClause != null) {
      out.write(' else ');
      elseClause.accept(this);
    }
  }

  @override
  void visitForStatement(ForStatement node) {
    Expression initialization = node.initialization;
    out.write("for (");
    if (initialization != null) {
      initialization.accept(this);
    } else if (node.variables != null) {
      _visitNode(node.variables);
    }
    out.write(";");
    _visitNode(node.condition, prefix: " ");
    out.write(";");
    _visitNodeList(node.updaters, prefix: " ", separator: ", ");
    out.write(") ");
    _visitNode(node.body);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    out.write("while (");
    _visitNode(node.condition);
    out.write(") ");
    _visitNode(node.body);
  }

  @override
  void visitDoStatement(DoStatement node) {
    out.write("do ");
    _visitNode(node.body);
    if (node.body is! Block) out.write(' ');
    out.write("while (");
    _visitNode(node.condition);
    out.write(");\n");
  }

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    out.write('${node.value}');
  }

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    out.write('${node.value}');
  }

  @override
  void visitNullLiteral(NullLiteral node) {
    out.write('null');
  }

  @override
  void visitListLiteral(ListLiteral node) {
    if (node.constKeyword != null) {
      out.write('/* Unimplemented const */');
    }
    // TODO(jmesserly): ES Array does not have Dart's ArrayList methods.
    out.write('/* Unimplemented ArrayList */[');
    _visitNodeList(node.elements, separator: ', ');
    out.write(']');
  }

  @override
  void visitMapLiteral(MapLiteral node) {
    out.write('dart.map(');
    var entries = node.entries;
    if (entries != null && entries.isNotEmpty) {
      // Use JS object literal notation if possible, otherwise use an array.
      if (entries.every((e) => e.key is SimpleStringLiteral)) {
        out.write('{\n', 2);
        _visitMapLiteralEntries(entries, separator: ': ');
        out.write('\n}', -2);
      } else {
        out.write('[\n', 2);
        _visitMapLiteralEntries(entries, separator: ', ');
        out.write('\n]', -2);
      }
    }
    out.write(')');
  }

  void _visitMapLiteralEntries(NodeList<MapLiteralEntry> nodes,
      {String separator}) {
    if (nodes == null) return;
    int size = nodes.length;
    if (size == 0) return;

    for (int i = 0; i < size; i++) {
      if (i > 0) out.write(',\n');
      var node = nodes[i];
      node.key.accept(this);
      out.write(separator);
      node.value.accept(this);
    }
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    // TODO(jmesserly): does this work for other quote styles?
    out.write('"${node.stringValue}"');
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    _visitNodeList(node.strings, separator: ' + ');
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    _visitNodeList(node.elements, separator: ' + ');
  }

  @override
  void visitInterpolationString(InterpolationString node) {
    out.write('"${node.value}"');
  }

  @override
  void visitInterpolationExpression(InterpolationExpression node) {
    // TODO(jmesserly): skip parens if not needed.
    // TODO(jmesserly): we could also use ES6 template strings here:
    // https://github.com/lukehoban/es6features#template-strings
    out.write('(');
    node.expression.accept(this);
    // Assuming we implement toString() on our objects, we can avoid calling it
    // in most cases. Builtin types may differ though.
    // For example, Dart's concrete List type does not have the same toString
    // as Array.prototype.toString().
    // https://people.mozilla.org/~jorendorff/es6-draft.html#sec-addition-operator-plus-runtime-semantics-evaluation
    out.write(')');
  }

  @override
  void visitBooleanLiteral(BooleanLiteral node) {
    out.write('${node.value}');
  }

  @override
  void visitDirective(Directive node) {}

  @override
  void visitNode(AstNode node) {
    out.write('/* Unimplemented ${node.runtimeType}: $node */');
  }

  // TODO(jmesserly): this is used to determine if the field initialization is
  // side effect free. We should make the check more general, as things like
  // list/map literals/regexp are also side effect free and fairly common
  // to use as field initializers.
  bool _isFieldInitConstant(VariableDeclaration field) =>
      field.initializer == null || _computeConstant(field) is ValidResult;

  EvaluationResultImpl _computeConstant(VariableDeclaration field) {
    // If the constant is already computed by ConstantEvaluator, just return it.
    VariableElementImpl element = field.element;
    var result = element.evaluationResult;
    if (result != null) return result;

    // ConstantEvaluator will not compute constants for non-const fields
    // at least for cases like `int x = 0;`, so run ConstantVisitor for those.
    // TODO(jmesserly): ideally we'd only do this if we're sure it was skipped
    // by ConstantEvaluator.
    var initializer = field.initializer;
    if (initializer == null) return null;

    return initializer.accept(_constVisitor);
  }

  static const Map<String, String> _builtins = const <String, String>{
    'dart.core': 'dart_core',
    'dart.math': 'dart_math',
  };

  String getLibraryId(LibraryElement element) {
    var libraryName = element.name;
    var builtinName = _builtins[libraryName];
    if (builtinName != null) return builtinName;

    return _jsLibraryName(element);
  }

  /// Returns true if [element] is a getter in JS, therefore needs
  /// `lib.topLevel` syntax instead of just `topLevel`.
  bool _needsModuleGetter(Element element) {
    if (element is PropertyAccessorElement) {
      element = (element as PropertyAccessorElement).variable;
    }
    return element is TopLevelVariableElement && !element.isConst;
  }

  /// Safely visit the given node, with an optional prefix or suffix.
  void _visitNode(AstNode node, {String prefix: '', String suffix: ''}) {
    if (node == null) return;

    out.write(prefix);
    node.accept(this);
    out.write(suffix);
  }

  /// Print a list of nodes, with an optional prefix, suffix, and separator.
  void _visitNodeList(List<AstNode> nodes,
      {String prefix: '', String suffix: '', String separator: ''}) {
    if (nodes == null) return;

    int size = nodes.length;
    if (size == 0) return;

    out.write(prefix);
    for (int i = 0; i < size; i++) {
      if (i > 0) out.write(separator);
      nodes[i].accept(this);
    }
    out.write(suffix);
  }

  /// Safely visit the given node, printing the suffix after the node if it is
  /// non-`null`.
  void visitToken(Token token, {String prefix: '', String suffix: ''}) {
    if (token == null) return;
    out.write(prefix);
    out.write(token.lexeme);
    out.write(suffix);
  }
}

class JSGenerator extends CodeGenerator {
  JSGenerator(String outDir, Uri root, TypeRules rules)
      : super(outDir, root, rules);

  void generateLibrary(Iterable<CompilationUnit> units, LibraryInfo info,
      CheckerReporter reporter) {
    // TODO(jmesserly): library directory should be relative to its package
    // root. For example, "package:ddc/src/codegen/js_codegen.dart" would be:
    // "ddc/src/codegen/js_codegen.js" under the output directory.
    var libraryName = _jsLibraryName(info.library);
    var libraryDir = path.join(outDir, libraryName);
    new Directory(libraryDir).createSync(recursive: true);
    String outputPath = path.join(libraryDir, '$libraryName.js');

    var out = new OutWriter(outputPath);

    new JSCodegenVisitor(info, rules, out).generateLibrary(units, reporter);

    out.close();
  }
}

/// Choose a canonical name from the library element
/// This never uses the library's name (the identifier in the `library`
/// declaration) as it doesn't have any meaningful rules enforced.
// TODO(jmesserly): library directory should be relative to its package
// root. For example, "package:ddc/src/codegen/js_codegen.dart" would be:
// "ddc/src/codegen/js_codegen.js" under the output directory.
String _jsLibraryName(LibraryElement library) {
  var uri = library.source.uri;
  return path.basenameWithoutExtension(uri.pathSegments.last);
}
