Module: dylan-user
Author: Carl L Gay
Copyright: Copyright (c) 2013 Dylan Hackers.  See License.txt for details.

define library logging
  use common-dylan;
  use big-integers;
  use generic-arithmetic;
  use io,
    import: { format, print, standard-io, streams };
  use system,
    import: { date, file-system, locators, threads };

  export
    logging,
    logging-impl;

end library logging;

define module logging
  create
    // Loggers
    // Maybe rename to <log> and log-*
    <logger>,
    log-formatter,
    log-formatter-setter,
    log-level,
    log-level-setter,
    log-level-applicable?,
    log-targets,
    logger-name,
    logger-additive?,
    logger-additive?-setter,
    logger-enabled?,
    logger-enabled?-setter,
    get-logger,
    get-root-logger,
    add-target,
    remove-all-targets,
    remove-target,

    // Levels
    <log-level>,
    <trace-level>, $trace-level,
    <debug-level>, $debug-level,
    <info-level>,  $info-level,
    <warn-level>,  $warn-level,
    <error-level>, $error-level,
    level-name,

    // Targets
    <log-target>,
    <null-log-target>,
    <stream-log-target>,
      target-stream,
    <file-log-target>,
      target-pathname,
      open-target-stream,
    <rolling-file-log-target>,
    $stdout-log-target,
    $stderr-log-target,
    $null-log-target,

    // Functions
    log-trace,
    log-debug,
    log-debug-if,
    log-info,
    log-warning,
    log-error,

    // Formatters
    <log-formatter>,
    $default-log-formatter,

    // Errors
    <logging-error>,

    // For building your own logging classes
    <abstract-logger>,
    <placeholder-logger>,
    log-to-target,
    log-message,
    current-log-object,
    current-log-args,
    pattern-to-stream,
    write-message;

end module logging;

define module logging-impl
  use common-dylan,
    exclude: { format-to-string };
  use date;
  use file-system;
    //import: { <file-stream>, <pathname>, rename-file };
  use format;
  use generic-arithmetic,
    import: { <integer> => <double-integer>,
              + => plus,
              * => mul,
              / => div };
  use locators,
    import: { <locator>,
              <file-locator>,
              locator-name,
              merge-locators };
  use logging;
  use print;
  use standard-io;
  use streams;
  use threads;

  export
    // for test suite
    elapsed-milliseconds,
    reset-logging,
    current-process-id;  // Move to System lib.

end module logging-impl;

