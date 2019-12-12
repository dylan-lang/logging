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

define constant $log-levels
  = list($trace-level, $debug-level, $info-level, $warn-level, $error-level);

define constant $log-functions
  = list(log-trace, log-debug, log-info, log-warning, log-error);

// given = error    pos = 4
// log = trace   idx = 0           expected = xxx\n
define function do-test-log-level
    (log-level :: <log-level>)
  reset-logging();
  let log-priority = position($log-levels, log-level);
  for (log-fn in $log-functions,
       current-level in $log-levels,
       current-priority from 0)
    let target = make(<string-log-target>);
    let log = make(<log>,
                   name: fmt("log.%d", current-priority),
                   targets: list(target),
                   level: log-level,
                   formatter: $message-only-formatter);
    log-fn(log, "xxx");
    let expected = if (current-priority >= log-priority) "xxx\n" else "" end;
    let actual = stream-contents(target.target-stream);
    check-equal(fmt("Log output (%=) matches expected (%=). Given level %s, "
                    "log level %s", actual, expected, log-level, current-level),
                expected, actual);
  end;
end function;

// elapsed-milliseconds uses double integers.  This test just tries to
// make sure that number-to-string (should be integer-to-string) doesn't
// blow up.
//
define test test-elapsed-milliseconds ()
  // $maximum-integer is the standard value, not from the generic-arithmetic module.
  let int :: <double-integer> = plus($maximum-integer, 1);
  check-no-errors("number-to-string(<double-integer>)",
                  number-to-string(int));
end;

define test test-process-id ()
  for (pattern in #("%{pid}", "%p"),
       i from 1)
    let target = make(<string-log-target>);
    let log = make(<log>,
                   name: format-to-string("test-process-id-%s", i),
                   targets: list(target),
                   formatter: make(<log-formatter>, pattern: pattern),
                   level: $trace-level);
    log-info(log, "this is ignored");
    check-equal("log stream contains process id only",
                stream-contents(target.target-stream),
                format-to-string("%d\n", current-process-id()));
  end;
end test test-process-id;
