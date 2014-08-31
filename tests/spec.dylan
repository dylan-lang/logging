Module: logging-test-suite
Author: Carl L Gay
Copyright: Copyright (c) 2013 Dylan Hackers. See License.txt for details.

// Defines suite logging-module-test-suite.
//
define module-spec logging
    (setup-function: curry(ensure-directories-exist, $temp-directory))
  open abstract class <abstract-log> (<object>);
  sealed /* instantiable */ class <file-log-target> (<log-target>);
  open /* instantiable */ class <log-formatter> (<object>);
  open /* instantiable */ class <log-target> (<closable-object>);
  open /* instantiable */ class <log> (<abstract-log>);
  instantiable class <logging-error> (<error>, <simple-condition>);
  instantiable class <null-log-target> (<log-target>);
  sealed class <placeholder-log> (<abstract-log>);
  sealed class <rolling-file-log-target> (<file-log-target>);
  class <stream-log-target> (<log-target>);

  class <log-level> (<object>);
  instantiable class <debug-level> (<trace-level>);
  instantiable class <error-level> (<warn-level>);
  instantiable class <info-level> (<debug-level>);
  instantiable class <trace-level> (<log-level>);
  instantiable class <warn-level> (<info-level>);

  constant $debug-level :: <object>;
  constant $error-level :: <object>;
  constant $info-level :: <object>;
  constant $trace-level :: <object>;
  constant $warn-level :: <object>;

  constant log-debug :: <object>;
  constant log-error :: <object>;
  constant log-info :: <object>;
  constant log-trace :: <object>;
  constant log-warning :: <object>;

  constant $stderr-log-target :: <object>;
  constant $stdout-log-target :: <object>;

  function add-target (<log>, <log-target>) => ();
  function get-log (<string>) => (false-or(<abstract-log>));
  function get-root-log () => (<log>);
  function level-name (<log-level>) => (<string>);
  function log-debug-if (<object>, <abstract-log>, <string>) => ();
  function log-level-setter (<log-level>, <log>) => (<log-level>);
  function log-level (<log>) => (<log-level>);
  function log-message (<log-level>, <log>, <object>) => ();
  function log-to-target (<log-target>, <log-level>, <log-formatter>, <object>, <sequence>) => ();
  function log-additive?-setter (<boolean>, <abstract-log>) => (<boolean>);
  function log-additive? (<abstract-log>) => (<boolean>);
  function log-enabled?-setter (<boolean>, <abstract-log>) => (<boolean>);
  function log-enabled? (<abstract-log>) => (<boolean>);
  function log-name (<abstract-log>) => (<string>);
  function pattern-to-stream (<log-formatter>, <stream>, <log-level>, <log-target>, <object>, <sequence>) => ();
  function remove-target (<log>, <log-target>) => ();
  function write-message (<log-target>, <object>, <sequence>) => ();
end module-spec logging;

define logging class-test <abstract-log> ()
end class-test <abstract-log>;

define logging class-test <debug-level> ()
end class-test <debug-level>;

define logging class-test <error-level> ()
end class-test <error-level>;

define logging class-test <info-level> ()
end class-test <info-level>;

define logging class-test <trace-level> ()
end class-test <trace-level>;

define logging class-test <warn-level> ()
end class-test <warn-level>;

define logging class-test <log-formatter> ()
end class-test <log-formatter>;

define logging class-test <log-level> ()
end class-test <log-level>;

define logging class-test <placeholder-log> ()
end class-test <placeholder-log>;

define logging class-test <log> ()
  check-no-errors("make a log with a <string> formatter",
                  make(<log>,
                       name: "<log>-test",
                       formatter: "foo"));
end class-test <log>;

define logging class-test <logging-error> ()
end class-test <logging-error>;

define logging class-test <log-target> ()
end class-test <log-target>;

define logging class-test <null-log-target> ()
end class-test <null-log-target>;

define logging class-test <stream-log-target> ()
end class-test <stream-log-target>;

define logging constant-test $stderr-log-target ()
end constant-test $stderr-log-target;

define logging constant-test $stdout-log-target ()
end constant-test $stdout-log-target;

define logging class-test <file-log-target> ()
  let locator = temp-locator("file-log-target-test.log");
  let target = make(<file-log-target>, pathname: locator);
  let log = make(<log>,
                 name: "file-log-target-test",
                 targets: list(target),
                 formatter: $message-only-formatter);
  log-info(log, "test");
  close(target);
  with-open-file (stream = locator, direction: #"input")
    check-equal("file-log-target has expected contents",
                read-to-end(stream), "test\n");
  end;
end class-test <file-log-target>;

define logging class-test <rolling-file-log-target> ()
  // Make sure the file rolls when it reaches max size
  let locator = temp-locator("rolling-log-file.log");
  if (file-exists?(locator))
    delete-file(locator)
  end;
  let target = make(<rolling-file-log-target>,
                    pathname: locator,
                    max-size: 10);
  let log = make(<log>,
                 name: "rolling-file-test",
                 targets: list(target),
                 formatter: $message-only-formatter);
  // I figure this could log 8 or 9 characters, including CR and/or LF.
  log-info(log, "1234567");
  close(target);  // can't read file on Windows unless it's closed
  check-equal("log doesn't roll when below max size",
              file-contents(locator),
              "1234567\n");
  open-target-stream(target);
  log-info(log, "890");
  close(target);  // can't read file on Windows unless it's closed
  check-equal("log rolls when max size exceeded",
              file-contents(locator),
              "");
end class-test <rolling-file-log-target>;

define logging constant-test $debug-level ()
end constant-test $debug-level;

define logging constant-test $error-level ()
end constant-test $error-level;

define logging constant-test $info-level ()
end constant-test $info-level;

define logging constant-test $trace-level ()
end constant-test $trace-level;

define logging constant-test $warn-level ()
end constant-test $warn-level;

define logging constant-test log-debug ()
    test-log-level($debug-level);
end constant-test log-debug;

define logging constant-test log-error ()
    test-log-level($error-level);
end constant-test log-error;

define logging constant-test log-info ()
    test-log-level($info-level);
end constant-test log-info;

define logging constant-test log-trace ()
    test-log-level($trace-level);
end constant-test log-trace;

define logging constant-test log-warning ()
    test-log-level($warn-level);
end constant-test log-warning;

define logging function-test add-target ()
end function-test add-target;

define logging function-test current-log-args ()
end function-test current-log-args;

define logging function-test current-log-object ()
end function-test current-log-object;

define logging function-test get-log ()
end function-test get-log;

define logging function-test get-root-log ()
end function-test get-root-log;

define logging function-test level-name ()
end function-test level-name;

define logging function-test log-debug-if ()
end function-test log-debug-if;

define logging function-test log-level ()
end function-test log-level;

define logging function-test log-level-setter ()
end function-test log-level-setter;

define logging function-test log-message ()
end function-test log-message;

define logging function-test log-to-target ()
end function-test log-to-target;

define logging function-test log-additive? ()
  // Make sure non-additive log DOESN'T pass it on to parent.
  let log1 = make-test-log("aaa");
  let log2 = make-test-log("aaa.bbb", additive?: #f);
  log-error(log2, "xxx");
  check-equal("non-additivity respected for target1",
              stream-contents(log1.log-targets[0].target-stream),
              "");
  check-equal("non-additivity respected for target2",
              stream-contents(log2.log-targets[0].target-stream),
              "xxx\n");

  // Make sure additive log DOES pass it on to parent.
  let log1 = make-test-log("xxx");
  let log2 = make-test-log("xxx.yyy", additive?: #t);
  log-error(log2, "xxx");
  check-equal("additivity respected for target1",
              stream-contents(log1.log-targets[0].target-stream),
              "xxx\n");
  check-equal("additivity respected for target2",
              stream-contents(log2.log-targets[0].target-stream),
              "xxx\n");
end function-test log-additive?;

define logging function-test log-additive?-setter ()
end function-test log-additive?-setter;

define logging function-test log-enabled? ()
end function-test log-enabled?;

define logging function-test log-enabled?-setter ()
  // Make sure disabled log doesn't do output
  let log = make-test-log("log-enabled-test");
  log-enabled?(log) := #f;
  log-info(log, "xxx");
  check-equal("disabled log does no output",
              stream-contents(log.log-targets[0].target-stream),
              "");

  // Make sure disabled log still respects additivity.
  let parent = make-test-log("parent");
  let child = make-test-log("parent.child");
  log-enabled?(child) := #f;
  log-info(child, "xxx");
  check-equal("additivity respected for disabled log",
              stream-contents(parent.log-targets[0].target-stream),
              "xxx\n");
end function-test log-enabled?-setter;

define logging function-test log-name ()
end function-test log-name;

define logging function-test pattern-to-stream ()
end function-test pattern-to-stream;

define logging function-test remove-target ()
end function-test remove-target;

define logging function-test write-message ()
end function-test write-message;

// Defines constant logging-test-suite
//
define library-spec logging ()
  module logging;
  test test-elapsed-milliseconds;
  test test-process-id;
end library-spec logging;
