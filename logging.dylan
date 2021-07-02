Module:    logging-impl
Author:    Carl L Gay
Synopsis:  Simple logging mechanism.  Some ideas taken from log4j.
Copyright: Copyright (c) 2013 Dylan Hackers.  See License.txt for details.


/*

See README.rst for documentation.

todo -- implement keep-versions in <rolling-file-log-target>

todo -- implement compress-on-close? in <rolling-file-log-target>

todo -- configuration parser

todo -- more documentation

todo -- more tests

todo -- Handle errors gracefully.  e.g., if the disk fills up it may be
        better to do nothing than to err.  Catch errors in user code when
        logging a message and log "*** error generating log message ***",
        for example.  If logging to stream/file fails, log to stderr as
        a fallback.  (e.g., someone forks and closes all fds)

todo -- <file-log-target> should accept a string for the filename to
        avoid making people import locators.  God I hate the locators
        library.

todo -- <rolling-file-log-target>: Should roll the file when either a
        max size or a max time is reached, whichever comes first.
        Should make it possible for users to override roll-log-file?
        and rolled-log-file-name methods if they want to roll their
        own.  Should also have option to compress on roll.  Should also
        be able to specify that it roll "daily at midnight" etc.

todo -- Add a way to extend the set of format directives from outside
        the library.  Get rid of code duplication in formatter parsing.

??? -- Is there a reasonable use case where you might not want \n at the
       end of each log entry?  Rather than hard-coding the \n one could
       specify it in the formatter's control string.  The worry is that
       everyone would forget to add it every time they write a new formatter.

idea -- There's often a tension between the level of logging you want
        to retain permanently and the level of logging you need for
        debugging.  Could support writing different log levels to
        additional targets.  Then one could log debug messages to a
        separate file and set them to roll every 5 minutes, with a
        small number of revisions, and you have essentially a circular
        buffer of recent debug info.  Log to RAMdisk...even better, to
        avoid disk contention.  :-)

idea -- It is useful for general purpose libraries (e.g., an XML parser)
        to do logging.  You normally want this logging disabled.  A calling
        library will probably want to turn on the XML parser's logging for
        specific threads, for debugging purposes.  The XML parser can use
        an exported thread variable to hold its debug log and callers can
        rebind that to the log they want.  (Not really an issue for this
        logging library to address...more of a suggestion for something to
        add to future documentation.)  Just enabling the XML parser's log
        won't always be what users want because it will enable logging in
        all threads.

todo -- Look at concurrency issues.  For example, is it possible for log
        messages to be written with out-of-order timestamps when multiple
        threads log to the same file via different log targets.  Can either
        document that and say "don't do that" or fix it.  Similarly, could
        add OPTIONAL file locking (a la fcntl.flock(fd, LOCK_EX)) so that
        multiple processes can ensure that large log messages are written
        atomically and guarantee monotonically increasing log entry dates.
        Must be optional since it's heavyweight.

idea -- Support logging categories.  Each log message is associated with a
        category.  Each category has a log level associated with it.  This
        makes it easy to adjust the types of debug logging per category at
        run time.  Categories could be hierarchical so that messages from
        entire subsystems can be enabled/disabled en masse.

todo -- See http://pypi.python.org/pypi/LogPy/1.0 for some (well, at least one)
        interesting ideas.  Attach arbitrary tags to log messages (instead of
        hierarchical categories or in addition to?).

*/


///////////////////////////////////////////////////////////
//// Log classes
////

define variable $root-log :: false-or(<log>) = #f;

define sealed generic log-name
    (log :: <abstract-log>) => (name :: <string>);

define sealed generic log-parent
    (log :: <abstract-log>) => (parent :: false-or(<abstract-log>));

define sealed generic log-children
    (log :: <abstract-log>) => (children :: <string-table>);

define sealed generic log-additive?
    (log :: <abstract-log>) => (additive? :: <boolean>);

define sealed generic log-additive?-setter
    (new-value :: <boolean>, log :: <abstract-log>) => (additive? :: <boolean>);

define sealed generic log-enabled?
    (log :: <abstract-log>) => (enabled? :: <boolean>);

define sealed generic log-enabled?-setter
    (new-value :: <boolean>, log :: <abstract-log>) => (enabled? :: <boolean>);

define abstract class <abstract-log> (<object>)
  // A dotted path name.  All parent logs in the path must already exist.
  constant slot log-name :: <string>,
    required-init-keyword: name:;

  slot log-parent :: false-or(<abstract-log>) = #f,
    init-keyword: parent:;

  constant slot log-children :: <string-table> = make(<string-table>),
    init-keyword: children:;

  // If this is #t then log messages sent to this log will be passed up
  // the hierarchy to parent logs as well, until it reaches a log
  // whose additivity is #f.  Terminology stolen from log4j.
  //
  slot log-additive? :: <boolean> = #t,
    init-keyword: additive?:;

  // If disabled, no messages will be logged to this log's targets.
  // The value of log-additive? will still be respected.  In other
  // words, logging to a disabled log will still log to ancestor
  // logs if they are themselves enabled.
  //
  slot log-enabled? :: <boolean> = #t,
    init-keyword: enabled?:;

end class <abstract-log>;

define method initialize
    (log :: <abstract-log>, #key name :: <string>)
  next-method();
  if ($root-log)
    add-log($root-log, log, as(<list>, split(name, '.')), name);
  end;
end method initialize;

define function local-name
    (log :: <abstract-log>)
 => (local-name :: <string>)
  last(split(log.log-name, '.'))
end;

// Instances of this class are used as placeholders in the log hierarchy when
// a log is created before its parents are created.  i.e., if the first log
// created is named "x.y.z" then both x and x.y will be <placeholder-log>s.
// (If x.y is later created as a real log then the placeholder will be replaced.)
//
define open class <placeholder-log> (<abstract-log>)
end;

define sealed generic log-level
  (log :: <log>) => (level :: <log-level>);

define sealed generic log-level-setter
  (level :: <log-level>, log :: <log>) => (level :: <log-level>);

define sealed generic log-targets
  (log :: <log>) => (targets :: <vector>);

define sealed generic log-formatter
  (log :: <log>) => (formatter :: <log-formatter>);

define open class <log> (<abstract-log>)
  slot log-level :: <log-level> = $info-level,
    init-keyword: level:;

  constant slot log-targets :: <stretchy-vector> = make(<stretchy-vector>),
    init-keyword: targets:;

  slot log-formatter :: <log-formatter> = $default-log-formatter,
    init-keyword: formatter:;

end class <log>;

define method make
    (class :: subclass(<log>),
     #rest args,
     #key formatter, targets :: false-or(<sequence>))
 => (log)
  // Formatter may be specified as a string for convenience.
  if (instance?(formatter, <string>))
    formatter := make(<log-formatter>, pattern: formatter);
  end;
  // Make sure targets is a <stretchy-vector>.  It's convenient for users
  // to be able to pass list(make(<target> ...)) though.
  let targets = as(<stretchy-vector>, targets | #[]);
  apply(next-method, class,
        targets: targets,
        formatter: formatter | $default-log-formatter,
        args)
end method make;

define method print-object
    (log :: <log>, stream :: <stream>)
 => ()
  if (*print-escape?*)
    next-method();
  else
    format(stream, "%s (%sadditive, level: %s, targets: %s)",
           log.log-name,
           if (log.log-additive?) "" else "non-" end,
           log.log-level.level-name,
           if (empty?(log.log-targets))
             "None"
           else
             join(log.log-targets, ", ", key: curry(format-to-string, "%s"))
           end);
  end;
end method print-object;

define method add-target
    (log :: <log>, target :: <log-target>) => ()
  add-new!(log.log-targets, target)
end;

define method remove-target
    (log :: <log>, target :: <log-target>) => ()
  remove!(log.log-targets, target);
end;

define method remove-all-targets
    (log :: <log>) => ()
  for (target in log.log-targets)
    remove-target(log, target)
  end;
end;

define open class <logging-error> (<error>, <simple-condition>)
end;

define function logging-error
    (control-string, #rest args)
  signal(make(<logging-error>,
              format-string: control-string,
              format-arguments: args))
end;

define function get-root-log
    () => (log :: <log>)
  $root-log
end;

define function get-log
    (name :: <string>) => (log :: false-or(<abstract-log>))
  %get-log($root-log, as(<list>, split(name, '.')), name)
end;

define method %get-log
    (log :: <abstract-log>, path :: <list>, original-name :: <string>)
  if (empty?(path))
    log
  else
    let child = element(log.log-children, first(path), default: #f);
    child & %get-log(child, path.tail, original-name)
  end
end method %get-log;

define method %get-log
    (log :: <placeholder-log>, path :: <list>, original-name :: <string>)
  ~empty?(path) & next-method()
end method %get-log;

define method %get-log
    (log == #f, path :: <list>, original-name :: <string>)
  logging-error("Log not found: %s", original-name);
end method %get-log;


define function add-log
    (parent :: <abstract-log>, new :: <abstract-log>, path :: <list>,
     original-name :: <string>)
  let name :: <string> = first(path);
  let child = element(parent.log-children, name, default: #f);
  if (path.size == 1)
    if (child)
      if (instance?(child, <placeholder-log>))
        // Copy the placeholder's children into the new log that
        // is replacing it.
        for (grandchild in child.log-children)
          new.log-children[local-name(grandchild)] := grandchild;
          grandchild.log-parent := new;
        end;
      else
        logging-error("Invalid log name, %s.  A child log named %s "
                      "already exists.", original-name, name);
      end;
    end;
    parent.log-children[name] := new;
    new.log-parent := parent;
  else
    if (~child)
      child := make(<placeholder-log>, name: name, parent: parent);
      parent.log-children[name] := child;
    end;
    add-log(child, new, path.tail, original-name);
  end;
end function add-log;




///////////////////////////////////////////////////////////
//// Log severity levels
////

// Returns a short string naming the level.
define generic level-name (level :: <log-level>) => (name :: <byte-string>);

// Root of the log level hierarchy.  Logging uses a simple class
// hierarchy to determine what messages should be logged.
//
define open abstract primary class <log-level> (<object>)
  constant slot level-name :: <byte-string>;
  constant slot level-short-name :: <byte-string>;
end;

define open class <trace-level> (<log-level>)
  inherited slot level-name = "TRACE";
  inherited slot level-short-name = "T";
end;

define open class <debug-level> (<trace-level>)
  inherited slot level-name = "DEBUG";
  inherited slot level-short-name = "D";
end;

define open class <info-level> (<debug-level>)
  inherited slot level-name = "INFO";
  inherited slot level-short-name = "I";
end;

define open class <warn-level> (<info-level>)
  inherited slot level-name = "WARNING";
  inherited slot level-short-name = "W";
end;

define open class <error-level> (<warn-level>)
  inherited slot level-name = "ERROR";
  inherited slot level-short-name = "E";
end;

define constant $trace-level = make(<trace-level>);
define constant $debug-level = make(<debug-level>);
define constant $info-level = make(<info-level>);
define constant $warn-level = make(<warn-level>);
define constant $error-level = make(<error-level>);

define method log-level-applicable?
    (given-level :: <log-level>, level :: <log-level>)
 => (applicable? :: <boolean>)
  instance?(given-level, level.object-class)
end;




///////////////////////////////////////////////////////////
//// Logging messages
////

define generic log-message
    (level :: <log-level>, log :: <abstract-log>, object :: <object>, #rest args)
 => ();

// This is generally called via log-info, log-error, etc, not directly.
//
define method log-message
    (level :: <log-level>, log :: <log>, object :: <object>, #rest args)
 => ()
  if (log.log-enabled?  & log-level-applicable?(level, log.log-level))
    for (target :: <log-target> in log.log-targets)
      log-to-target(target, level, log.log-formatter, object, args);
    end;
  end;
  if (log.log-additive? & log.log-parent)
    apply(log-message, level, log.log-parent, object, args);
  end;
end method log-message;

define method log-message
    (level :: <log-level>, log :: <placeholder-log>, object :: <object>, #rest args)
 => ()
  if (log.log-additive? & log.log-parent)
    apply(log-message, level, log.log-parent, object, args)
  end;
end;

define inline function log-trace (object, #rest args) => ()
  apply(log-message, $trace-level, *log*, object, args);
end;

define inline function log-debug (object, #rest args) => ()
  apply(log-message, $debug-level, *log*, object, args);
end;

define inline function log-info (object, #rest args) => ()
  apply(log-message, $info-level, *log*, object, args);
end;

define inline function log-warning (object, #rest args) => ()
  apply(log-message, $warn-level, *log*, object, args);
end;

define inline function log-error (object, #rest args) => ()
  apply(log-message, $error-level, *log*, object, args);
end;

define function log-debug-if (test, object, #rest args) => ()
  if (test)
    apply(log-message, $debug-level, *log*, object, args);
  end;
end;


///////////////////////////////////////////////////////////
//// Targets
////

// Abstract target for logging.  Subclasses represent different
// backend targets such as streams, files, databases, etc.
//
define open abstract class <log-target> (<closable-object>)
end;


// When this is called, the decision has already been made that this object
// must be logged for the given log level, so methods should unconditionally
// write the object to the backing store.
//
define open generic log-to-target
    (target :: <log-target>, level :: <log-level>, formatter :: <log-formatter>,
     object :: <object>, args :: <sequence>)
 => ();

// Override this if you want to use a normal formatter string but
// want to write objects to the log stream instead of strings.
//
define open generic write-message
    (target :: <log-target>, object :: <object>, args :: <sequence>)
 => ();


// Note that there is no default method on "object :: <object>".

define method close
    (target :: <log-target>, #key)
 => ()
  // do nothing
end;

// A log target that simply discards its output.
define sealed class <null-log-target> (<log-target>)
end;

define sealed method log-to-target
    (target :: <null-log-target>, level :: <log-level>,
     formatter :: <log-formatter>, format-string :: <string>,
     args :: <sequence>)
 => ()
  // do nothing
end;

define constant $null-log-target :: <null-log-target>
  = make(<null-log-target>);

// A log target that outputs directly to a stream.
// e.g., make(<stream-log-target>, stream: *standard-output*)
//
define open class <stream-log-target> (<log-target>)
  constant slot target-stream :: <stream>,
    required-init-keyword: #"stream";
end;

define method print-object
    (target :: <stream-log-target>, stream :: <stream>)
 => ()
  if (*print-escape?*)
    next-method();
  else
    write(stream, "stream target");
  end;
end method print-object;

define constant $stdout-log-target
  = make(<stream-log-target>, stream: *standard-output*);

define constant $stderr-log-target
  = make(<stream-log-target>, stream: *standard-error*);

define method log-to-target
    (target :: <stream-log-target>, level :: <log-level>, formatter :: <log-formatter>,
     format-string :: <string>, args :: <sequence>)
 => ()
  let stream :: <stream> = target.target-stream;
  with-stream-locked (stream)
    pattern-to-stream(formatter, stream, level, target, format-string, args);
    write(stream, "\n");
    force-output(stream);
  end;
end method log-to-target;

define method write-message
    (target :: <stream-log-target>, format-string :: <string>, args :: <sequence>)
 => ()
  apply(format, target.target-stream, format-string, args);
end method write-message;


// A log target that is backed by a single, monolithic file.
// (Why is this not a subclass of <stream-log-target>?)
//
define class <file-log-target> (<log-target>)
  constant slot target-pathname :: <pathname>,
    required-init-keyword: pathname:;
  slot target-stream :: false-or(<file-stream>) = #f;
end;

define method initialize
    (target :: <file-log-target>, #key)
  next-method();
  open-target-stream(target);
end;

define method print-object
    (target :: <file-log-target>, stream :: <stream>)
 => ()
  if (*print-escape?*)
    next-method();
  else
    format(stream, "file %s", as(<string>, target.target-pathname));
  end;
end method print-object;

define open generic open-target-stream
    (target :: <file-log-target>) => (stream :: <stream>);

define method open-target-stream
    (target :: <file-log-target>)
 => (stream :: <file-stream>)
  ensure-directories-exist(target.target-pathname);
  target.target-stream := make(<file-stream>,
                               locator: target.target-pathname,
                               element-type: <character>,
                               direction: #"output",
                               if-exists: #"append",
                               if-does-not-exist: #"create")
end;

define method log-to-target
    (target :: <file-log-target>, level :: <log-level>,
     formatter :: <log-formatter>, format-string :: <string>,
     format-args :: <sequence>)
 => ()
  let stream :: <stream> = target.target-stream;
  with-stream-locked (stream)
    pattern-to-stream(formatter, stream, level, target, format-string, format-args);
    write(stream, "\n");
    force-output(stream);
  end;
end method log-to-target;

define method write-message
    (target :: <file-log-target>, format-string :: <string>, args :: <sequence>)
 => ()
  apply(format, target.target-stream, format-string, args);
end;

define method close
    (target :: <file-log-target>, #key abort?)
 => ()
  if (target.target-stream)
    close(target.target-stream, abort?: abort?);
  end;
end;

// A log target that is backed by a file and ensures that the file
// only grows to a certain size, after which it is renamed to
// filename.<date-when-file-was-opened>.
//
// I investigated making this a subclass of <wrapper-stream> but it
// didn't work well due to the need to create the inner-stream
// first and pass it as an init arg.  That doesn't work too well
// given that I want to roll the log if the file exists when I
// first attempt to open it.  It leads to various special cases.
//
// Attempt to re-open the file if logging to it gets (the equivalent
// of) bad file descriptor?
//
define class <rolling-file-log-target> (<file-log-target>)

  constant slot max-file-size :: <integer> = 100 * 1024 * 1024,
    init-keyword: max-size:;

  // TODO: not yet implemented
  // If this is #f then all versions are kept.
  //constant slot keep-versions :: false-or(<integer>) = #f,
  //  init-keyword: #"keep-versions";

  // TODO: not yet implemented
  //constant slot compress-on-close? :: <boolean> = #t,
  //  init-keyword: #"compress?";

  // Date when the underlying file was created.  When it gets closed
  // it will be renamed with this date in the name.
  slot file-creation-date :: <date> = current-date();

end class <rolling-file-log-target>;

define constant $log-roller-lock :: <lock> = make(<lock>);


define method initialize
    (target :: <rolling-file-log-target>, #key roll :: <boolean> = #t)
  if (roll
        & file-exists?(target.target-pathname)
        & file-property(target.target-pathname, #"size") > 0)
    roll-log-file(target);
  end;
  next-method();
end method initialize;

define method print-object
    (target :: <rolling-file-log-target>, stream :: <stream>)
 => ()
  if (*print-escape?*)
    next-method();
  else
    format(stream, "rolling file %s", as(<string>, target.target-pathname));
  end;
end method print-object;

define method log-to-target
    (target :: <rolling-file-log-target>, level :: <log-level>,
     formatter :: <log-formatter>, format-string :: <string>,
     format-args :: <sequence>)
 => ()
  next-method();
  // todo -- calling stream-size may be very slow?  Maybe log-to-target should
  // return the number of bytes written, but that could be inefficient (e.g.,
  // it might have to format to string and then write that to the underlying
  // stream instead of formatting directly to the stream).
  if (stream-size(target.target-stream) >= target.max-file-size)
    roll-log-file(target);
  end;
end;

define method roll-log-file
    (target :: <rolling-file-log-target>)
  with-lock ($log-roller-lock)
    if (target.target-stream)  // may be #f first time
      close(target.target-stream);
    end;
    // todo -- make the archived log filename accept %{date:fmt} and
    //         %{version} escapes.  e.g., "foo.log.%{version}"
    // Also consider putting more info in the rolled filenames, such
    // as process id, hostname, etc.  Makes it easier to combine files
    // into a single location.
    let date = format-date("%Y%m%dT%H%M%S", target.file-creation-date);
    let oldloc = as(<file-locator>, target.target-pathname);
    let newloc = merge-locators(as(<file-locator>,
                                   concatenate(locator-name(oldloc), ".", date)),
                                oldloc);
    rename-file(oldloc, newloc);
    target.file-creation-date := current-date();
    open-target-stream(target);
  end with-lock;
end method roll-log-file;


///////////////////////////////////////////////////////////
//// Formatting
////

define open class <log-formatter> (<object>)
  constant slot formatter-pattern :: <string>,
    required-init-keyword: pattern:;
  slot parsed-pattern :: <sequence>;
end class <log-formatter>;

// Leave in for debugging for now.
ignore(formatter-pattern);

define method initialize
    (formatter :: <log-formatter>, #key pattern :: <string>)
  next-method();
  formatter.parsed-pattern := parse-formatter-pattern(pattern);
end;

// Should be called with the stream locked.
//
define method pattern-to-stream
    (formatter :: <log-formatter>, stream :: <stream>,
     level :: <log-level>, target :: <log-target>,
     object :: <object>, args :: <sequence>)
 => ()
  for (item in formatter.parsed-pattern)
    if (instance?(item, <string>))
      write(stream, item);
    else
      // This is a little hokey, but it was easier to allow some
      // formatter functions to just return a string and others
      // to write to the underlying stream, so if the function
      // returns #f it means "i already did my output".
      let result = item(level, target, object, args);
      if (result)
        write(stream, result);
      end;
    end;
  end;
end method pattern-to-stream;

// Parse a string of the form "%{r} blah %{m} ..." into a list of functions
// and/or strings.  The functions can be called with no arguments and return
// strings.  The concatenation of all the resulting strings is the log message.
// (The concatenation needn't ever be done if writing to a stream, but I do
// wonder which would be faster, concatenation or multiple stream writes.
// Might be worth benchmarking at some point.)
//
define method parse-formatter-pattern
    (pattern :: <string>)
 => (parsed :: <sequence>)
  let result :: <stretchy-vector> = make(<stretchy-vector>);
  block (exit)
    let dispatch-char :: <byte-character> = '%';
    let index :: <integer> = 0;
    let control-size :: <integer> = pattern.size;
    local method next-char () => (char :: <character>)
            if (index >= control-size)
              logging-error("Log format control string ended prematurely: %s",
                            pattern);
            else
              let char = pattern[index];
              index := index + 1;
              char
            end
          end method;
    local method peek-char () => (char :: false-or(<character>))
            if (index < control-size)
              pattern[index]
            end
          end;
    while (index < control-size)
      // Skip to dispatch char.
      for (i :: <integer> = index then (i + 1),
           until: ((i == control-size)
                   | (pattern[i] == dispatch-char)))
      finally
        if (i ~== index)
          add!(result, copy-sequence(pattern, start: index, end: i));
        end;
        if (i == control-size)
          exit();
        else
          index := i + 1;
        end;
      end for;
      let start :: <integer> = index;
      let align :: <symbol> = #"right";
      let width :: <integer> = 0;
      let char = next-char();
      if (char == '-')
        align := #"left";
        char := next-char();
      end;
      if (member?(char, "0123456789"))
        let (wid, idx) = string-to-integer(pattern, start: index - 1);
        width := wid;
        index := idx;
        char := next-char();
      end;
      local method pad (string :: <string>)
              let len :: <integer> = string.size;
              if (width <= len)
                string
              else
                let fill :: <string> = make(<string>, size: width - len, fill: ' ');
                if (align == #"left")
                  concatenate(string, fill)
                else
                  concatenate(fill, string)
                end
              end
            end method;
      local method parse-long-format-control ()
              let bpos = index;
              while (~member?(peek-char(), ":}")) next-char() end;
              let word = copy-sequence(pattern, start: bpos, end: index);
              let arg = #f;
              if (pattern[index] == ':')
                next-char();
                let start = index;
                while(peek-char() ~= '}') next-char() end;
                arg := copy-sequence(pattern, start: start, end: index);
              end;
              next-char();   // eat '}'
              select (word by \=)
                "date" =>
                  method (#rest args)
                    pad(if (arg)
                          format-date(arg, current-date())
                        else
                          as-iso8601-string(current-date())
                        end)
                  end;
                "level" =>      // deprecated, use "severity"
                  method (level, target, object, args)
                    pad(level-name(level))
                  end;
                "severity" =>
                  // Would be nice to do this padding at compile time since the severity
                  // level is explicit in the log-info etc call. Just pass the level to
                  // this function (parse-formatter-pattern).
                  method (level, target, object, args)
                    pad(level-name(level))
                  end;
                "message" =>
                  method (level, target, object, args)
                    write-message(target, object, args);
                    #f
                  end;
                "pid" =>
                  method (#rest args)
                    pad(integer-to-string(current-process-id()));
                  end;
                "millis" =>
                  method (#rest args)
                    pad(number-to-string(elapsed-milliseconds()));
                  end;
                "thread" =>
                  method (#rest args)
                    pad(thread-name(current-thread()));
                  end;
                otherwise =>
                  // Unknown control string.  Just output the text we've seen...
                  copy-sequence(pattern, start: start, end: index);
              end select;
            end method;
      add!(result,
           select (char)
             '{' => parse-long-format-control();
             'd' =>
               method (#rest args)
                 pad(as-iso8601-string(current-date()));
               end;
             'l', 'L' =>
               method (level, target, object, args)
                 pad(level-name(level))
               end;
             'm' =>
               method (level, target, object, args)
                 write-message(target, object, args);
                 #f
               end;
             'p' =>
               method (#rest args)
                 pad(integer-to-string(current-process-id()));
               end;
             'r' =>
               method (#rest args)
                 pad(number-to-string(elapsed-milliseconds()));
               end;
             's' =>
               method (level, target, object, args)
                 pad(level-short-name(level))
               end;
             't' =>
               method (#rest args)
                 pad(thread-name(current-thread()));
               end;
             '%' => pad("%");
             otherwise =>
               // Unknown control char.  Just output the text we've seen...
               copy-sequence(pattern, start: start, end: index);
           end);
    end while;
  end block;
  result
end method parse-formatter-pattern;

define constant $default-log-formatter :: <log-formatter>
  = make(<log-formatter>, pattern: "%s %{date:%Y-%m-%dT%H:%M:%S.%F%z} [%t] %m");

define constant $application-start-date :: <date> = current-date();

define function elapsed-milliseconds
    () => (millis :: <double-integer>)
  let duration :: <duration> = current-date() - $application-start-date;
  let (days, hours, minutes, seconds, microseconds) = decode-duration(duration);
  floor(plus(div(microseconds, 1000.0),
             plus(mul(seconds, 1000),
                  plus(mul(minutes, 60000),
                       plus(mul(hours, 3600000), mul(days, 86400000))))))
end function;


/////////////////////////////////////////////////////
//// Default log

// This makes it simple, and relatively concise, for small libraries to
// do logging via log-info et al without having to pass the log each time.
// Just set this at start-up. Libraries that log to this will obviously
// log to stderr unless it is re-bound and will also log to stderr if they
// log at load time. No locking is provided. Threaded libraries should
// provide their own locking if needed.

define thread variable *log* :: <log>
  = make(<log>,
         name: "default",
         targets: list($stderr-log-target));


/////////////////////////////////////////////////////
//// For use by the test suite
////

define function reset-logging
    ()
  // maybe should close existing log targets?
  $root-log := make(<log>, name: "root", additive?: #f, enabled?: #f);
end;

/////////////////////////////////////////////////////
//// Initialize
////

begin
  reset-logging();
end;
