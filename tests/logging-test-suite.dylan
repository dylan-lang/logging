Module: logging-test-suite
Author: Carl L Gay
Copyright: Copyright (c) 2013 Dylan Hackers.  See License.txt for details.

define constant fmt = format-to-string;

define function temp-locator
    (filename :: <string>) => (temp-locator :: <file-locator>)
  // locators are a freakin' nightmare...falling back to strings.
  as(<file-locator>,
     concatenate(as(<string>, test-temp-directory()), "/", filename))
end;

define function file-contents
    (pathname :: <pathname>)
 => (text :: <string>)
  with-open-file(stream = pathname)
    read-to-end(stream)
  end
end;

// This class serves two testing purposes: it's an easy way to get the
// results of logging to a stream and it tests the ability to create
// new types of log targets from outside the logging library.
//
define class <string-log-target> (<stream-log-target>)
end;

define method make
    (class == <string-log-target>, #rest args, #key stream)
 => (target)
  apply(next-method, class,
        stream: stream | make(<string-stream>, direction: #"output"),
        args)
end;

define constant $message-only-formatter
  = make(<log-formatter>, pattern: "%{message}");

// Make the most common type of log for testing.
//
define function make-test-log
    (name :: <string>, #rest init-args)
 => (log :: <log>)
  apply(make, <log>,
        name: name,
        targets: list(make(<string-log-target>)),
        formatter: $message-only-formatter,
        init-args)
end;

// given = error    pos = 4
// log = trace   idx = 0           expected = xxx\n
define function do-test-log-level
    (log-level :: <log-level>)
  reset-logging();
  let functions = list(log-trace, log-debug, log-info, log-warning, log-error);
  let levels = list($trace-level, $debug-level, $info-level, $warn-level, $error-level);
  let log-priority = position(levels, log-level);
  for (log-fn in functions,
       current-level in levels,
       current-priority from 0)
    let target = make(<string-log-target>);
    let log = make(<log>,
                   name: fmt("log.%d", current-priority),
                   targets: list(target),
                   level: log-level,
                   formatter: $message-only-formatter);
    dynamic-bind (*log* = log)
      log-fn("xxx");
    end;
    let expected = if (current-priority >= log-priority) "xxx\n" else "" end;
    let actual = stream-contents(target.target-stream);
    check-equal(fmt("Log output (%=) matches expected (%=). Given level %s, "
                    "log level %s", actual, expected, log-level, current-level),
                expected, actual);
  end;
end function;

define test test-format-elapsed-milliseconds ()
  let target = make(<string-log-target>);
  dynamic-bind (*log* = make(<log>,
                             name: "test-format-elapsed-milliseconds",
                             targets: list(target),
                             formatter: "%{millis}"))
    log-info("test");
  end;
  let millis-string = split(stream-contents(target.target-stream), " ")[0];
  // TODO: Need a fake clock to test this better.
  assert-no-errors(string-to-integer(millis-string));
end test;

define test test-format-process-id ()
  for (pattern in #("%{pid}", "%p"),
       i from 1)
    let target = make(<string-log-target>);
    dynamic-bind (*log* = make(<log>,
                               name: format-to-string("test-format-process-id-%s", i),
                               targets: list(target),
                               formatter: make(<log-formatter>, pattern: pattern),
                               level: $trace-level))
      log-info("this is ignored");
    end;
    check-equal("log stream contains process id only",
                stream-contents(target.target-stream),
                format-to-string("%d\n", current-process-id()));
  end;
end test;

define test test-format-severity ()
  let target = make(<string-log-target>);
  dynamic-bind (*log* = make(<log>,
                             name: "test-format-severity",
                             targets: list(target),
                             formatter: make(<log-formatter>, pattern: "%s %{severity}"),
                             level: $trace-level))
    log-trace("x");
    log-debug("x");
    log-info("x");
    log-warning("x");
    log-error("x");
  end;
  assert-equal("T TRACE\nD DEBUG\nI INFO\nW WARNING\nE ERROR\n",
               stream-contents(target.target-stream))
end test;

// Check that by default trace and debug logging is not output.
define test test-default-severity-level ()
  let log = make-test-log("test-default-log");
  dynamic-bind (*log* = log)
    log-trace("trace");
    log-debug("debug");
    log-info("info");
    log-warning("warning");
    log-error("error");
  end;
  assert-equal("info\nwarning\nerror\n",
               stream-contents(log.log-targets[0].target-stream));
end test;
