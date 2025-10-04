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

define test test-format-thread ()
  local
    method log-in-thread (n, pattern, thread-name)
      let target = make(<string-log-target>);
      local method thread-top-level ()
              let log = make(<log>,
                             name: format-to-string("test-format-thread-%d", n),
                             targets: list(target),
                             formatter: make(<log-formatter>, pattern: pattern),
                             level: $trace-level);
              log-message($trace-level, log, "ignored");
            end;
      let thread = make(<thread>,
                        name: thread-name,
                        function: thread-top-level);
      join-thread(thread);
      values(stream-contents(target.target-stream),
             thread-id(thread))
    end method;
  assert-equal("foo\n", log-in-thread(1, "%{thread}", "foo"));
  assert-equal("bar\n", log-in-thread(2, "%t", "bar"));
  let (message, thread-id) = log-in-thread(3, "%{thread}", #f);
  assert-equal(format-to-string("%d\n", thread-id), message);
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

// Make sure that if a relative locator is given for a rolling log file
// the new file is created in the same directory when the log rolls.
define test test-rolling-log-file-absolutism ()
  let cwd = working-directory();
  let test-dir = test-temp-directory();
  block ()
    working-directory() := test-dir;

    // Create the target and the first log file...
    let relative = as(<file-locator>, "rolling.log");
    let absolute = merge-locators(relative, test-dir);
    assert-false(file-exists?(relative));
    assert-false(file-exists?(absolute));
    let target = make(<rolling-file-log-target>,
                      pathname: relative,
                      max-size: 10);
    let formatter = make(<log-formatter>, pattern: "%m");
    assert-true(file-exists?(relative), "relative file exists after creating target?");
    assert-true(file-exists?(absolute), "absolute file exists after creating target?");

    // Because the initial file timestamp is stored when the target is created,
    // and then again when it is rolled, we need to make sure it doesn't roll
    // in the same second as when it was created, or the NEXT roll will have a
    // filename conflict.
    sleep(1.0);

    // This should roll the file since it outputs more than 10 bytes and the
    // roll check is performed after doing output, not before.
    log-to-target(target, $info-level, formatter, "aaaaaaaaaaaaaaaaaaaa", #[]);
    let files1 = directory-contents(test-dir);
    assert-equal(2, files1.size);

    // Change working directory
    let subdir = subdirectory-locator(test-dir, "subdir");
    ensure-directories-exist(subdir);
    working-directory() := subdir;

    // This should roll the file again.
    log-to-target(target, $info-level, formatter, "bbbbbbbbbbbbbbbbbbbb", #[]);
    let files2 = directory-contents(test-dir);
    assert-equal(4, files2.size); // including subdir
  cleanup
    working-directory() := cwd;
  end block;
end test;
