Module: logging-test-suite
Copyright: Copyright (c) 2013 Dylan Hackers. See License.txt for details.

define test test-<abstract-log> ()
end test;

define test test-<debug-level> ()
end test;

define test test-<error-level> ()
end test;

define test test-<info-level> ()
end test;

define test test-<trace-level> ()
end test;

define test test-<warn-level> ()
end test;

define test test-<log-formatter> ()
end test;

define test test-<log-level> ()
end test;

define test test-<placeholder-log> ()
end test;

define test test-<log> ()
  check-no-errors("make a log with a <string> formatter",
                  make(<log>,
                       name: "<log>-test",
                       formatter: "foo"));
end test;

define test test-<logging-error> ()
end test;

define test test-<log-target> ()
end test;

define test test-<null-log-target> ()
end test;

define test test-<stream-log-target> ()
end test;

define test test-$stderr-log-target ()
end test;

define test test-$stdout-log-target ()
end test;

define test test-<file-log-target> ()
  let locator = temp-locator("file-log-target-test.log");
  let target = make(<file-log-target>, pathname: locator);
  dynamic-bind (*log* = make(<log>,
                             name: "file-log-target-test",
                             targets: list(target),
                             formatter: $message-only-formatter))
    log-info("test");
  end;
  close(target);
  with-open-file (stream = locator, direction: #"input")
    check-equal("file-log-target has expected contents",
                read-to-end(stream), "test\n");
  end;
end test;

define test test-<rolling-file-log-target> ()
  // Make sure the file rolls when it reaches max size
  let locator = temp-locator("rolling-log-file.log");
  if (file-exists?(locator))
    delete-file(locator)
  end;
  let target = make(<rolling-file-log-target>,
                    pathname: locator,
                    max-size: 10);
  dynamic-bind (*log* = make(<log>,
                             name: "rolling-file-test",
                             targets: list(target),
                             formatter: $message-only-formatter))
    // I figure this could log 8 or 9 characters, including CR and/or LF.
    log-info("1234567");
    close(target);  // can't read file on Windows unless it's closed
    assert-equal("1234567\n", file-contents(locator),
                 "log doesn't roll when below max size");
    open-target-stream(target);
    log-info("890");
    close(target);  // can't read file on Windows unless it's closed
    assert-equal("", file-contents(locator),
                 "log rolls when max size exceeded");
  end;
end test;

define test test-$debug-level ()
end test;

define test test-$error-level ()
end test;

define test test-$info-level ()
end test;

define test test-$trace-level ()
end test;

define test test-$warn-level ()
end test;

define test test-log-debug ()
    do-test-log-level($debug-level);
end test;

define test test-log-error ()
    do-test-log-level($error-level);
end test;

define test test-log-info ()
    do-test-log-level($info-level);
end test;

define test test-log-trace ()
    do-test-log-level($trace-level);
end test;

define test test-log-warning ()
    do-test-log-level($warn-level);
end test;

define test test-add-target ()
end test;

define test test-get-log ()
end test;

define test test-get-root-log ()
end test;

define test test-level-name ()
end test;

define test test-log-debug-if ()
end test;

define test test-log-level ()
end test;

define test test-log-level-setter ()
end test;

define test test-log-message ()
end test;

define test test-log-to-target ()
end test;

define test test-log-additive? ()
  // Make sure non-additive log DOESN'T pass it on to parent.
  let log1 = make-test-log("aaa");
  let log2 = make-test-log("aaa.bbb", additive?: #f);
  dynamic-bind (*log* = log2)
    log-error("xxx");
  end;
  assert-equal("", stream-contents(log1.log-targets[0].target-stream),
               "non-additivity respected for target1");
  assert-equal("xxx\n", stream-contents(log2.log-targets[0].target-stream),
               "non-additivity respected for target2");

  // Make sure additive log DOES pass it on to parent.
  let log1 = make-test-log("xxx");
  let log2 = make-test-log("xxx.yyy", additive?: #t);
  dynamic-bind (*log* = log2)
    log-error("xxx");
  end;
  assert-equal("xxx\n", stream-contents(log1.log-targets[0].target-stream),
               "additivity respected for target1");
  assert-equal("xxx\n", stream-contents(log2.log-targets[0].target-stream),
               "additivity respected for target2");
end test;

define test test-log-additive?-setter ()
end test;

define test test-log-enabled? ()
end test;

define test test-log-enabled?-setter ()
  // Make sure disabled log doesn't do output
  let log = make-test-log("log-enabled-test");
  log-enabled?(log) := #f;
  dynamic-bind (*log* = log)
    log-info(log, "xxx");
  end;
  assert-equal("", stream-contents(log.log-targets[0].target-stream),
               "disabled log does no output");

  // Make sure disabled log still respects additivity.
  let parent = make-test-log("parent");
  let child = make-test-log("parent.child");
  log-enabled?(child) := #f;
  dynamic-bind (*log* = child) log-info("xxx"); end;
  assert-equal("xxx\n", stream-contents(parent.log-targets[0].target-stream),
               "additivity respected for disabled log");
end test;

define test test-log-name ()
end test;

define test test-pattern-to-stream ()
end test;

define test test-remove-target ()
end test;

define test test-write-message ()
end test;

define interface-specification-suite logging-specification-suite ()
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
  instantiable class <trace-level> (<log-level>);
  instantiable class <debug-level> (<trace-level>);
  instantiable class <info-level> (<debug-level>);
  instantiable class <warn-level> (<info-level>);
  instantiable class <error-level> (<warn-level>);

  constant $trace-level :: <object>;
  constant $debug-level :: <object>;
  constant $info-level :: <object>;
  constant $warn-level :: <object>;
  constant $error-level :: <object>;

  variable *log* :: <log>;
  function log-trace (<object>, #"rest") => ();
  function log-debug (<object>, #"rest") => ();
  function log-debug-if (<object>, <object>, #"rest") => ();
  function log-info (<object>, #"rest") => ();
  function log-warning (<object>, #"rest") => ();
  function log-error (<object>, #"rest") => ();

  constant $stderr-log-target :: <object>;
  constant $stdout-log-target :: <object>;

  function add-target (<log>, <log-target>) => ();
  function get-log (<string>) => (false-or(<abstract-log>));
  function get-root-log () => (<log>);
  function level-name (<log-level>) => (<string>);
  function log-level-setter (<log-level>, <log>) => (<log-level>);
  function log-level (<log>) => (<log-level>);
  function log-message (<log-level>, <abstract-log>, <object>) => ();
  function log-to-target (<log-target>, <log-level>, <log-formatter>, <object>, <sequence>) => ();
  function log-additive?-setter (<boolean>, <abstract-log>) => (<boolean>);
  function log-additive? (<abstract-log>) => (<boolean>);
  function log-enabled?-setter (<boolean>, <abstract-log>) => (<boolean>);
  function log-enabled? (<abstract-log>) => (<boolean>);
  function log-name (<abstract-log>) => (<string>);
  function pattern-to-stream (<log-formatter>, <stream>, <log-level>, <log-target>, <object>, <sequence>) => ();
  function remove-target (<log>, <log-target>) => ();
  function write-message (<log-target>, <object>, <sequence>) => ();
end logging-specification-suite;

ignore(logging-specification-suite);
