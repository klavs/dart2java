package generics;

public class Foo1__boolean extends dart._runtime.base.DartObject implements generics.Foo1_interface__boolean
{
    private static dart._runtime.types.simple.TypeExpr dart2java$typeExpr_Foo1$T = generics.Foo1.dart2java$typeInfo.typeVariables[0];
    public boolean variable;
    public generics.Foo1_interface__boolean anotherFoo1;
  
    public Foo1__boolean(dart._runtime.helpers.ConstructorHelper.EmptyConstructorMarker arg, dart._runtime.types.simple.Type type)
    {
      super(arg, type);
    }
  
    public void createInnerFoo_Foo1__boolean()
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      this.setAnotherFoo1_Foo1__boolean(((generics.Foo1_interface__boolean) ((generics.Foo1_interface__boolean) generics.Foo1.<java.lang.Boolean>factory$(dart2java$localTypeEnv.extend(generics.Foo1.factory$$typeInfo.typeVariables, new dart._runtime.types.simple.Type[] {dart2java$localTypeEnv.evaluate(dart2java$typeExpr_Foo1$T)})))));
    }
    public boolean foo_Foo1__boolean(boolean t)
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      return t;
    }
    public void writeVariable_Foo1__boolean(boolean value)
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      this.setVariable_Foo1__boolean(value);
    }
    public void _constructornewMe()
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      super._constructor();
    }
    public boolean getVariable_Foo1__boolean()
    {
      return this.variable;
    }
    public generics.Foo1_interface__boolean getAnotherFoo1_Foo1__boolean()
    {
      return this.anotherFoo1;
    }
    public boolean setVariable_Foo1__boolean(boolean value)
    {
      this.variable = value;
      return value;
    }
    public generics.Foo1_interface__boolean setAnotherFoo1_Foo1__boolean(generics.Foo1_interface__boolean value)
    {
      this.anotherFoo1 = value;
      return value;
    }
    public java.lang.Boolean getVariable()
    {
      return this.getVariable_Foo1__boolean();
    }
    public generics.Foo1_interface__boolean getAnotherFoo1()
    {
      return this.getAnotherFoo1_Foo1__boolean();
    }
    public java.lang.Boolean setVariable(java.lang.Boolean value)
    {
      return this.setVariable_Foo1__boolean(((boolean) value));
    }
    public generics.Foo1_interface__boolean setAnotherFoo1(generics.Foo1_interface__boolean value)
    {
      return this.setAnotherFoo1_Foo1__boolean(((generics.Foo1_interface__boolean) value));
    }
    public void createInnerFoo()
    {
      this.createInnerFoo_Foo1__boolean();
    }
    public java.lang.Boolean foo(java.lang.Boolean t)
    {
      return this.foo_Foo1__boolean(((boolean) t));
    }
    public void writeVariable(java.lang.Boolean value)
    {
      this.writeVariable_Foo1__boolean(((boolean) value));
    }
}
