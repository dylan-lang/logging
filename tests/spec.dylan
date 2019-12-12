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
end test;

define test test-log-additive?-setter ()
end test;

define test test-log-enabled? ()
end test;

define test test-log-enabled?-setter ()
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
end logging-specification-suite;

ignore(logging-specification-suite);
