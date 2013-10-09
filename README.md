
# CL-REACTIVE: Reactive functions in Common Lisp

The `CL-REACTIVE` package provides support for reactive programming in
Common Lisp at the function level.  In reactive programming, changing
the value of a variable.

The common example of reactive programming is a spreadsheet where
changing the value of one cell causes a variety of other cells to be
recalculated.

Common Lisp already has `Cells` which is reactive programming based on
CLOS slots.  Here, reactive programming is handled at a function and
variable level instead of at the slot level.

This package provides signal variables and signal functions.  Signal
variables hold a single, typed value.  Signal functions calculate
their value from the values of signal variables and/or other signal
functions.  Signal variables and signal functions are collectively
referred to as signals.  In most instances, it is not necessary to
distinguish between signal variables and signal functions.  The only
important distinction between the two are that one can explicitly set
the signal value of a signal variable while one cannot do the same for
a signal function.

## Basic Signal Manipulations

The fundamental building blocks for all signal operations are:
querying signal values, defining new signal variables, defining new
signal functions, and delaying eager recalculation of signal
functions.

### Querying Signal Values

Given a signal `SIG`, one can query its value with the `SIGNAL-VALUE`
method.

    (signal-value sig) => current value of the signal

If `SIG` is a signal-variable, one can set the signal value with
`SETF`:

    (setf (signal-value sig) new-signal-value)

One can also use the convenience macro `WITH-SIGNAL-VALUES` to work
directly with the value:

    (defmacro with-signal-values (&rest decls) &body body)

The `DECLS` here is a list of entries each of the form
`(VARNAME SIGNAL)`.  Each `VARNAME` will be bound to the signal value
of the corresponding `SIGNAL`.  For example, given signals `SIG1` and
`SIG2` where `SIG1` is a signal variable and `SIG2` is any signal, one
might do something like:

    (with-signal-values ((v1 sig1)
                         (v2 sig2))
      (incf v1)
      (+ v1 v2))

The `WITH-SIGNAL-VALUES` macro here uses `SYMBOL-MACROLET` to bind
`V1` to the value of `SIG1` and `V2` to the value of `SIG2`.

### Defining Signal Variables

One can define a signal variable with global scope using the macro
`DEFSIGNAL-VARIABLE`:

    (defmacro defsignal-variable (name value
                                  &key (type t) documentation)
       ...)

This macro creates a global signal variable bound to the given `NAME`.
The initial value of the signal variable is `VALUE`.  One can
optionally specify the `TYPE` for this signal's values and a
`DOCUMENTATION` string for this signal.  For example, the following
snippet creates a signal variable for monitoring the current
temperature:

    (defsignal-variable *current-temperature* 0
              :type real
              :documentation "Current temperature in degrees Celsius.")

One can also define signal variables in the local context using the macro
`SIGNAL-LET`:

    (defmacro signal-let ((&rest decls) &body body) ...)

The `SIGNAL-LET` macro acts like `LET` but binds signal variables to
the names.  The `DECLS` in `SIGNAL-LET` can be either a symbol or a
list of the form `(NAME VALUE &KEY (TYPE T) DOCUMENTATION)`.  For
example, the following creates a list of three signal variables.

    (signal-let ((sig-a 0 :type integer :documentation "First Signal")
                 (sig-b nil :documentation "Second Signal")
                 sig-c)
      (list sig-a sig-b sig-c))

### Defining Signal Functions

One can define a signal function (calculated signal) with global scope
using the macro `DEFSIGNAL-FUNCTION`:

    (defmacro defsignal-function (name (&rest depends) &body body)
       ...)

This macro creates a global signal function bound to the given `NAME`.
The signal value is calculated from the `BODY` using the signals listed
in `DEPENDS`.  The `DEPENDS` here is a list of entries each of the
form `(VARNAME SIGNAL)`.  Each `VARNAME` will be bound to the signal
value of the corresponding `SIGNAL` for the `BODY`.  The `BODY` will
be executed each time one of the `DEPENDS` signals is updated.

The `NAME` here can be either a symbol or a list of the form
`(NAME &KEY (TYPE T) DOCUMENTATION)`.  The results generated by `BODY`
must conform to the specified `TYPE`.  The `DOCUMENTATION` here will
be used on the signal function itself as well as the wrapper function
`#'NAME`.  If `DOCUMENTATION` is not specified and the `BODY` begins
with a string, that string will be used as the `DOCUMENTATION`.

For example, the following snippet creates a signal variable for
monitoring the current temperature in Farenheit:

    (defsignal-function (current-temperature-f :type real)
                           ((celsius *current-temperature*))
      "Current temperature in degrees Farenheit."
      (+ (* 9/5 celsius) 32))

One can also define signal functions in the local context using the
macro `SIGNAL-FLET`:

    (defmacro signal-flet ((&rest fdecls) &body body) ...)

Each entry in the `FDECLS` list is of the form
`(NAME (&REST DEPENDS) &BODY SIG-BODY)`.  This macro creates a local
signal function bound to the given `NAME`.  The signal value is
calculated from the `SIG-BODY` using the signals listed in `DEPENDS`.
The `DEPENDS` here is a list of entries each of the form
`(VARNAME SIGNAL)`.  Each `VARNAME` will be bound to the signal value
of the corresponding `SIGNAL` for the `SIG-BODY`.  The `SIG-BODY` will
be executed each time one of the `DEPENDS` signals is updated.

The `NAME` here can be either a symbol or a list of the form `(NAME
&KEY (TYPE T) DOCUMENTATION)`.  The results generated by `BODY` must
conform to the specified `TYPE`.  The `DOCUMENTATION` here will be
used for the signal function.

The `SIGNAL-FLET` macro acts like `FLET` but binds signal functions to
the names.  The signal functions depend on other signals.  For example,
the following creates a list of two signal functions that both depend
on the signal `SIG-X`.

    (signal-flet ((sig-abs-x ((x sig-x)) (abs x))
                  ((sig-sqr-x :type integer) ((x sig-x)) (* x x)))
      (list sig-abs-x sig-sqr-x))

### Deferring Signal Updates

There are times when one will be updating multiple signal variables
which are closely related.  Some signal functions may well depend upon
both of them.  For these instances, it is convenient to delay
recalculating signals until all of the updates are done.  One can use
the `WITH-SIGNAL-UPDATES-DEFERRED` macro around a body of code where
signal functions will not eagerly update until the macro has
completed.  Signal functions which are needed within the
`WITH-SIGNAL-UPDATES-DEFERRED` section will be calculated as needed.

For example, in the following code, the

    (signal-flet ((sig-min ((mx sig-mouse-x) (my sig-mouse-y))
                     (min mx my))
                  (sig-max ((mx sig-mouse-x) (my sig-mouse-y))
                     (max mx my)))
      (with-signal-values ((mx sig-mouse-x)
                           (my sig-mouse-y)
                           (mouse-max sig-max))
        (with-signal-updates-deferred ()
          (setf mx new-x
                my new-y)
          (list (/ mx mouse-max) (/ my mouse-max)))))

Neither `SIG-MAX` nor `SIG-MIN` will be updated when `MX` and `MY` are
assigned.  The `SIG-MAX` signal will be updated when it is used to
create the `LIST`.  The `SIG-MIN` signal will not be updated until the
`WITH-SIGNAL-UPDATES-DEFERRED` section ends.
