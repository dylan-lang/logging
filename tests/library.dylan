Module: dylan-user
Author: Carl L Gay
Copyright: Copyright (c) 2013 Dylan Hackers.  See License.txt for details.

define library logging-test-suite
  use common-dylan;
  use generic-arithmetic;
  use io;
  use logging;
  use system,
    import: { date, file-system, locators };
  use testworks;
  use testworks-specs;

  export logging-test-suite;
end;

define module logging-test-suite
  use common-dylan;
  use date;
  use generic-arithmetic,
    import: { <integer> => <double-integer>, + => plus, * => mul, / => div };
  use logging;
  use logging-impl;
  use streams;
  use file-system;
    //import: { <pathname>, with-open-file };
  use locators;
  use testworks;
  use testworks-specs;

  export logging-test-suite;
end;


