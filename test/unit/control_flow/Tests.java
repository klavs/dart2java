// Copyright 2016, the Dart project authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.assertFalse;

import org.junit.Test;
import scenario.__TopLevel;

public class Tests {

  @Test
  public void testIfStatement() {
    assertTrue(__TopLevel.isLessIfThen(1, 2));
    assertFalse(__TopLevel.isLessIfThen(2, 1));
    assertTrue(__TopLevel.isLessIfThenElse(1, 2));
    assertFalse(__TopLevel.isLessIfThenElse(2, 1));
  }

  @Test
  public void testTernary() {
    assertTrue(__TopLevel.isLessTernary(1, 2));
    assertFalse(__TopLevel.isLessTernary(2, 1));
  }

  @Test
  public void testLoops() {
    assertEquals(10, (int) __TopLevel.countWhile());
    assertEquals(10, (int) __TopLevel.countDo());
    assertEquals(10, (int) __TopLevel.countFor());
    assertEquals(90, (int) __TopLevel.countForMultiUpdate());
  }
}