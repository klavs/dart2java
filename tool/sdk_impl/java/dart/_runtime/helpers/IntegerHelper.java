package dart._runtime.helpers;

import dart._runtime.types.simple.InterfaceTypeExpr;
import dart._runtime.types.simple.InterfaceTypeInfo;

public class IntegerHelper {
  public static final InterfaceTypeInfo dart2java$typeInfo
      = new InterfaceTypeInfo(int.class, null);

  static {
    IntegerHelper.dart2java$typeInfo.superclass = new InterfaceTypeExpr(NumberHelper.dart2java$typeInfo);
  }

  // --- Methods defined in Object ---

  // TODO(springerm): noSuchMethod
  // TODO(springerm): runtimeType


  // --- Methods defined in Comparable ---


  // --- Methods defined in num ---
  
  public static boolean operatorEqual(Integer self, Object other) {
    return self.equals(other);
  }

  public static int getHashCode(int self) {
    return self;
  }

  public static int compareTo(int self, int other) {
    if (self < other) {
      return -1;
    } else if (self > other) {
      return 1;
    } else {
      return 0;
    }
  }

  public static int compareTo(int self, double other) {
    if (self < other) {
      return -1;
    } else if (self > other) {
      return 1;
    } else {
      return 0;
    }
  }

  public static int compareTo(int self, Number other) {
    if (other instanceof Integer) {
      return compareTo(self, (int) other);
    } else {
      // Must be double
      return compareTo(self, (double) other);
    }
  }


  public static int operatorPlus(int self, int other) {
    return self + other;
  }

  public static double operatorPlus(int self, double other) {
    return self + other;
  }

  public static Number operatorPlus(int self, Number other) {
    if (other instanceof Integer) {
      return operatorPlus(self, (int) other);
    } else {
      // Must be double
      return operatorPlus(self, (double) other);
    }
  }

  public static int operatorMinus(int self, int other) {
    return self - other;
  }

  public static double operatorMinus(int self, double other) {
    return self - other;
  }

  public static Number operatorMinus(int self, Number other) {
    if (other instanceof Integer) {
      return operatorMinus(self, (int) other);
    } else {
      // Must be double
      return operatorMinus(self, (double) other);
    }
  }

  public static int operatorStar(int self, int other) {
    return self * other;
  }

  public static double operatorStar(int self, double other) {
    return self * other;
  }

  public static Number operatorStar(int self, Number other) {
    if (other instanceof Integer) {
      return operatorStar(self, (int) other);
    } else {
      // Must be double
      return operatorStar(self, (double) other);
    }
  }

  public static int operatorModulus(int self, int other) {
    return self % other;
  }

  // TODO(springerm): operatorModulus for Double
  // TODO(springerm): operatorModulus for Number

  public static double operatorDivide(int self, int other) {
    return ((double) self) / other;
  } 

  public static double operatorDivide(int self, double other) {
    return ((double) self) / other;
  } 

  public static double operatorDivide(int self, Number other) {
    if (other instanceof Integer) {
      return operatorDivide(self, (int) other);
    } else {
      // Must be double
      return operatorDivide(self, (double) other);
    }
  }

  public static int operatorTruncatedDivide(int self, int other) {
    return (int) (self / other);
  }

  public static int operatorTruncatedDivide(int self, double other) {
    return (int) (self / other);
  }

  public static int operatorTruncatedDivide(int self, Number other) {
    if (other instanceof Integer) {
      return operatorTruncatedDivide(self, (int) other);
    } else {
      // Must be double
      return operatorTruncatedDivide(self, (double) other);
    }
  }

  public static int operatorUnaryMinus(int self) {
    return -self;
  }

  // TODO(springerm): remainder

  public static boolean operatorLess(int self, int other) {
    return self < other;
  }

  public static boolean operatorLess(int self, double other) {
    return self < other;
  }

  public static boolean operatorLess(int self, Number other) {
    if (other instanceof Integer) {
      return operatorLess(self, (int) other);
    } else {
      // Must be double
      return operatorLess(self, (double) other);
    }
  }

  public static boolean operatorLessEqual(int self, int other) {
    return self <= other;
  }

  public static boolean operatorLessEqual(int self, double other) {
    return self <= other;
  }

  public static boolean operatorLessEqual(int self, Number other) {
    if (other instanceof Integer) {
      return operatorLessEqual(self, (int) other);
    } else {
      // Must be double
      return operatorLessEqual(self, (double) other);
    }
  }

  public static boolean operatorGreater(int self, int other) {
    return self > other;
  }

  public static boolean operatorGreater(int self, double other) {
    return self > other;
  }

  public static boolean operatorGreater(int self, Number other) {
    if (other instanceof Integer) {
      return operatorGreater(self, (int) other);
    } else {
      // Must be double
      return operatorGreater(self, (double) other);
    }
  }

  public static boolean operatorGreaterEqual(int self, int other) {
    return self >= other;
  }

  public static boolean operatorGreaterEqual(int self, double other) {
    return self >= other;
  }

  public static boolean operatorGreaterEqual(int self, Number other) {
    if (other instanceof Integer) {
      return operatorGreaterEqual(self, (int) other);
    } else {
      // Must be double
      return operatorGreaterEqual(self, (double) other);
    }
  }
  
  public static boolean isNaN(int self) {
    return false;
  }

  public static boolean isNegative(int self) {
    return self < 0;
  }

  public static boolean isInfinite(int self) {
    return false;
  }

  public static boolean isFinite(int self) {
    return true;
  }

  public static int abs(int self) {
    return Integer.signum(self) * self;
  }

  public static int getSign(int self) {
    return Integer.signum(self);
  }

  public static int round(int self) {
    return self;
  }

  public static int floor(int self) {
    return self;
  }

  public static int ceil(int self) {
    return self;
  }

  public static int truncate(int self) {
    return self;
  }

  // TODO(springerm): roundToDouble
  // TODO(springerm): floorToDouble
  // TODO(springerm:) ceilToDouble
  // TODO(springerm): truncateToDouble
  // TODO(springerm): clamp

  public static int toInt(int self) {
    return self;
  }

  public static double toDouble(int self) {
    return (double) self;
  }

  // TODO(springerm): toStringAsFixed
  // TODO(springerm): toStringAsExponential
  // TODO(springerm): toStringAsPrecision

  public static String toString(Integer self) {
    return self.toString();
  }


  // -- Methods defined in int --

  public static int operatorBitAnd(int self, int other) {
    return self & other;
  }

  public static int operatorBitOr(int self, int other) {
    return self | other;
  }

  public static int operatorBitXor(int self, int other) {
    return self ^ other;
  }

  public static int operatorUnaryBitNegate(int self) {
    return ~self;
  }

  public static int operatorShiftLeft(int self, int other) {
    return self << other;
  }

  public static int operatorShiftRight(int self, int other) {
    return self >> other;
  }

  // TODO(springerm): modPow
  // TODO(springerm): modInverse
  // TODO(springerm): gcd

  public static boolean isEven(int self) {
    return self % 2 == 0;
  }

  public static boolean isOdd(int self) {
    return self % 2 == 1;
  }

  // TODO(springerm): bitLength
  // TODO(springerm): toUnsigned
  // TODO(springerm): toSigned
  // TODO(springerm): toRadixString

  public static class Static {
    // TODO(springerm): parse
    // TODO(springerm): fromEnvironment
  }


  // --- Other methods ---

  public static boolean operatorNotEqual(int self, int other) {
    return self != other;
  }

}
