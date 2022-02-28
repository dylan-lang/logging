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
    import: { date, file-system, locators, operating-system, threads };

  export
    logging,
    logging-impl;

end library logging;

define module logging
  create
    *log*,
    <log>,
    log-formatter,
    log-formatter-setter,
    log-level,
    log-level-setter,
    log-level-applicable?,
    log-targets,
    log-name,
    log-additive?,
    log-additive?-setter,
    log-enabled?,
    log-enabled?-setter,
    get-log,
    get-root-log,
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
    <abstract-log>,
    <placeholder-log>,
    log-to-target,
    log-message,
    pattern-to-stream,
    write-message;

end module logging;

define module logging-impl
  use common-dylan,
    exclude: { format-to-string };
  use date;
  use file-system;
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
              merge-locators,
              simplify-locator };
  use logging;
  use operating-system,
    import: { current-process-id };
  use print;
  use standard-io;
  use streams;
  use threads;

  export
    // for test suite
    elapsed-milliseconds,
    reset-logging;
end module logging-impl;
