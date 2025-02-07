import { test } "mo:test";
import Debug "mo:base/Debug";

test(
  "Test 1",
  func() {
    Debug.print("Error message");
    assert (false);
  },
);
