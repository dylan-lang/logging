Module: dylan-user
Author: Carl L Gay
Copyright: Copyright (c) 2013 Dylan Hackers.  See License.txt for details.

define library logging-test-suite
  use common-dylan;
  use generic-arithmetic;
  use io;
  use logging;
  use system,
    import: { date, file-system, locators, operating-system };
  use testworks;
end library;

define module logging-test-suite
  use common-dylan;
  use date;
  use format;
  use generic-arithmetic,
    import: { <integer> => <double-integer>, + => plus, * => mul, / => div };
  use logging;
  use logging-impl;
  use streams;
  use file-system,
    import: { delete-file, ensure-directories-exist, file-exists?, <pathname>, with-open-file };
  use locators;
  use operating-system,
    import: { current-process-id };
  use testworks;
  use threads;
end module;
